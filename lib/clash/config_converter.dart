// lib/clash/config_converter.dart
// Sing-box配置到Clash配置的转换器

import 'dart:convert';
import 'dart:math' as math;
import 'package:hiddify/clash/models/models.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:loggy/loggy.dart';

final _logger = Loggy('ConfigConverter');

class ConfigConverter with InfraLogger {
  /// 将Sing-box JSON配置转换为Clash YAML配置
  Future<SetupParams> convertSingboxToClash(String singboxConfigContent) async {
    try {
      final Map<String, dynamic> singboxConfig;

      // 尝试解析JSON配置
      try {
        singboxConfig = jsonDecode(singboxConfigContent) as Map<String, dynamic>;
      } catch (e) {
        // 如果不是JSON，可能是订阅内容，尝试处理
        return await _handleSubscriptionContent(singboxConfigContent);
      }

      // 构建Clash配置
      final clashConfig = await _buildClashConfig(singboxConfig);

      // 转换为YAML
      final yamlConfig = _mapToYaml(clashConfig);

      return SetupParams(
        config: yamlConfig,
        params: SetupConfigParams(),
      );
    } catch (e) {
      _logger.error("配置转换失败: $e");
      rethrow;
    }
  }

  /// 处理订阅内容（可能包含多个配置）
  Future<SetupParams> _handleSubscriptionContent(String content) async {
    try {
      _logger.debug("处理订阅内容，长度: ${content.length}");
      
      // 首先检查是否是已经是YAML格式的Clash配置
      if (content.contains('proxies:') || content.contains('proxy-groups:')) {
        _logger.debug("检测到Clash YAML格式，直接使用");
        return SetupParams(
          config: content,
          params: SetupConfigParams(),
        );
      }

      // 尝试base64解码
      String decodedContent;
      try {
        decodedContent = String.fromCharCodes(base64.decode(content.trim()));
        _logger.debug("Base64解码成功，解码后长度: ${decodedContent.length}");
      } catch (e) {
        decodedContent = content;
        _logger.debug("Base64解码失败，使用原始内容");
      }

      // 再次检查解码后是否是YAML格式
      if (decodedContent.contains('proxies:') || decodedContent.contains('proxy-groups:')) {
        _logger.debug("解码后检测到Clash YAML格式");
        return SetupParams(
          config: decodedContent,
          params: SetupConfigParams(),
        );
      }

      // 解析订阅内容为代理列表
      final proxies = _parseSubscriptionLinks(decodedContent);
      _logger.debug("成功解析 ${proxies.length} 个代理配置");

      if (proxies.isEmpty) {
        throw Exception("没有找到有效的代理配置");
      }

      // 构建基础Clash配置
      final clashConfig = _buildBasicClashConfig(proxies);
      final yamlConfig = _mapToYaml(clashConfig);

      return SetupParams(
        config: yamlConfig,
        params: SetupConfigParams(),
      );
    } catch (e) {
      _logger.error("订阅内容处理失败: $e");
      rethrow;
    }
  }

  /// 构建Clash配置
  Future<Map<String, dynamic>> _buildClashConfig(Map<String, dynamic> singboxConfig) async {
    final clashConfig = <String, dynamic>{
      'port': 7890,
      'socks-port': 7891,
      'allow-lan': false,
      'mode': 'rule',
      'log-level': 'info',
      'external-controller': '127.0.0.1:9090',
      'secret': '',
    };

    // 转换入站配置
    if (singboxConfig.containsKey('inbounds')) {
      _convertInbounds(singboxConfig['inbounds'] as List, clashConfig);
    }

    // 转换出站配置
    if (singboxConfig.containsKey('outbounds')) {
      _convertOutbounds(singboxConfig['outbounds'] as List, clashConfig);
    }

    // 转换路由规则
    if (singboxConfig.containsKey('route')) {
      _convertRoute(singboxConfig['route'] as Map<String, dynamic>, clashConfig);
    }

    // 转换DNS配置
    if (singboxConfig.containsKey('dns')) {
      _convertDns(singboxConfig['dns'] as Map<String, dynamic>, clashConfig);
    }

    return clashConfig;
  }

