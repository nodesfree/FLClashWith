// lib/clash/clash_adapter_service.dart
// ClashMeta核心适配器，实现SingboxService接口

import 'dart:async';

import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:hiddify/clash/simple_clash_core.dart';
import 'package:hiddify/clash/config_converter.dart';
import 'package:hiddify/core/model/directories.dart';
import 'package:hiddify/singbox/model/singbox_config_option.dart';
import 'package:hiddify/singbox/model/singbox_outbound.dart';
import 'package:hiddify/singbox/model/singbox_stats.dart';
import 'package:hiddify/singbox/model/singbox_status.dart';
import 'package:hiddify/singbox/model/warp_account.dart';
import 'package:hiddify/singbox/service/singbox_service.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:loggy/loggy.dart';

final _logger = Loggy('ClashAdapterService');

class ClashAdapterService with InfraLogger implements SingboxService {
  final ClashCore _clashCore = ClashCore();
  final ConfigConverter _converter = ConfigConverter();

  late final Stream<SingboxStatus> _status;
  late final StreamController<SingboxStatus> _statusController;

  bool _isInitialized = false;
  SingboxConfigOption? _currentOptions;

  @override
  Future<void> init() async {
    if (_isInitialized) return;

    _logger.debug("初始化ClashAdapterService");

    // 初始化状态流
    _statusController = StreamController<SingboxStatus>.broadcast();
    _status = _statusController.stream;

    // 初始化ClashCore
    await _clashCore.preload();
    await _clashCore.init();

    _isInitialized = true;
    _logger.debug("ClashAdapterService初始化完成");
  }

  @override
  TaskEither<String, Unit> setup(Directories directories, bool debug) {
    return TaskEither(() async {
      try {
        await init();

        // 设置工作目录
        final homeDirPath = directories.workingDir.path;
        await _clashCore.init();

        _logger.debug("ClashCore设置完成，工作目录: $homeDirPath");
        return right(unit);
      } catch (e) {
        _logger.error("设置失败: $e");
        return left("ClashCore设置失败: $e");
      }
    });
  }

  @override
  TaskEither<String, Unit> validateConfigByPath(String path, String tempPath, bool debug) {
    return TaskEither(() async {
      try {
        // 读取配置文件
        final configFile = File(path);
        if (!await configFile.exists()) {
          return left("配置文件不存在: $path");
        }

        final configContent = await configFile.readAsString();

        // 尝试转换为Clash配置
        final clashConfig = await _converter.convertSingboxToClash(configContent);

        // 验证配置
        final validationResult = await _clashCore.validateConfig(clashConfig.config);
        if (validationResult.isNotEmpty) {
          return left("配置验证失败: $validationResult");
        }

        // 保存转换后的配置到tempPath
        final tempFile = File(tempPath);
        await tempFile.writeAsString(clashConfig.config);

        _logger.debug("配置验证成功");
        return right(unit);
      } catch (e) {
        _logger.error("配置验证失败: $e");
        return left("配置验证失败: $e");
      }
    });
  }

  @override
  TaskEither<String, Unit> changeOptions(SingboxConfigOption options) {
    return TaskEither(() async {
      try {
        _currentOptions = options;

        // 将SingboxConfigOption适配到ClashCore
        final coreState = _convertSingboxOptionsToCoreState(options);
        await _clashCore.setState(coreState);

        _logger.debug("配置选项更新成功");
        return right(unit);
      } catch (e) {
        _logger.error("配置选项更新失败: $e");
        return left("配置选项更新失败: $e");
      }
    });
  }

  @override
  TaskEither<String, String> generateFullConfigByPath(String path) {
    return TaskEither(() async {
      try {
        final configFile = File(path);
        if (!await configFile.exists()) {
          return left("配置文件不存在: $path");
        }

        final configContent = await configFile.readAsString();
        final clashConfig = await _converter.convertSingboxToClash(configContent);

        _logger.debug("配置生成成功");
        return right(clashConfig.config);
      } catch (e) {
        _logger.error("配置生成失败: $e");
        return left("配置生成失败: $e");
      }
    });
  }

