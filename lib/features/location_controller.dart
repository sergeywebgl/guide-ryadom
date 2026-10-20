import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/device_location.dart';

class LocationController extends ChangeNotifier {
  LocationController(
    this.provider, {
    this.timeout = const Duration(seconds: 45),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final DeviceLocation provider;
  final Duration timeout;
  final DateTime Function() now;
  GeoFix? fix;
  GeoAccess? access;
  GeoIssue? issue;
  bool busy = false, _disposed = false;
  int _epoch = 0;
  Timer? _timer;
  StreamSubscription<GeoFix>? _subscription;

  Future<void> locate() async {
    if (busy || _disposed) return;
    final epoch = ++_epoch;
    busy = true;
    fix = null;
    issue = null;
    access = null;
    notifyListeners();
    _timer = Timer(timeout, () => _finish(epoch, GeoIssue.timeout));
    try {
      final permission = await provider.requestAccess();
      if (!_active(epoch)) return;
      access = permission;
      switch (permission) {
        case GeoAccess.denied:
          _finish(epoch, GeoIssue.denied);
          return;
        case GeoAccess.blocked:
          _finish(epoch, GeoIssue.blocked);
          return;
        case GeoAccess.disabled:
          _finish(epoch, GeoIssue.disabled);
          return;
        case GeoAccess.precise:
        case GeoAccess.approximate:
          break;
      }
      _subscription = provider.fixes().listen(
        (value) {
          if (!_active(epoch) || !value.usable(now())) return;
          fix = value;
          _finish(epoch, null);
        },
        onError: (Object e) =>
            _finish(epoch, e is GeoFailure ? e.issue : GeoIssue.unavailable),
        onDone: () {
          if (_active(epoch)) _finish(epoch, GeoIssue.unavailable);
        },
      );
      // A synchronous stream may finish before listen returns.
      if (!_active(epoch)) {
        await _subscription?.cancel();
        _subscription = null;
      }
    } catch (e) {
      _finish(epoch, e is GeoFailure ? e.issue : GeoIssue.unavailable);
    }
  }

  bool _active(int epoch) => !_disposed && busy && _epoch == epoch;
  void _finish(int epoch, GeoIssue? failure) {
    if (!_active(epoch)) return;
    busy = false;
    issue = failure;
    _timer?.cancel();
    _timer = null;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    notifyListeners();
  }

  void cancel({bool clear = false}) {
    if (busy) _finish(_epoch, GeoIssue.cancelled);
    _epoch++;
    if (clear && !_disposed) {
      fix = null;
      notifyListeners();
    }
  }

  Future<void> settings({required bool app}) async {
    cancel(clear: true);
    try {
      if (!await provider.openSettings(app: app) && !_disposed) {
        issue = GeoIssue.unavailable;
        notifyListeners();
      }
    } catch (_) {
      if (!_disposed) {
        issue = GeoIssue.unavailable;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _timer?.cancel();
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }
}
