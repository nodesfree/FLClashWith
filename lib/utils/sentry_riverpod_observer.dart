// Riverpod observer for Sentry - temporarily disabled
import 'package:hooks_riverpod/hooks_riverpod.dart';
// import 'package:sentry_flutter/sentry_flutter.dart'; // Temporarily disabled

class SentryRiverpodObserver extends ProviderObserver {
  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    // Temporarily disabled Sentry breadcrumb
    // Sentry.addBreadcrumb(
    //   Breadcrumb(
    //     message: 'Provider ${provider.name ?? provider.runtimeType} was initialized',
    //     category: 'riverpod.provider',
    //     level: SentryLevel.info,
    //     data: {
    //       'provider': provider.name ?? provider.runtimeType.toString(),
    //       'value': value.toString(),
    //     },
    //   ),
    // );
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    // Temporarily disabled Sentry breadcrumb
    // Could log provider updates here if needed for debugging
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    // Temporarily disabled Sentry breadcrumb
    // Could log provider disposal here if needed for debugging
  }
}