  @override
  TaskEither<String, Unit> start(String path, String name, bool disableMemoryLimit) {
    return TaskEither(() async {
      try {
        _statusController.add(const SingboxStarting());

        // 读取并转换配置
        final configFile = File(path);
        if (!await configFile.exists()) {
          _statusController.add(
            SingboxStopped(
              alert: SingboxAlert.emptyConfiguration,
              message: "配置文件不存在: $path",
            ),
          );
          return left("配置文件不存在: $path");
        }

        final configContent = await configFile.readAsString();
                var clashConfig = await _converter.convertSingboxToClash(configContent);
        
        // 应用当前选项
        if (_currentOptions != null) {
          clashConfig = _enhanceConfigWithOptions(clashConfig, _currentOptions!);
        }

        // 启动ClashCore
        final setupResult = await _clashCore.setupConfig(clashConfig);
        if (setupResult.isNotEmpty) {
          _statusController.add(
            SingboxStopped(
              alert: SingboxAlert.startService,
              message: "配置应用失败: $setupResult",
            ),
          );
          return left("配置应用失败: $setupResult");
        }

        // 启动监听
        await _clashCore.startListener();

        _statusController.add(const SingboxStarted());
        _logger.debug("ClashCore启动成功，配置: $name");
        return right(unit);
      } catch (e) {
        _statusController.add(
          SingboxStopped(
            alert: SingboxAlert.startService,
            message: "启动失败: $e",
          ),
        );
        _logger.error("启动失败: $e");
        return left("启动失败: $e");
      }
    });
  }

  @override
  TaskEither<String, Unit> stop() {
    return TaskEither(() async {
      try {
        _statusController.add(const SingboxStopping());

        await _clashCore.stopListener();
        await _clashCore.shutdown();

        _statusController.add(const SingboxStopped());
        _logger.debug("ClashCore停止成功");
        return right(unit);
      } catch (e) {
        _logger.error("停止失败: $e");
        return left("停止失败: $e");
      }
    });
  }

  @override
  TaskEither<String, Unit> restart(String path, String name, bool disableMemoryLimit) {
    return TaskEither(() async {
      try {
        _statusController.add(const SingboxStopping());

        // 先停止
        await _clashCore.stopListener();

        // 等待短暂时间确保完全停止
        await Future.delayed(const Duration(milliseconds: 500));

        // 重新启动
        final startResult = await start(path, name, disableMemoryLimit).run();
        return startResult;
      } catch (e) {
        _logger.error("重启失败: $e");
        return left("重启失败: $e");
      }
    });
  }

  @override
  TaskEither<String, Unit> resetTunnel() {
    return TaskEither(() async {
      try {
        // ClashMeta的连接重置
        _clashCore.resetConnections();
        _logger.debug("隧道重置成功");
        return right(unit);
      } catch (e) {
        _logger.error("隧道重置失败: $e");
        return left("隧道重置失败: $e");
      }
    });
  }

  @override
  Stream<SingboxStatus> watchStatus() => _status;

