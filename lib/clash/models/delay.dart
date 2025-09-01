// lib/clash/models/delay.dart

class Delay {
  final String name;
  final int value;
  final String url;

  const Delay({
    required this.name,
    required this.value,
    required this.url,
  });

  factory Delay.fromJson(Map<String, dynamic> json) {
    return Delay(
      name: (json['name'] ?? '') as String,
      value: (json['value'] ?? -1) as int,
      url: (json['url'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'url': url,
    };
  }
}
