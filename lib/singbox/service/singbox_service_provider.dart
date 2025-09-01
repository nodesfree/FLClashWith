import 'package:hiddify/clash/clash_adapter_service.dart';
import 'package:hiddify/singbox/service/singbox_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'singbox_service_provider.g.dart';

@Riverpod(keepAlive: true)
SingboxService singboxService(SingboxServiceRef ref) {
  // 使用ClashMeta适配器替换原有的SingboxService
  return ClashAdapterService();
}
