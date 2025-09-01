// lib/clash/simple_clash_core.dart
// 简化的ClashCore实现，用于适配

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hiddify/clash/models/models.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:loggy/loggy.dart';



class ClashCore with InfraLogger {
  Process? _process;
  late String _workingDir;
  late String _configPath;
  StreamSubscription? _outputSubscription;
  StreamSubscription? _errorSubscription;

  Future<void> preload() async {
    loggy.debug("ClashCore预加载");
    // 这里可以进行一些预加载操作
  }

  Future<void> init() async {
    loggy.debug("ClashCore初始化");

    // 创建工作目录
    _workingDir = '/tmp/hiddify_clash';
    final workDir = Directory(_workingDir);
    if (!await workDir.exists()) {
      await workDir.create(recursive: true);
    }
  }

  Future<String> validateConfig(String config) async {
    try {
      // 简单的YAML验证
      if (config.trim().isEmpty) {
        return "配置为空";
      }

      // 检查基本的YAML格式
      if (!config.contains('port:') || !config.contains('proxies:')) {
        return "配置格式不正确";
      }

      return ""; // 空字符串表示验证成功
    } catch (e) {
      return "配置验证失败: $e";
    }
  }

  Future<void> setState(CoreState state) async {
    loggy.debug("设置核心状态: ${state.toJson()}");
    // 这里可以处理状态设置
  }

  Future<String> setupConfig(SetupParams config) async {
    try {
      _configPath = '$_workingDir/config.yaml';
      final configFile = File(_configPath);
      await configFile.writeAsString(config.config);

      loggy.debug("配置文件已保存到: $_configPath");
      return ""; // 空字符串表示成功
    } catch (e) {
      loggy.error("保存配置失败: $e");
      return "保存配置失败: $e";
    }
  }

  Future<void> startListener() async {
    try {
      loggy.debug("启动ClashMeta进程");

      // 尝试使用本地的clash可执行文件
      String clashBinary = 'clash';

      // 检查是否有可用的clash二进制文件
      try {
        final result = await Process.run('which', ['clash']);
        if (result.exitCode != 0) {
          // 如果没有系统clash，使用我们复制的核心
          clashBinary = '${Directory.current.path}/clashcore/clash';

          // 如果核心文件不存在，使用基本的HTTP代理模拟
          if (!await File(clashBinary).exists()) {
            loggy.warning("Clash二进制文件不存在，使用模拟模式");
            return;
          }
        }
      } catch (e) {
        loggy.warning("无法检查clash二进制文件: $e");
      }

      _process = await Process.start(
        clashBinary,
        ['-f', _configPath, '-d', _workingDir],
        workingDirectory: _workingDir,
      );

      // 监听输出
      _outputSubscription = _process!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        loggy.debug("Clash输出: $line");
      });

      _errorSubscription = _process!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        loggy.warning("Clash错误: $line");
      });

      loggy.debug("ClashMeta进程启动成功");
    } catch (e) {
      loggy.error("启动ClashMeta进程失败: $e");
      rethrow;
    }
  }

  Future<void> stopListener() async {
    try {
      await _outputSubscription?.cancel();
      await _errorSubscription?.cancel();

      _process?.kill(ProcessSignal.sigterm);
      await _process?.exitCode;

      loggy.debug("ClashMeta进程已停止");
    } catch (e) {
      loggy.error("停止ClashMeta进程失败: $e");
    }
  }

  Future<void> shutdown() async {
    await stopListener();
    loggy.debug("ClashCore已关闭");
  }

  void resetConnections() {
    loggy.debug("重置连接");
    // 这里可以实现连接重置逻辑
  }

  Future<Traffic> getTraffic() async {
    // 返回模拟的流量数据
    return const Traffic(up: 1024, down: 2048);
  }

  Future<Traffic> getTotalTraffic() async {
    // 返回模拟的总流量数据
    return const Traffic(up: 1024000, down: 2048000);
  }

  Future<List<Group>> getProxiesGroups() async {
    // 返回模拟的代理组数据
    return [
      const Group(
        tag: 'PROXY',
        type: GroupType.Selector,
        now: 'DIRECT',
        all: [
          Proxy(tag: 'DIRECT', type: 'direct'),
          Proxy(tag: 'REJECT', type: 'reject'),
        ],
      ),
    ];
  }

  Future<String> changeProxy(ChangeProxyParams params) async {
    loggy.debug("切换代理: ${params.groupName} -> ${params.proxyName}");
    // 这里可以实现代理切换逻辑
    return ""; // 空字符串表示成功
  }

  Future<Delay> getDelay(String testUrl, String proxyName) async {
    loggy.debug("测试延迟: $proxyName -> $testUrl");
    // 返回模拟的延迟数据
    return Delay(
      name: proxyName,
      value: 100, // 模拟100ms延迟
      url: testUrl,
    );
  }
}
