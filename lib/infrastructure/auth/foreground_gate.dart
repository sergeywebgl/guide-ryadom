import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/auth.dart';

/// The callback can arrive while the browser is still the foreground app.
Future<void> waitForAndroidForeground(
  Future<void> cancelled, {
  Duration timeout = const Duration(minutes: 1),
}) async {
  final binding = WidgetsBinding.instance;
  if (binding.lifecycleState == AppLifecycleState.resumed) return;
  final resumed = Completer<void>();
  final listener = AppLifecycleListener(
    binding: binding,
    onStateChange: (state) {
      if (state == AppLifecycleState.resumed && !resumed.isCompleted) {
        resumed.complete();
      }
    },
  );
  try {
    await Future.any<void>([
      resumed.future,
      cancelled.then<void>((_) => throw const AuthFailure('cancelled')),
    ]).timeout(timeout);
  } finally {
    listener.dispose();
  }
}
