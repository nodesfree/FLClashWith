// lib/features/panel/xboard/services/token_expiry_handler.dart
// 全局token过期处理服务

import 'package:flutter/widgets.dart';
import 'package:hiddify/features/panel/xboard/services/auth_provider.dart';
import 'package:hiddify/features/panel/xboard/utils/storage/token_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loggy/loggy.dart';

class TokenExpiryHandler {
  static final TokenExpiryHandler _instance = TokenExpiryHandler._internal();
  factory TokenExpiryHandler() => _instance;
  TokenExpiryHandler._internal();

  static final _logger = Loggy('TokenExpiryHandler');

  /// 处理认证错误的情况（token可能过期，需要清除并重新登录）
  static Future<void> handleAuthError({
    required BuildContext? context,
    required WidgetRef? ref,
    String? errorMessage,
  }) async {
    try {
      _logger.warning('处理认证错误: $errorMessage');
      
      // 清除过期的token和auth_data
      await TokenStorage.deleteAllCredentials();
      _logger.info('已清除过期的认证凭据');
      
      // 更新认证状态为未登录
      if (ref != null) {
        ref.read(authProvider.notifier).setLoggedIn(false);
        _logger.info('已更新认证状态为未登录');
      }
      
      // 如果有上下文，提示用户重新登录
      if (context != null && context.mounted) {
        // 使用Navigator而不是GoRouter，避免依赖问题
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
        _logger.info('已跳转到登录页面');
      }
      
    } catch (e, stackTrace) {
      _logger.error('处理认证错误时发生错误', e, stackTrace);
    }
  }
  
  /// 检查错误是否为认证错误（token可能过期，需要重新登录）
  static bool isAuthError(dynamic error) {
    if (error == null) return false;
    
    final errorString = error.toString().toLowerCase();
    // 检查服务器返回的认证错误信息
    return errorString.contains('未登录或登陆已过期') ||
           errorString.contains('未登录') ||
           errorString.contains('登陆已过期') ||
           errorString.contains('访问被拒绝') ||
           errorString.contains('unauthorized') ||
           errorString.contains('401') ||
           errorString.contains('403');
  }
}

/// 全局token过期处理Provider
final tokenExpiryHandlerProvider = Provider<TokenExpiryHandler>((ref) {
  return TokenExpiryHandler();
});