  /// 转换入站配置
  void _convertInbounds(List inbounds, Map<String, dynamic> clashConfig) {
    for (final inbound in inbounds) {
      if (inbound is! Map<String, dynamic>) continue;

      final type = inbound['type'] as String?;
      final port = inbound['listen_port'] as int?;

      switch (type) {
        case 'mixed':
          clashConfig['port'] = port ?? 7890;
          break;
        case 'socks':
          clashConfig['socks-port'] = port ?? 7891;
          break;
        case 'tun':
          clashConfig['tun'] = {
            'enable': true,
            'stack': inbound['stack'] ?? 'system',
            'device': inbound['interface_name'] ?? 'utun',
            'auto-route': inbound['auto_route'] ?? true,
            'auto-detect-interface': true,
            'dns-hijack': ['any:53'],
          };
          break;
      }
    }
  }

  /// 转换出站配置
  void _convertOutbounds(List outbounds, Map<String, dynamic> clashConfig) {
    final proxies = <Map<String, dynamic>>[];
    final proxyGroups = <Map<String, dynamic>>[];
    final proxyNames = <String>[];

    for (final outbound in outbounds) {
      if (outbound is! Map<String, dynamic>) continue;

      final type = outbound['type'] as String?;
      final tag = outbound['tag'] as String?;

      if (tag == null) continue;

      switch (type) {
        case 'direct':
        case 'block':
          // 跳过特殊出站
          continue;
        case 'selector':
          // 代理组
          proxyGroups.add(_convertSelectorGroup(outbound));
          continue;
        case 'urltest':
          // URL测试组
          proxyGroups.add(_convertUrlTestGroup(outbound));
          continue;
        default:
          // 普通代理
          final proxy = _convertProxy(outbound);
          if (proxy != null) {
            proxies.add(proxy);
            proxyNames.add(tag);
          }
      }
    }

    clashConfig['proxies'] = proxies;

    // 如果没有代理组，创建默认组
    if (proxyGroups.isEmpty && proxyNames.isNotEmpty) {
      proxyGroups.addAll([
        {
          'name': 'PROXY',
          'type': 'select',
          'proxies': ['DIRECT', ...proxyNames],
        },
        {
          'name': 'AUTO',
          'type': 'url-test',
          'proxies': proxyNames,
          'url': 'http://www.gstatic.com/generate_204',
          'interval': 300,
        },
      ]);
    }

    clashConfig['proxy-groups'] = proxyGroups;
  }

  /// 转换单个代理
  Map<String, dynamic>? _convertProxy(Map<String, dynamic> outbound) {
    final type = outbound['type'] as String?;
    final tag = outbound['tag'] as String?;

    if (tag == null) return null;

    switch (type) {
      case 'shadowsocks':
        return _convertShadowsocks(outbound);
      case 'vmess':
        return _convertVmess(outbound);
      case 'vless':
        return _convertVless(outbound);
      case 'trojan':
        return _convertTrojan(outbound);
      case 'hysteria':
        return _convertHysteria(outbound);
      case 'hysteria2':
        return _convertHysteria2(outbound);
      default:
        _logger.warning("不支持的协议类型: $type");
        return null;
    }
  }

  /// 转换Shadowsocks代理
  Map<String, dynamic> _convertShadowsocks(Map<String, dynamic> outbound) {
    return {
      'name': outbound['tag'],
      'type': 'ss',
      'server': outbound['server'],
      'port': outbound['server_port'],
      'cipher': outbound['method'],
      'password': outbound['password'],
      if (outbound['plugin'] != null) 'plugin': outbound['plugin'],
      if (outbound['plugin_opts'] != null) 'plugin-opts': outbound['plugin_opts'],
    };
  }

  /// 转换VMess代理
  Map<String, dynamic> _convertVmess(Map<String, dynamic> outbound) {
    return {
      'name': outbound['tag'],
      'type': 'vmess',
      'server': outbound['server'],
      'port': outbound['server_port'],
      'uuid': outbound['uuid'],
      'alterId': outbound['alter_id'] ?? 0,
      'cipher': outbound['security'] ?? 'auto',
      if (outbound['transport'] != null)
        ...() {
          final transport = outbound['transport'] as Map<String, dynamic>;
          final transportType = transport['type'] as String?;

          switch (transportType) {
            case 'ws':
              return {
                'network': 'ws',
                'ws-opts': {
                  'path': transport['path'] ?? '/',
                  if (transport['headers'] != null) 'headers': transport['headers'],
                },
              };
            case 'grpc':
              return {
                'network': 'grpc',
                'grpc-opts': {
                  'grpc-service-name': transport['service_name'] ?? '',
                },
              };
            default:
              return <String, dynamic>{};
          }
        }(),
      if (outbound['tls'] != null)
        ...() {
          final tls = outbound['tls'] as Map<String, dynamic>;
          return {
            'tls': tls['enabled'] ?? false,
            if (tls['server_name'] != null) 'servername': tls['server_name'],
            'skip-cert-verify': !((tls['verify'] ?? true) as bool),
          };
        }(),
    };
  }

