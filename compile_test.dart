// compile_test.dart
// 快速编译测试，检查核心适配器的编译状态

import 'package:hiddify/clash/clash_adapter_service.dart';
import 'package:hiddify/singbox/model/singbox_config_option.dart';
import 'package:hiddify/core/model/directories.dart';

void main() async {
  print('🔍 开始编译测试...');
  
  try {
    // 测试ClashAdapterService是否能正常实例化
    final adapter = ClashAdapterService();
    print('✅ ClashAdapterService 实例化成功');
    
    // 测试基本配置
    final testOptions = SingboxConfigOption(
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
      urlTestInterval: const Duration(minutes: 10),
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
    print('✅ SingboxConfigOption 创建成功');
    
    // 测试directories
    final directories = Directories.temp();
    print('✅ Directories 创建成功');
    
    print('✅ 所有核心类型编译成功！');
    
  } catch (e) {
    print('❌ 编译测试失败: $e');
  }
}
