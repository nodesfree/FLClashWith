// lib/clash/models/clash_models.dart

class ChangeProxyParams {
  final String groupName;
  final String proxyName;

  const ChangeProxyParams({
    required this.groupName,
    required this.proxyName,
  });

  Map<String, dynamic> toJson() {
    return {
      'groupName': groupName,
      'proxyName': proxyName,
    };
  }
}