  /// 转换VLESS代理
  Map<String, dynamic> _convertVless(Map<String, dynamic> outbound) {
    return {
      'name': outbound['tag'],
      'type': 'vless',
      'server': outbound['server'],
      'port': outbound['server_port'],
      'uuid': outbound['uuid'],
      'flow': outbound['flow'] ?? '',
      if (outbound['transport'] != null)
        ...() {
          final transport = outbound['transport'] as Map<String, dynamic>;
          final transportType = transport['type'] as String?;

          switch (transportType) {
            case 'ws':
              return {
                'network': 'ws',
                'ws-opts': {
                  'path': transport['path'] ?? '/',
                  if (transport['headers'] != null) 'headers': transport['headers'],
                },
              };
            default:
              return <String, dynamic>{};
          }
        }(),
      if (outbound['tls'] != null)
        ...() {
          final tls = outbound['tls'] as Map<String, dynamic>;
          return {
            'tls': tls['enabled'] ?? false,
            if (tls['server_name'] != null) 'servername': tls['server_name'],
            'skip-cert-verify': !((tls['verify'] ?? true) as bool),
          };
        }(),
    };
  }

  /// 转换Trojan代理
  Map<String, dynamic> _convertTrojan(Map<String, dynamic> outbound) {
    return {
      'name': outbound['tag'],
      'type': 'trojan',
      'server': outbound['server'],
      'port': outbound['server_port'],
      'password': outbound['password'],
      if (outbound['tls'] != null)
        ...() {
          final tls = outbound['tls'] as Map<String, dynamic>;
          return {
            'sni': tls['server_name'],
            'skip-cert-verify': !((tls['verify'] ?? true) as bool),
          };
        }(),
    };
  }

  /// 转换Hysteria代理
  Map<String, dynamic> _convertHysteria(Map<String, dynamic> outbound) {
    return {
      'name': outbound['tag'],
      'type': 'hysteria',
      'server': outbound['server'],
      'port': outbound['server_port'],
      'auth-str': outbound['auth_str'] ?? '',
      'up': outbound['up_mbps'] ?? 10,
      'down': outbound['down_mbps'] ?? 50,
      if (outbound['tls'] != null)
        ...() {
          final tls = outbound['tls'] as Map<String, dynamic>;
          return {
            'sni': tls['server_name'],
            'skip-cert-verify': !((tls['verify'] ?? true) as bool),
          };
        }(),
    };
  }

  /// 转换Hysteria2代理
  Map<String, dynamic> _convertHysteria2(Map<String, dynamic> outbound) {
    return {
      'name': outbound['tag'],
      'type': 'hysteria2',
      'server': outbound['server'],
      'port': outbound['server_port'],
      'password': outbound['password'] ?? '',
      'up': outbound['up_mbps'] ?? 10,
      'down': outbound['down_mbps'] ?? 50,
      if (outbound['tls'] != null)
        ...() {
          final tls = outbound['tls'] as Map<String, dynamic>;
          return {
            'sni': tls['server_name'],
            'skip-cert-verify': !((tls['verify'] ?? true) as bool),
          };
        }(),
    };
  }

  /// 转换选择器组
  Map<String, dynamic> _convertSelectorGroup(Map<String, dynamic> outbound) {
    return {
      'name': outbound['tag'],
      'type': 'select',
      'proxies': ['DIRECT', ...(outbound['outbounds'] as List? ?? [])],
    };
  }

  /// 转换URL测试组
  Map<String, dynamic> _convertUrlTestGroup(Map<String, dynamic> outbound) {
    return {
      'name': outbound['tag'],
      'type': 'url-test',
      'proxies': outbound['outbounds'] as List? ?? [],
      'url': outbound['url'] ?? 'http://www.gstatic.com/generate_204',
      'interval': (outbound['interval'] as String?)?.replaceAll('s', '') ?? '300',
    };
  }

