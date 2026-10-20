enum GeoAccess { precise, approximate, denied, blocked, disabled }

enum GeoIssue { denied, blocked, disabled, timeout, unavailable, cancelled }

class GeoFix {
  const GeoFix(
    this.latitude,
    this.longitude,
    this.accuracy,
    this.measuredAt, {
    this.mocked = false,
  });
  final double latitude, longitude, accuracy;
  final DateTime measuredAt;
  final bool mocked;
  bool usable(DateTime now) =>
      latitude.isFinite &&
      longitude.isFinite &&
      accuracy.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180 &&
      accuracy >= 0 &&
      now.difference(measuredAt) <= const Duration(seconds: 30) &&
      measuredAt.difference(now) <= const Duration(seconds: 5);
}

abstract interface class DeviceLocation {
  /// Called only after explicit user action. May show the OS permission dialog.
  Future<GeoAccess> requestAccess();
  Stream<GeoFix> fixes();
  Future<bool> openSettings({required bool app});
}

class GeoFailure implements Exception {
  const GeoFailure(this.issue);
  final GeoIssue issue;
}
