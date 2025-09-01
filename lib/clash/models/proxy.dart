// lib/clash/models/proxy.dart

class Proxy {
  final String tag;
  final String type;

  const Proxy({
    required this.tag,
    required this.type,
  });

  factory Proxy.fromJson(Map<String, dynamic> json) {
    return Proxy(
      tag: json['name'] ?? '',
      type: json['type'] ?? '',
    );
  }
}