  /// 转换路由配置
  void _convertRoute(Map<String, dynamic> route, Map<String, dynamic> clashConfig) {
    final rules = <String>[];

    if (route.containsKey('rules')) {
      final routeRules = route['rules'] as List;

      for (final rule in routeRules) {
        if (rule is! Map<String, dynamic>) continue;

        final clashRule = _convertRule(rule);
        if (clashRule != null) {
          rules.add(clashRule);
        }
      }
    }

    // 添加默认规则
    rules.addAll([
      'DOMAIN-SUFFIX,local,DIRECT',
      'IP-CIDR,127.0.0.0/8,DIRECT',
      'IP-CIDR,172.16.0.0/12,DIRECT',
      'IP-CIDR,192.168.0.0/16,DIRECT',
      'IP-CIDR,10.0.0.0/8,DIRECT',
      'IP-CIDR,17.0.0.0/8,DIRECT',
      'IP-CIDR,100.64.0.0/10,DIRECT',
      'GEOIP,CN,DIRECT',
      'MATCH,PROXY',
    ]);

    clashConfig['rules'] = rules;
  }

  /// 转换单个规则
  String? _convertRule(Map<String, dynamic> rule) {
    final type = rule['type'] as String?;
    final outbound = rule['outbound'] as String?;

    if (type == null || outbound == null) return null;

    switch (type) {
      case 'domain':
        return 'DOMAIN,${rule['domain']},$outbound';
      case 'domain_suffix':
        return 'DOMAIN-SUFFIX,${rule['domain']},$outbound';
      case 'domain_keyword':
        return 'DOMAIN-KEYWORD,${rule['domain']},$outbound';
      case 'geosite':
        return 'RULE-SET,${rule['geosite']},$outbound';
      case 'ip_cidr':
        return 'IP-CIDR,${rule['ip_cidr']},$outbound';
      case 'geoip':
        return 'GEOIP,${rule['country_code']},$outbound';
      default:
        return null;
    }
  }

  /// 转换DNS配置
  void _convertDns(Map<String, dynamic> dns, Map<String, dynamic> clashConfig) {
    clashConfig['dns'] = {
      'enable': dns['enable'] ?? true,
      'listen': '0.0.0.0:53',
      'nameserver': _extractNameservers(dns),
      'fallback': [
        '8.8.8.8',
        '1.1.1.1',
      ],
      'fallback-filter': {
        'geoip': true,
        'geoip-code': 'CN',
      },
    };
  }

  /// 提取DNS服务器
  List<String> _extractNameservers(Map<String, dynamic> dns) {
    final nameservers = <String>[];

    if (dns.containsKey('servers')) {
      final servers = dns['servers'] as List;
      for (final server in servers) {
        if (server is String) {
          nameservers.add(server);
        } else if (server is Map<String, dynamic>) {
          final address = server['address'] as String?;
          if (address != null) {
            nameservers.add(address);
          }
        }
      }
    }

    if (nameservers.isEmpty) {
      nameservers.addAll(['223.5.5.5', '119.29.29.29']);
    }

    return nameservers;
  }

  /// 解析订阅链接
  List<Map<String, dynamic>> _parseSubscriptionLinks(String content) {
    final proxies = <Map<String, dynamic>>[];
    final lines = content.split('\n');

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      try {
        if (trimmedLine.startsWith('ss://')) {
          final proxy = _parseShadowsocksLink(trimmedLine);
          if (proxy.isNotEmpty) proxies.add(proxy);
        } else if (trimmedLine.startsWith('vmess://')) {
          final proxy = _parseVmessLink(trimmedLine);
          if (proxy.isNotEmpty) proxies.add(proxy);
        } else if (trimmedLine.startsWith('trojan://')) {
          final proxy = _parseTrojanLink(trimmedLine);
          if (proxy.isNotEmpty) proxies.add(proxy);
        } else if (trimmedLine.startsWith('vless://')) {
          final proxy = _parseVlessLink(trimmedLine);
          if (proxy.isNotEmpty) proxies.add(proxy);
        } else if (trimmedLine.startsWith('hysteria2://')) {
          final proxy = _parseHysteria2Link(trimmedLine);
          if (proxy.isNotEmpty) proxies.add(proxy);
        }
      } catch (e) {
        final preview = trimmedLine.length > 50 ? '${trimmedLine.substring(0, 50)}...' : trimmedLine;
        _logger.warning("解析代理链接失败: $preview, 错误: $e");
      }
    }

