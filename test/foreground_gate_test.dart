import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guide_ryadom/domain/auth.dart';
import 'package:guide_ryadom/infrastructure/auth/foreground_gate.dart';

void background(WidgetsBinding binding) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    binding.handleAppLifecycleStateChanged(state);
  }
}

void foreground(WidgetsBinding binding) {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  testWidgets(
    'foreground adapter waits through hidden and inactive until resumed',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      background(tester.binding);
      var ready = false;
      final waiting = waitForAndroidForeground(Completer<void>().future)
          .then((_) => ready = true);
      await tester.pump();
      expect(ready, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(ready, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await waiting;
      expect(ready, isTrue);
      await waitForAndroidForeground(Completer<void>().future);
    },
  );

  testWidgets('cancellation removes foreground wait without later completion', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    background(tester.binding);
    final cancel = Completer<void>();
    final checked = expectLater(
      waitForAndroidForeground(cancel.future),
      throwsA(isA<AuthFailure>().having((e) => e.code, 'code', 'cancelled')),
    );
    cancel.complete();
    await tester.pump();
    await checked;
    foreground(tester.binding);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('foreground wait times out and cleans up', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    background(tester.binding);
    final checked = expectLater(
      waitForAndroidForeground(
        Completer<void>().future,
        timeout: const Duration(seconds: 1),
      ),
      throwsA(isA<TimeoutException>()),
    );
    await tester.pump(const Duration(seconds: 2));
    await checked;
    foreground(tester.binding);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
