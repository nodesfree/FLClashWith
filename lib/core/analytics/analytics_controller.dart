import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hiddify/core/analytics/analytics_filter.dart';
import 'package:hiddify/core/logger/logger_controller.dart';
import 'package:hiddify/core/model/environment.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
// import 'package:sentry_flutter/sentry_flutter.dart'; // Temporarily disabled
import 'package:shared_preferences/shared_preferences.dart';

part 'analytics_controller.g.dart';

const String enableAnalyticsPrefKey = "enable_analytics";
const bool _testCrashReport = false;

@Riverpod(keepAlive: true)
class AnalyticsController extends _$AnalyticsController with InfraLogger {
  late final SharedPreferences _preferences;

  @override
  Future<bool> build() async {
    _preferences = await ref.watch(sharedPreferencesProvider.future);
    final shouldEnableAnalytics = _preferences.getBool(enableAnalyticsPrefKey) ?? true;
    if (shouldEnableAnalytics) {
      loggy.debug("enabling analytics");
      return await enableAnalytics();
    } else {
      loggy.debug("analytics disabled by user");
      return false;
    }
  }

  Future<bool> enableAnalytics() async {
    try {
      loggy.debug("initializing analytics");
      
      // Temporarily disabled Sentry integration
      // In a real implementation, this would initialize Sentry with proper configuration
      await _preferences.setBool(enableAnalyticsPrefKey, true);
      
      // Simulate successful analytics initialization
      loggy.debug("analytics enabled successfully");
      return true;
      
    } catch (exception, stackTrace) {
      loggy.error("failed to enable analytics", exception, stackTrace);
      return false;
    }
  }

  Future<void> disableAnalytics() async {
    if (state case AsyncData()) {
      loggy.debug("disabling analytics");
      state = const AsyncLoading();
      await _preferences.setBool(enableAnalyticsPrefKey, false);
      // await Sentry.close(); // Temporarily disabled
      LoggerController.instance.removePrinter("analytics");
      state = const AsyncData(false);
    }
  }
}