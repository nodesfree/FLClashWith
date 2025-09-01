// lib/clash/models/traffic.dart

class Traffic {
  final int up;
  final int down;

  const Traffic({
    this.up = 0,
    this.down = 0,
  });

  factory Traffic.fromMap(Map<String, dynamic> map) {
    return Traffic(
      up: (map['up'] ?? 0) as int,
      down: (map['down'] ?? 0) as int,
    );
  }
}
