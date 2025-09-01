import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/features/panel/xboard/utils/storage/token_storage.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';

final authProvider = StateNotifierProvider<AuthNotifier, bool>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<bool> {
  AuthNotifier() : super(false) {
    _checkInitialAuthState();
  }

  Future<void> _checkInitialAuthState() async {
    final token = await getToken();
    print('Retrieved token: $token');
    if (token != null && token.isNotEmpty) {
      print('Token found, setting user to logged in');
      state = true;
    } else {
      print('No token found, setting user to not logged in');
      state = false;
    }
  }

  void setLoggedIn(bool isLoggedIn) {
    state = isLoggedIn;
  }
}
// 定义一个登出函数
Future<void> logout(BuildContext context, WidgetRef ref) async {
  // 清除存储的 token
  await deleteToken();
  // 更新 authProvider 状态为未登录
  ref.read(authProvider.notifier).setLoggedIn(false);
  // 跳转到登录页面
  if (context.mounted) {
    context.go('/');
  }
}
