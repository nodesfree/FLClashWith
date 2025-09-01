// lib/clash/models/change_proxy_params.dart
// 代理切换参数

class ChangeProxyParams {
  final String groupName;
  final String proxyName;

  const ChangeProxyParams({
    required this.groupName,
    required this.proxyName,
  });

  factory ChangeProxyParams.fromJson(Map<String, dynamic> json) {
    return ChangeProxyParams(
      groupName: (json['groupName'] ?? '') as String,
      proxyName: (json['proxyName'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupName': groupName,
      'proxyName': proxyName,
    };
  }
}
