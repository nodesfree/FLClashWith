// test_app.dart
// 用于测试ClashMeta集成的简单Flutter应用

import 'package:flutter/material.dart';
import 'package:hiddify/clash/clash_adapter_service.dart';
import 'package:hiddify/singbox/model/singbox_config_option.dart';
import 'package:hiddify/core/directories/directories.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HiddifyWithPanels + ClashMeta 测试',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TestHomePage(),
    );
  }
}

class TestHomePage extends StatefulWidget {
  const TestHomePage({super.key});

  @override
  State<TestHomePage> createState() => _TestHomePageState();
}

class _TestHomePageState extends State<TestHomePage> {
  final ClashAdapterService _clashAdapter = ClashAdapterService();
  String _status = '未连接';
  String _logs = '';
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _setupStatusListener();
  }

  void _setupStatusListener() {
    _clashAdapter.watchStatus().listen((status) {
      setState(() {
        _status = _getStatusText(status);
      });
      _addLog('状态变化: $_status');
    });
  }

  String _getStatusText(dynamic status) {
    switch (status.toString()) {
      case 'SingboxStopped':
        return '已停止';
      case 'SingboxStarting':
        return '正在启动';
      case 'SingboxStarted':
        return '已连接';
      default:
        return status.toString();
    }
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _logs = '[$timestamp] $message\n$_logs';
    });
  }

  Future<void> _testConnection() async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      _addLog('🚀 开始测试ClashMeta集成...');

      // 设置目录
      final directories = Directories.temp(); // 使用临时目录
      
      // 初始化适配器
      _addLog('📂 初始化适配器...');
      final setupResult = await _clashAdapter.setup(directories, true);
      
      setupResult.fold(
        (error) {
          _addLog('❌ 初始化失败: $error');
        },
        (_) {
          _addLog('✅ 适配器初始化成功');
        },
      );

      // 测试配置验证
      _addLog('🔍 测试配置验证...');
      final testConfig = _createTestConfig();
      final configPath = '${directories.working}/test_config.json';
      
      // 这里简化处理，实际应用中会有完整的配置文件
      _addLog('📄 使用测试配置');
      
      // 测试启动
      _addLog('🔥 启动ClashMeta服务...');
      final startResult = await _clashAdapter.start(configPath, _getTestOptions());
      
      startResult.fold(
        (error) {
          _addLog('❌ 启动失败: $error');
        },
        (_) {
          _addLog('✅ ClashMeta启动成功！');
        },
      );

      // 等待状态稳定
      await Future.delayed(const Duration(seconds: 2));

      // 测试停止
      _addLog('🛑 停止服务...');
      await _clashAdapter.stop();
      _addLog('✅ 测试完成');

    } catch (e) {
      _addLog('💥 测试异常: $e');
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Map<String, dynamic> _createTestConfig() {
    return {
      "log": {"level": "info"},
      "inbounds": [
        {
          "type": "mixed",
          "listen": "127.0.0.1",
          "listen_port": 7890
        }
      ],
      "outbounds": [
        {
          "type": "direct",
          "tag": "direct"
        }
      ],
      "route": {
        "rules": [
          {
            "geoip": ["private"],
            "outbound": "direct"
          }
        ]
      }
    };
  }

  SingboxConfigOption _getTestOptions() {
    return const SingboxConfigOption(
      executeConfigAsIs: false,
      enableClashApi: true,
      enableTun: false,
      setSystemProxy: false,
      mixedPort: 7890,
      localDnsPort: 6450,
      tunImplementation: TunImplementation.system,
      mtu: 1500,
      strictRoute: true,
      connectionTestUrl: "http://www.gstatic.com/generate_204",
      urlTestInterval: Duration(minutes: 10),
      enableFakeIp: false,
      independentDnsCache: false,
      bypassLan: true,
      allowConnectionFromLan: false,
      enableTlsFragment: false,
      tlsFragmentSize: 10,
      tlsFragmentSleep: 50,
      enableTlsMixedSniCase: false,
      enableTlsPadding: false,
      tlsPaddingSize: 100,
      enableMux: false,
      muxProtocol: MuxProtocol.h2mux,
      muxMaxConnections: 4,
      muxMinUploadBytes: 16384,
      muxPadding: false,
      logLevel: LogLevel.warn,
      resolveDestination: false,
      ipv6Mode: IPv6Mode.disable,
      remoteDnsAddress: "tls://8.8.8.8",
      remoteDnsDomainStrategy: DomainStrategy.auto,
      directDnsAddress: "8.8.8.8",
      directDnsDomainStrategy: DomainStrategy.auto,
      mixedRuleSet: false,
      localRuleSet: true,
      enableWarp: false,
      warpDetourMode: WarpDetourMode.inOut,
      warpLicenseKey: "",
      warpCleanIp: "",
      warpPort: 0,
      warpNoise: "",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('ClashMeta 集成测试'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      '当前状态',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: _status == '已连接' ? Colors.green : 
                               _status == '已停止' ? Colors.red : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isConnecting ? null : _testConnection,
              icon: _isConnecting 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
              label: Text(_isConnecting ? '测试中...' : '开始测试'),
            ),
            const SizedBox(height: 16),
            Text(
              '测试日志',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SingleChildScrollView(
                    child: Text(
                      _logs.isEmpty ? '暂无日志' : _logs,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
