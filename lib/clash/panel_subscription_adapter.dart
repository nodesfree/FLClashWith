// lib/clash/panel_subscription_adapter.dart
// 面板订阅功能的适配器，确保v2board订阅信息能够完美集成到ClashMeta

import 'dart:convert';
import 'dart:io';

import 'package:hiddify/clash/config_converter.dart';
import 'package:hiddify/features/panel/xboard/services/http_service/user_service.dart';
import 'package:hiddify/features/panel/xboard/services/token_expiry_handler.dart';
import 'package:hiddify/features/panel/xboard/utils/storage/token_storage.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/overview/profiles_overview_notifier.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:loggy/loggy.dart';

// 使用InfraLogger mixin提供的loggy属性

class PanelSubscriptionAdapter with InfraLogger {
  final UserService _userService = UserService();
  final ConfigConverter _configConverter = ConfigConverter();

  /// 获取面板订阅并转换为Clash配置
  Future<String?> fetchAndConvertSubscription(String accessToken) async {
    try {
      loggy.debug("开始获取面板订阅");

      // 1. 从面板获取订阅链接
      final subscriptionUrl = await _userService.getSubscriptionLink(accessToken);
      if (subscriptionUrl == null) {
        loggy.error("无法获取订阅链接");
        return null;
      }

      loggy.debug("获取到订阅链接: $subscriptionUrl");

      // 2. 下载订阅内容
      final subscriptionContent = await _downloadSubscriptionContent(subscriptionUrl);
      if (subscriptionContent == null) {
        loggy.error("无法下载订阅内容");
        return null;
      }

      loggy.debug("成功下载订阅内容，长度: ${subscriptionContent.length}");

      // 3. 解析订阅内容并转换为Clash配置
      final clashConfig = await _parseAndConvertSubscription(subscriptionContent);

      loggy.debug("订阅转换完成");
      return clashConfig;
    } catch (e) {
      loggy.error("获取和转换订阅失败: $e");
      // 检查是否是认证错误
      if (TokenExpiryHandler.isAuthError(e)) {
        loggy.warning("检测到认证错误，需要重新登录");
        // 使用全局认证错误处理器
        await TokenExpiryHandler.handleAuthError(
          context: null,
          ref: null,
          errorMessage: e.toString(),
        );
        // token过期后直接返回null，不要重新抛出异常
        return null;
      }
      return null;
    }
  }

  /// 更新面板订阅并应用到配置文件
  Future<bool> updatePanelSubscription(WidgetRef ref) async {
    try {
      loggy.debug("开始更新面板订阅");

      // 1. 获取访问令牌
      final accessToken = await TokenStorage.getToken();
      if (accessToken == null) {
        loggy.error("访问令牌不存在");
        return false;
      }

      // 2. 获取转换后的Clash配置
      final clashConfig = await fetchAndConvertSubscription(accessToken);
      if (clashConfig == null) {
        loggy.error("无法获取Clash配置");
        return false;
      }

      // 3. 保存配置到文件
      final configPath = await _saveClashConfig(clashConfig);
      if (configPath == null) {
        loggy.error("保存配置失败");
        return false;
      }

      // 4. 更新Profile系统
      await _updateProfileSystem(ref, configPath);

      loggy.debug("面板订阅更新完成");
      return true;
    } catch (e) {
      loggy.error("更新面板订阅失败: $e");
      return false;
    }
  }

