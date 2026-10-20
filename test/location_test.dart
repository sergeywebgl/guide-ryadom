import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guide_ryadom/domain/device_location.dart';
import 'package:guide_ryadom/features/location_controller.dart';
import 'package:guide_ryadom/features/location_page.dart';

class FakeLocation implements DeviceLocation {
  final stream = StreamController<GeoFix>();
  GeoAccess access = GeoAccess.precise;
  Completer<GeoAccess>? pending;
  int requests = 0, subscriptions = 0;
  bool? settingsApp;
  @override
  Future<GeoAccess> requestAccess() async {
    requests++;
    return pending == null ? access : await pending!.future;
  }

  @override
  Stream<GeoFix> fixes() {
    subscriptions++;
    return stream.stream;
  }

  @override
  Future<bool> openSettings({required bool app}) async {
    settingsApp = app;
    return true;
  }
}

void main() {
  final now = DateTime.utc(2026, 10, 20);
  test('fix validation rejects stale, future, nonfinite and out of range', () {
    expect(GeoFix(52, 0, 20, now).usable(now), isTrue);
    for (final fix in [
      GeoFix(91, 0, 20, now),
      GeoFix(52, 181, 20, now),
      GeoFix(double.nan, 0, 20, now),
      GeoFix(52, 0, -1, now),
      GeoFix(52, 0, 20, now.subtract(const Duration(seconds: 31))),
      GeoFix(52, 0, 20, now.add(const Duration(seconds: 6))),
    ]) {
      expect(fix.usable(now), isFalse);
    }
  });
  for (final access in [
    GeoAccess.denied,
    GeoAccess.blocked,
    GeoAccess.disabled,
  ]) {
    test('$access never subscribes', () async {
      final p = FakeLocation()..access = access;
      final c = LocationController(p);
      await c.locate();
      expect(c.issue?.name, access.name);
      expect(p.subscriptions, 0);
      c.dispose();
    });
  }
  test(
    'first fresh approximate fix stops updates; duplicate taps ignored',
    () async {
      final p = FakeLocation()..access = GeoAccess.approximate;
      final c = LocationController(p, now: () => now);
      expect(p.requests, 0);
      await c.locate();
      await c.locate();
      p.stream.add(GeoFix(52, 0, 12, now.subtract(const Duration(minutes: 2))));
      await Future<void>.delayed(Duration.zero);
      expect(c.fix, isNull);
      expect(c.busy, isTrue);
      p.stream.add(GeoFix(52, 0, 1000, now));
      await Future<void>.delayed(Duration.zero);
      expect(c.fix?.accuracy, 1000);
      expect(c.access, GeoAccess.approximate);
      expect(c.busy, isFalse);
      expect(p.stream.hasListener, isFalse);
      expect(p.requests, 1);
      c.dispose();
    },
  );
  test('cancel ignores a late permission grant', () async {
    final p = FakeLocation()..pending = Completer<GeoAccess>();
    final c = LocationController(p);
    final request = c.locate();
    c.cancel();
    p.pending!.complete(GeoAccess.precise);
    await request;
    expect(p.subscriptions, 0);
    expect(c.issue, GeoIssue.cancelled);
    c.dispose();
  });
  testWidgets('timeout cancels stream and reports timeout', (tester) async {
    final p = FakeLocation();
    final c = LocationController(p, timeout: const Duration(seconds: 1));
    await c.locate();
    await tester.pump(const Duration(seconds: 2));
    expect(c.issue, GeoIssue.timeout);
    expect(p.stream.hasListener, isFalse);
    c.dispose();
  });
  test('stream error and early close fail safely', () async {
    for (final error in [true, false]) {
      final p = FakeLocation();
      final c = LocationController(p);
      await c.locate();
      if (error) {
        p.stream.addError(const GeoFailure(GeoIssue.disabled));
      } else {
        unawaited(p.stream.close());
      }
      await Future<void>.delayed(Duration.zero);
      expect(c.issue, error ? GeoIssue.disabled : GeoIssue.unavailable);
      expect(c.fix, isNull);
      c.dispose();
    }
  });
  testWidgets(
    'page requests only on tap, background cancels, no automatic resume',
    (tester) async {
      final p = FakeLocation();
      await tester.pumpWidget(MaterialApp(home: LocationPage(provider: p)));
      expect(p.requests, 0);
      await tester.tap(find.text('Определить местоположение'));
      await tester.pump();
      expect(p.stream.hasListener, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(p.stream.hasListener, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(p.requests, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('blocked permission offers settings; compact large text fits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = FakeLocation()..access = GeoAccess.blocked;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: LocationPage(provider: p),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Определить местоположение'),
      200,
    );
    await tester.tap(find.text('Определить местоположение'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Настройки разрешений'), 200);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Настройки разрешений'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки разрешений'));
    await tester.pump();
    expect(p.settingsApp, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
