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

  /// 处理token过期的情况
  static Future<void> handleTokenExpiry({
    required BuildContext? context,
    required WidgetRef? ref,
    String? errorMessage,
  }) async {
    try {
      _logger.warning('处理token过期: $errorMessage');
      
      // 1. 清除本地存储的token
      await deleteToken();
      _logger.info('已清除本地token');
      
      // 2. 更新认证状态
      if (ref != null) {
        ref.read(authProvider.notifier).setLoggedIn(false);
        _logger.info('已更新认证状态为未登录');
      }
      
      // 3. 如果有上下文，跳转到登录页面
      if (context != null && context.mounted) {
        // 使用Navigator而不是GoRouter，避免依赖问题
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
        _logger.info('已跳转到登录页面');
      }
      
    } catch (e, stackTrace) {
      _logger.error('处理token过期时发生错误', e, stackTrace);
    }
  }
  
  /// 检查错误是否为token过期错误
  static bool isTokenExpiredError(dynamic error) {
    if (error == null) return false;
    
    final errorString = error.toString().toLowerCase();
    return errorString.contains('token已过期') ||
           errorString.contains('token无效') ||
           errorString.contains('未登录') ||
           errorString.contains('登陆已过期') ||
           errorString.contains('unauthorized') ||
           errorString.contains('401') ||
           errorString.contains('403');
  }
}

/// 全局token过期处理Provider
final tokenExpiryHandlerProvider = Provider<TokenExpiryHandler>((ref) {
  return TokenExpiryHandler();
});