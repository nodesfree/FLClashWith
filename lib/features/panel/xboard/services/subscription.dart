// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:hiddify/clash/panel_subscription_adapter.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/panel/xboard/services/http_service/user_service.dart';
import 'package:hiddify/features/panel/xboard/utils/storage/token_storage.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hiddify/features/profile/overview/profiles_overview_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class Subscription {
  static final UserService _userService = UserService();
  static final PanelSubscriptionAdapter _panelAdapter = PanelSubscriptionAdapter();

  // 公共方法：处理获取新订阅链接的逻辑（使用ClashMeta适配器）
  static Future<void> _handleSubscription(BuildContext context, WidgetRef ref, Future<String?> Function(String) getSubscriptionLink) async {
    final t = ref.watch(translationsProvider);
    final accessToken = await TokenStorage.getToken();
    if (accessToken == null) {
      _showSnackbar(context, t.userInfo.noAccessToken);
      return;
    }

    try {
      // 使用新的面板订阅适配器
      final success = await _panelAdapter.updatePanelSubscription(ref);

      if (success) {
        // 显示成功提示
        _showSnackbar(context, getSubscriptionLink == _userService.resetSubscriptionLink ? t.userInfo.subscriptionResetSuccess : t.userInfo.subscriptionUpdateSuccess);
      } else {
        throw Exception("订阅更新失败");
      }
    } catch (e) {
      _showSnackbar(context, "${getSubscriptionLink == _userService.resetSubscriptionLink ? t.userInfo.subscriptionResetError : t.userInfo.subscriptionUpdateError} $e");
    }
  }

  // 更新订阅的方法
  static Future<void> updateSubscription(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await _handleSubscription(context, ref, _userService.getSubscriptionLink);
  }

  // 重置订阅的方法
  static Future<void> resetSubscription(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await _handleSubscription(
      context,
      ref,
      _userService.resetSubscriptionLink,
    );
  }

  // 显示提示信息
  static void _showSnackbar(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
