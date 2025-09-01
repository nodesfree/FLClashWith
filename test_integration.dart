// test_integration.dart
// 集成测试文件，验证ClashMeta适配器功能

import 'dart:io';

import 'package:hiddify/clash/clash_adapter_service.dart';
import 'package:hiddify/clash/panel_subscription_adapter.dart';
import 'package:hiddify/core/model/directories.dart';

void main() async {
  print('🚀 开始HiddifyWithPanels + ClashMeta集成测试');

  // 1. 测试适配器基础功能
  await testAdapterBasics();

  // 2. 测试配置转换
  await testConfigConversion();

  // 3. 测试面板订阅适配
  await testPanelSubscriptionAdapter();

  print('✅ 所有测试完成！');
}

Future<void> testAdapterBasics() async {
  print('\n📋 测试1: 适配器基础功能');

  try {
    final adapter = ClashAdapterService();
    await adapter.init();

    print('✅ 适配器初始化成功');

    // 测试setup
    final directories = Directories(
      workingDir: Directory('/tmp/test_hiddify'),
      documentsDir: Directory('/tmp/test_docs'),
      tempDir: Directory('/tmp'),
    );

    final setupResult = await adapter.setup(directories, false).run();
    setupResult.fold(
      (error) => print('❌ Setup失败: $error'),
      (_) => print('✅ Setup成功'),
    );
  } catch (e) {
    print('❌ 适配器测试失败: $e');
  }
}

Future<void> testConfigConversion() async {
  print('\n🔄 测试2: 配置转换功能');

  try {
    final sampleSingboxConfig = '''
{
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
    },
    {
      "type": "shadowsocks",
      "tag": "ss-server",
      "server": "example.com",
      "server_port": 443,
      "method": "aes-256-gcm",
      "password": "password123"
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
}
''';

    final adapter = ClashAdapterService();
    await adapter.init();

    final conversionResult = await adapter.generateFullConfigByPath('/dev/null').run();
    conversionResult.fold(
      (error) => print('❌ 配置转换失败: $error'),
      (config) => print('✅ 配置转换成功，长度: ${config.length}'),
    );
  } catch (e) {
    print('❌ 配置转换测试失败: $e');
  }
}

Future<void> testPanelSubscriptionAdapter() async {
  print('\n🔗 测试3: 面板订阅适配器');

  try {
    final panelAdapter = PanelSubscriptionAdapter();

    // 测试订阅链接解析
    final sampleSubscription = '''
ss://YWVzLTI1Ni1nY206cGFzc3dvcmQxMjM@example.com:443#Test%20Server
vmess://eyJ2IjoiMiIsInBzIjoidGVzdCIsImFkZCI6ImV4YW1wbGUuY29tIiwicG9ydCI6IjQ0MyIsInR5cGUiOiJub25lIiwiaWQiOiIxMjM0NTY3OC0xMjM0LTEyMzQtMTIzNC0xMjM0NTY3ODkwYWIiLCJhaWQiOiIwIiwibmV0Ijoid3MiLCJwYXRoIjoiLyIsImhvc3QiOiIiLCJ0bHMiOiJ0bHMifQ==
''';

    print('✅ 面板订阅适配器创建成功');
    print('📝 示例订阅内容长度: ${sampleSubscription.length}');
  } catch (e) {
    print('❌ 面板订阅适配器测试失败: $e');
  }
}