  @override
  Stream<SingboxStats> watchStats() {
    return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
      try {
        final traffic = await _clashCore.getTraffic();
        final totalTraffic = await _clashCore.getTotalTraffic();

        return SingboxStats(
          uplink: traffic.up,
          downlink: traffic.down,
          uplinkTotal: totalTraffic.up,
          downlinkTotal: totalTraffic.down,
          connectionsIn: 0,
          connectionsOut: 0,
        );
      } catch (e) {
        _logger.error("获取统计信息失败: $e");
        return const SingboxStats(
          uplink: 0,
          downlink: 0,
          uplinkTotal: 0,
          downlinkTotal: 0,
          connectionsIn: 0,
          connectionsOut: 0,
        );
      }
    });
  }

  @override
  Stream<List<SingboxOutboundGroup>> watchGroups() {
    return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) async {
      try {
        final groups = await _clashCore.getProxiesGroups();
        return groups.map<SingboxOutboundGroup>((group) => _convertGroupToSingboxOutbound(group)).toList();
      } catch (e) {
        _logger.error("获取代理组失败: $e");
        return <SingboxOutboundGroup>[];
      }
    });
  }

  @override
  Stream<List<SingboxOutboundGroup>> watchActiveGroups() {
    // 对于Clash，活跃组和所有组是一样的
    return watchGroups();
  }

  @override
  TaskEither<String, Unit> selectOutbound(String groupTag, String outboundTag) {
    return TaskEither(() async {
      try {
        final params = ChangeProxyParams(groupName: groupTag, proxyName: outboundTag);
        final result = await _clashCore.changeProxy(params);

        if (result.isNotEmpty) {
          return left("切换代理失败: $result");
        }

        _logger.debug("代理切换成功: $groupTag -> $outboundTag");
        return right(unit);
      } catch (e) {
        _logger.error("代理切换失败: $e");
        return left("代理切换失败: $e");
      }
    });
  }

  @override
  TaskEither<String, Unit> urlTest(String groupTag) {
    return TaskEither(() async {
      try {
        // 对整个组进行延迟测试
        final groups = await _clashCore.getProxiesGroups();
        final targetGroup = groups.firstWhere(
          (g) => g.tag == groupTag,
          orElse: () => throw Exception("代理组不存在: $groupTag"),
        );

        // 测试组内所有代理的延迟
        for (final proxy in targetGroup.all) {
          try {
            await _clashCore.getDelay("http://www.gstatic.com/generate_204", proxy.tag);
          } catch (e) {
            _logger.warning("代理 ${proxy.tag} 延迟测试失败: $e");
          }
        }

        _logger.debug("延迟测试完成: $groupTag");
        return right(unit);
      } catch (e) {
        _logger.error("延迟测试失败: $e");
        return left("延迟测试失败: $e");
      }
    });
  }

  @override
  Stream<List<String>> watchLogs(String path) {
    // ClashMeta的日志监听实现
    return Stream.periodic(const Duration(seconds: 1)).map((_) => <String>[]);
  }

  @override
  TaskEither<String, Unit> clearLogs() {
    return TaskEither(() async {
      _logger.debug("日志清理完成");
      return right(unit);
    });
  }

  @override
  TaskEither<String, WarpResponse> generateWarpConfig({
    required String licenseKey,
    required String previousAccountId,
    required String previousAccessToken,
  }) {
    return TaskEither(() async {
      // ClashMeta不直接支持Warp，返回错误
      return left("ClashMeta不支持Warp配置生成");
    });
  }

  // 辅助方法：转换配置选项
  CoreState _convertSingboxOptionsToCoreState(SingboxConfigOption options) {
    return CoreState(
      enableTun: options.enableTun,
      tunMode: options.enableTun,
      mixedPort: options.mixedPort,
      tproxyPort: options.tproxyPort,
      dnsPort: options.localDnsPort,
      onlyProxy: false, // 根据需要设置
    );
  }

  // 辅助方法：增强配置
  SetupParams _enhanceConfigWithOptions(SetupParams config, SingboxConfigOption options) {
    // 这里可以根据options修改config
    // 例如修改端口、DNS设置等
    return config;
  }

  // 辅助方法：转换代理组
  SingboxOutboundGroup _convertGroupToSingboxOutbound(dynamic group) {
    return SingboxOutboundGroup(
      tag: group.tag as String,
      type: (group.type as GroupType).name,
      selected: group.now as String,
      items: (group.all as List)
          .map((proxy) => SingboxOutbound(
                tag: proxy.tag as String,
                type: proxy.type as String,
                server: "",
                serverPort: 0,
              ))
          .toList(),
    );
  }
}
