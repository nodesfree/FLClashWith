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
      name: json['name'] ?? '',
      value: json['value'] ?? -1,
      url: json['url'] ?? '',
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