  /// 下载订阅内容
  Future<String?> _downloadSubscriptionContent(String subscriptionUrl) async {
    try {
      final response = await http.get(
        Uri.parse(subscriptionUrl),
        headers: {
          'User-Agent': 'ClashForAndroid/1.0.0',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        loggy.debug("订阅内容前500字符: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}");
        return response.body;
      } else {
        loggy.error("订阅下载失败，状态码: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      loggy.error("下载订阅内容失败: $e");
      return null;
    }
  }

  /// 解析并转换订阅内容
  Future<String?> _parseAndConvertSubscription(String subscriptionContent) async {
    try {
      // 1. 尝试base64解码
      String decodedContent;
      try {
        decodedContent = String.fromCharCodes(base64.decode(subscriptionContent));
        loggy.debug("Base64解码成功，解码后长度: ${decodedContent.length}");
      } catch (e) {
        decodedContent = subscriptionContent;
        loggy.debug("Base64解码失败，使用原始内容，长度: ${decodedContent.length}");
      }

      // 打印订阅内容前500字符用于调试
      final previewContent = decodedContent.length > 500 ? decodedContent.substring(0, 500) : decodedContent;
      loggy.debug("订阅内容前500字符: $previewContent");

      // 2. 优先检查是否已经是Clash YAML格式（最高优先级）
      if (decodedContent.contains('proxies:') || decodedContent.contains('proxy-groups:') || decodedContent.contains('rules:')) {
        loggy.debug("检测到Clash YAML格式，直接使用");
        return decodedContent;
      }

      // 3. 检查是否为JSON格式（Sing-box配置）
      Map<String, dynamic>? singboxConfig;
      try {
        singboxConfig = jsonDecode(decodedContent) as Map<String, dynamic>;
        loggy.debug("检测到JSON格式，确认为Sing-box配置");
        
        // 确保这确实是sing-box配置而不是其他JSON
        if (singboxConfig.containsKey('outbounds') || singboxConfig.containsKey('inbounds')) {
          loggy.debug("确认为Sing-box配置，进行转换");
          final setupParams = await _configConverter.convertSingboxToClash(decodedContent);
          return setupParams.config;
        } else {
          loggy.debug("JSON格式但不是Sing-box配置，当作订阅链接处理");
          singboxConfig = null;
        }
      } catch (e) {
        // 不是JSON，可能是订阅链接列表
        singboxConfig = null;
        loggy.debug("不是JSON格式，尝试解析为订阅链接列表");
      }

      // 4. 作为订阅链接列表处理
      loggy.debug("开始解析为订阅链接列表");
      final clashConfig = await _buildClashConfigFromSubscription(decodedContent);
      return _mapToYaml(clashConfig);
      
    } catch (e) {
      loggy.error("解析订阅内容失败: $e");
      return null;
    }
  }

  /// 从订阅链接构建Clash配置
  Future<Map<String, dynamic>> _buildClashConfigFromSubscription(String subscriptionContent) async {
    final proxies = <Map<String, dynamic>>[];
    final lines = subscriptionContent.split('\n');
    
    loggy.debug("开始解析订阅内容，总行数: ${lines.length}");
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;
      
      loggy.debug("解析第${i+1}行: ${trimmedLine.length > 100 ? trimmedLine.substring(0, 100) + '...' : trimmedLine}");

      try {
        Map<String, dynamic>? proxy;

        if (trimmedLine.startsWith('ss://')) {
          proxy = _parseShadowsocksLink(trimmedLine);
        } else if (trimmedLine.startsWith('vmess://')) {
          proxy = _parseVmessLink(trimmedLine);
        } else if (trimmedLine.startsWith('vless://')) {
          proxy = _parseVlessLink(trimmedLine);
        } else if (trimmedLine.startsWith('trojan://')) {
          proxy = _parseTrojanLink(trimmedLine);
        } else if (trimmedLine.startsWith('hysteria://')) {
          proxy = _parseHysteriaLink(trimmedLine);
        } else if (trimmedLine.startsWith('hysteria2://') || trimmedLine.startsWith('hy2://')) {
          proxy = _parseHysteria2Link(trimmedLine);
        } else {
          loggy.debug("未识别的协议类型: ${trimmedLine.substring(0, trimmedLine.indexOf('://') + 3)}");
        }

        if (proxy != null) {
          proxies.add(proxy);
          loggy.debug("成功解析代理: ${proxy['name']}");
        }
      } catch (e) {
        loggy.warning("解析代理链接失败: $trimmedLine, 错误: $e");
      }
    }
    
    loggy.debug("解析完成，有效代理数量: ${proxies.length}");

    if (proxies.isEmpty) {
      throw Exception("没有找到有效的代理配置");
    }

    final proxyNames = proxies.map((p) => p['name'] as String).toList();

    return {
      'port': 7890,
      'socks-port': 7891,
      'allow-lan': false,
      'mode': 'rule',
      'log-level': 'info',
      'external-controller': '127.0.0.1:9090',
      'proxies': proxies,
      'proxy-groups': [
        {
          'name': 'PROXY',
          'type': 'select',
          'proxies': ['DIRECT', 'AUTO', ...proxyNames],
        },
        {
          'name': 'AUTO',
          'type': 'url-test',
          'proxies': proxyNames,
          'url': 'http://www.gstatic.com/generate_204',
          'interval': 300,
        },
        {
          'name': 'FALLBACK',
          'type': 'fallback',
          'proxies': proxyNames,
          'url': 'http://www.gstatic.com/generate_204',
          'interval': 300,
        },
      ],
      'rules': [
        // 直连规则
        'DOMAIN-SUFFIX,local,DIRECT',
        'IP-CIDR,127.0.0.0/8,DIRECT',
        'IP-CIDR,172.16.0.0/12,DIRECT',
        'IP-CIDR,192.168.0.0/16,DIRECT',
        'IP-CIDR,10.0.0.0/8,DIRECT',
        'IP-CIDR,17.0.0.0/8,DIRECT',
        'IP-CIDR,100.64.0.0/10,DIRECT',

        // 国内直连
        'GEOIP,CN,DIRECT',

        // 其他流量走代理
        'MATCH,PROXY',
      ],
      'dns': {
        'enable': true,
        'listen': '0.0.0.0:53',
        'nameserver': ['223.5.5.5', '119.29.29.29'],
        'fallback': ['8.8.8.8', '1.1.1.1'],
        'fallback-filter': {
          'geoip': true,
          'geoip-code': 'CN',
        },
      },
    };
  }

  /// 解析Shadowsocks链接
  Map<String, dynamic>? _parseShadowsocksLink(String link) {
    try {
      final uri = Uri.parse(link);
      final userInfo = String.fromCharCodes(base64.decode(uri.userInfo));
      final parts = userInfo.split(':');

      if (parts.length != 2) return null;

      return {
        'name': uri.fragment.isNotEmpty ? uri.fragment : '${uri.host}:${uri.port}',
        'type': 'ss',
        'server': uri.host,
        'port': uri.port,
        'cipher': parts[0],
        'password': parts[1],
      };
    } catch (e) {
      loggy.warning("解析SS链接失败: $link, 错误: $e");
      return null;
    }
  }

  /// 解析VMess链接
  Map<String, dynamic>? _parseVmessLink(String link) {
    try {
      final base64Part = link.substring(8); // 移除 "vmess://"
      final jsonStr = String.fromCharCodes(base64.decode(base64Part));
      final config = jsonDecode(jsonStr) as Map<String, dynamic>;

      final proxy = <String, dynamic>{
        'name': config['ps'] ?? '${config['add']}:${config['port']}',
        'type': 'vmess',
        'server': config['add'],
        'port': int.parse(config['port'].toString()),
        'uuid': config['id'],
        'alterId': int.parse(config['aid']?.toString() ?? '0'),
        'cipher': config['scy'] ?? 'auto',
      };

      // 传输协议
      final net = config['net'];
      if (net == 'ws') {
        proxy['network'] = 'ws';
        proxy['ws-opts'] = {
          'path': config['path'] ?? '/',
          if (config['host'] != null) 'headers': {'Host': config['host']},
        };
      } else if (net == 'grpc') {
        proxy['network'] = 'grpc';
        proxy['grpc-opts'] = {
          'grpc-service-name': config['path'] ?? '',
        };
      }

      // TLS
      if (config['tls'] == 'tls') {
        proxy['tls'] = true;
        if (config['sni'] != null) {
          proxy['servername'] = config['sni'];
        }
      }

      return proxy;
    } catch (e) {
      loggy.warning("解析VMess链接失败: $link, 错误: $e");
      return null;
    }
  }

  /// 解析VLESS链接
  Map<String, dynamic>? _parseVlessLink(String link) {
    try {
      final uri = Uri.parse(link);
      final params = uri.queryParameters;

      final proxy = <String, dynamic>{
        'name': uri.fragment.isNotEmpty ? uri.fragment : '${uri.host}:${uri.port}',
        'type': 'vless',
        'server': uri.host,
        'port': uri.port,
        'uuid': uri.userInfo,
        'flow': params['flow'] ?? '',
      };

      // 传输协议
      final type = params['type'];
      if (type == 'ws') {
        proxy['network'] = 'ws';
        proxy['ws-opts'] = {
          'path': params['path'] ?? '/',
          if (params['host'] != null) 'headers': {'Host': params['host']},
        };
      }

      // TLS
      if (params['security'] == 'tls') {
        proxy['tls'] = true;
        if (params['sni'] != null) {
          proxy['servername'] = params['sni'];
        }
      }

      return proxy;
    } catch (e) {
      loggy.warning("解析VLESS链接失败: $link, 错误: $e");
      return null;
    }
  }

  /// 解析Trojan链接
  Map<String, dynamic>? _parseTrojanLink(String link) {
    try {
      final uri = Uri.parse(link);
      final params = uri.queryParameters;

      return {
        'name': uri.fragment.isNotEmpty ? uri.fragment : '${uri.host}:${uri.port}',
        'type': 'trojan',
        'server': uri.host,
        'port': uri.port,
        'password': uri.userInfo,
        'sni': params['sni'] ?? uri.host,
        'skip-cert-verify': params['allowInsecure'] == '1',
      };
    } catch (e) {
      loggy.warning("解析Trojan链接失败: $link, 错误: $e");
      return null;
    }
  }

  /// 解析Hysteria链接
  Map<String, dynamic>? _parseHysteriaLink(String link) {
    try {
      final uri = Uri.parse(link);
      final params = uri.queryParameters;

      return {
        'name': uri.fragment.isNotEmpty ? uri.fragment : '${uri.host}:${uri.port}',
        'type': 'hysteria',
        'server': uri.host,
        'port': uri.port,
        'auth-str': uri.userInfo,
        'up': int.tryParse(params['upmbps'] ?? '10') ?? 10,
        'down': int.tryParse(params['downmbps'] ?? '50') ?? 50,
        'sni': params['peer'] ?? uri.host,
        'skip-cert-verify': params['insecure'] == '1',
      };
    } catch (e) {
      loggy.warning("解析Hysteria链接失败: $link, 错误: $e");
      return null;
    }
  }

  /// 解析Hysteria2链接
  Map<String, dynamic>? _parseHysteria2Link(String link) {
    try {
      final uri = Uri.parse(link);
      final params = uri.queryParameters;

      return {
        'name': uri.fragment.isNotEmpty ? uri.fragment : '${uri.host}:${uri.port}',
        'type': 'hysteria2',
        'server': uri.host,
        'port': uri.port,
        'password': uri.userInfo,
        'up': int.tryParse(params['upmbps'] ?? '10') ?? 10,
        'down': int.tryParse(params['downmbps'] ?? '50') ?? 50,
        'sni': params['sni'] ?? uri.host,
        'skip-cert-verify': params['insecure'] == '1',
      };
    } catch (e) {
      loggy.warning("解析Hysteria2链接失败: $link, 错误: $e");
      return null;
    }
  }

  /// 保存Clash配置到文件
  Future<String?> _saveClashConfig(String clashConfig) async {
    try {
      final configDir = Directory('/tmp/hiddify_clash_configs');
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }

      final configFile = File('${configDir.path}/panel_subscription.yaml');
      await configFile.writeAsString(clashConfig);

      loggy.debug("配置已保存到: ${configFile.path}");
      return configFile.path;
    } catch (e) {
      loggy.error("保存配置失败: $e");
      return null;
    }
  }

  /// 更新Profile系统
  Future<void> _updateProfileSystem(WidgetRef ref, String configPath) async {
    try {
      // 1. 获取当前的Profile仓库
      final profileRepository = await ref.read(profileRepositoryProvider.future);

      // 2. 删除旧的远程配置
      final profilesResult = await profileRepository.watchAll().first;
      final profiles = profilesResult.getOrElse((_) => []);

      for (final profile in profiles) {
        if (profile is RemoteProfileEntity) {
          await ref.read(profilesOverviewNotifierProvider.notifier).deleteProfile(profile);
        }
      }

      // 3. 创建新的本地配置文件Profile
      final newProfile = LocalProfileEntity(
        id: 'panel_subscription_${DateTime.now().millisecondsSinceEpoch}',
        active: true,
        name: 'Panel Subscription',
        lastUpdate: DateTime.now(),
      );

      // 4. 添加到Profile系统 - 暂时简化，直接使用配置文件
      // TODO: 集成到HiddifyWithPanels的Profile系统
      loggy.info("面板订阅配置已保存到: $configPath");
      loggy.info("新Profile创建: ${newProfile.name} (${newProfile.id})");

      loggy.debug("Profile系统更新完成");
    } catch (e) {
      loggy.error("更新Profile系统失败: $e");
      rethrow;
    }
  }

  /// 将Map转换为YAML字符串
  String _mapToYaml(Map<String, dynamic> map) {
    final buffer = StringBuffer();
    _writeYamlMap(map, buffer, 0);
    return buffer.toString();
  }

  void _writeYamlMap(Map<String, dynamic> map, StringBuffer buffer, int indent) {
    for (final entry in map.entries) {
      buffer.write('  ' * indent);
      buffer.write('${entry.key}: ');

      if (entry.value is Map<String, dynamic>) {
        buffer.writeln();
        _writeYamlMap(entry.value as Map<String, dynamic>, buffer, indent + 1);
      } else if (entry.value is List) {
        buffer.writeln();
        _writeYamlList(entry.value as List, buffer, indent + 1);
      } else if (entry.value is String && entry.value.toString().contains(' ')) {
        buffer.writeln('"${entry.value}"');
      } else {
        buffer.writeln(entry.value);
      }
    }
  }

  void _writeYamlList(List list, StringBuffer buffer, int indent) {
    for (final item in list) {
      buffer.write('  ' * indent);
      buffer.write('- ');

      if (item is Map<String, dynamic>) {
        buffer.writeln();
        _writeYamlMap(item, buffer, indent + 1);
      } else if (item is String && item.contains(' ')) {
        buffer.writeln('"$item"');
      } else {
        buffer.writeln(item);
      }
    }
  }
}
