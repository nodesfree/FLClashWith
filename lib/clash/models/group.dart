// lib/clash/models/group.dart

import 'package:hiddify/clash/models/proxy.dart';

enum GroupType {
  Selector,
  URLTest,
  Fallback,
  LoadBalance,
  Relay,
}

class Group {
  final String tag;
  final GroupType type;
  final String now;
  final List<Proxy> all;

  const Group({
    required this.tag,
    required this.type,
    required this.now,
    required this.all,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      tag: json['name'] ?? '',
      type: _parseGroupType(json['type'] ?? ''),
      now: json['now'] ?? '',
      all: (json['all'] as List? ?? []).map((e) => Proxy.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  static GroupType _parseGroupType(String type) {
    switch (type.toLowerCase()) {
      case 'select':
        return GroupType.Selector;
      case 'url-test':
        return GroupType.URLTest;
      case 'fallback':
        return GroupType.Fallback;
      case 'load-balance':
        return GroupType.LoadBalance;
      case 'relay':
        return GroupType.Relay;
      default:
        return GroupType.Selector;
    }
  }
}
