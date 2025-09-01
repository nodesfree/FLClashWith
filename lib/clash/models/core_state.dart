// lib/clash/models/core_state.dart

class CoreState {
  final bool enableTun;
  final bool tunMode;
  final int mixedPort;
  final int tproxyPort;
  final int dnsPort;
  final bool onlyProxy;

  const CoreState({
    required this.enableTun,
    required this.tunMode,
    required this.mixedPort,
    required this.tproxyPort,
    required this.dnsPort,
    required this.onlyProxy,
  });

  Map<String, dynamic> toJson() {
    return {
      'enableTun': enableTun,
      'tunMode': tunMode,
      'mixedPort': mixedPort,
      'tproxyPort': tproxyPort,
      'dnsPort': dnsPort,
      'onlyProxy': onlyProxy,
    };
  }
}