    _logger.debug("解析订阅链接: 总行数=${lines.length}, 有效代理=${proxies.length}");
    return proxies;
  }

  /// 解析Shadowsocks链接
  Map<String, dynamic> _parseShadowsocksLink(String link) {
    try {
      // ss://方法:端口@服务器地址#备注
      final uri = Uri.parse(link);
      final userInfo = String.fromCharCodes(base64.decode(uri.userInfo));
      final parts = userInfo.split(':');
      
      if (parts.length != 2) return {};
      
      return {
        'name': uri.fragment.isNotEmpty ? uri.fragment : 'SS-${uri.host}',
        'type': 'ss',
        'server': uri.host,
        'port': uri.port,
        'cipher': parts[0],
        'password': parts[1],
      };
    } catch (e) {
      _logger.warning("SS链接解析失败: $e");
      return {};
    }
  }

  /// 解析VMess链接
  Map<String, dynamic> _parseVmessLink(String link) {
    try {
      // vmess://base64编码的JSON配置
      final base64String = link.substring(8); // 移除 "vmess://"
      final decodedJson = String.fromCharCodes(base64.decode(base64String));
      final config = jsonDecode(decodedJson) as Map<String, dynamic>;
      
      return {
        'name': config['ps'] ?? 'VMess-${config['add']}',
        'type': 'vmess',
        'server': config['add'],
        'port': int.tryParse(config['port'].toString()) ?? 443,
        'uuid': config['id'],
        'alterId': int.tryParse(config['aid'].toString()) ?? 0,
        'cipher': config['scy'] ?? 'auto',
        'network': config['net'] ?? 'tcp',
        'tls': config['tls'] == 'tls',
        if (config['host'] != null && config['host'].toString().isNotEmpty)
          'servername': config['host'],
        if (config['path'] != null && config['path'].toString().isNotEmpty)
          'ws-opts': {'path': config['path']},
      };
    } catch (e) {
      _logger.warning("VMess链接解析失败: $e");
      return {};
    }
  }

  /// 解析Trojan链接
  Map<String, dynamic> _parseTrojanLink(String link) {
    try {
      final uri = Uri.parse(link);
      
      return {
        'name': uri.fragment.isNotEmpty ? uri.fragment : 'Trojan-${uri.host}',
        'type': 'trojan',
        'server': uri.host,
        'port': uri.port,
        'password': uri.userInfo,
        'sni': uri.queryParameters['sni'] ?? uri.host,
      };
    } catch (e) {
      _logger.warning("Trojan链接解析失败: $e");
      return {};
    }
  }

  /// 解析VLess链接
  Map<String, dynamic> _parseVlessLink(String link) {
    try {
      final uri = Uri.parse(link);
      
      return {
        'name': uri.fragment.isNotEmpty ? uri.fragment : 'VLess-${uri.host}',
        'type': 'vless',
        'server': uri.host,
        'port': uri.port,
        'uuid': uri.userInfo,
        'tls': uri.queryParameters['security'] == 'tls',
        if (uri.queryParameters['sni'] != null)
          'servername': uri.queryParameters['sni'],
      };
    } catch (e) {
      _logger.warning("VLess链接解析失败: $e");
      return {};
    }
  }

  /// 解析Hysteria2链接
  Map<String, dynamic> _parseHysteria2Link(String link) {
    try {
      final uri = Uri.parse(link);
      
      return {
        'name': uri.fragment.isNotEmpty ? uri.fragment : 'Hysteria2-${uri.host}',
        'type': 'hysteria2',
        'server': uri.host,
        'port': uri.port,
        'password': uri.userInfo,
        'sni': uri.queryParameters['sni'],
        'skip-cert-verify': uri.queryParameters['insecure'] == '1',
        if (uri.queryParameters['obfs'] != null)
          'obfs': {
            'type': uri.queryParameters['obfs'],
            if (uri.queryParameters['obfs-password'] != null)
              'password': uri.queryParameters['obfs-password'],
          },
      };
    } catch (e) {
      _logger.warning("Hysteria2链接解析失败: $e");
      return {};
    }
  }

  /// 构建基础Clash配置（用于订阅）
  Map<String, dynamic> _buildBasicClashConfig(List<Map<String, dynamic>> proxies) {
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
      ],
      'rules': [
        'DOMAIN-SUFFIX,local,DIRECT',
        'IP-CIDR,127.0.0.0/8,DIRECT',
        'IP-CIDR,172.16.0.0/12,DIRECT',
        'IP-CIDR,192.168.0.0/16,DIRECT',
        'IP-CIDR,10.0.0.0/8,DIRECT',
        'GEOIP,CN,DIRECT',
        'MATCH,PROXY',
      ],
      'dns': {
        'enable': true,
        'listen': '0.0.0.0:53',
        'nameserver': ['223.5.5.5', '119.29.29.29'],
        'fallback': ['8.8.8.8', '1.1.1.1'],
      },
    };
  }

  /// 将Map转换为YAML字符串
  String _mapToYaml(Map<String, dynamic> map) {
    // 简单的YAML序列化
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
      } else {
        buffer.writeln(item);
      }
    }
  }
}
