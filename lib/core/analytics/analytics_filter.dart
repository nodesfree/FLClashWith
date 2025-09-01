// Analytics filter - Sentry functionality temporarily disabled
import 'dart:async';

import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/features/proxy/model/proxy_failure.dart';

// Placeholder for Sentry event handling
Map<String, dynamic>? sentryBeforeSend(Map<String, dynamic> event, Map<String, dynamic>? hint) {
  // Temporarily disabled - would normally filter events before sending to Sentry
  return null;
}

Map<String, dynamic> createUserInfo() {
  return {
    'email': '',
    'username': '', 
    'ipAddress': '0.0.0.0',
  };
}

bool canSendEvent(dynamic throwable) {
  return switch (throwable) {
    UnexpectedFailure(:final error) => canSendEvent(error),
    ProxyFailure _ => false,
    _ => false,
  };
}