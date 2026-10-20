import 'package:geolocator/geolocator.dart';

import '../domain/device_location.dart';

class AndroidDeviceLocation implements DeviceLocation {
  @override
  Future<GeoAccess> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) return GeoAccess.disabled;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return GeoAccess.blocked;
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return GeoAccess.denied;
    }
    final accuracy = await Geolocator.getLocationAccuracy();
    return accuracy == LocationAccuracyStatus.reduced
        ? GeoAccess.approximate
        : GeoAccess.precise;
  }

  @override
  Stream<GeoFix> fixes() =>
      Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
            ),
          )
          .map(
            (p) => GeoFix(
              p.latitude,
              p.longitude,
              p.accuracy,
              p.timestamp,
              mocked: p.isMocked,
            ),
          )
          .handleError((Object error) {
            if (error is LocationServiceDisabledException) {
              throw const GeoFailure(GeoIssue.disabled);
            }
            if (error is PermissionDeniedException) {
              throw const GeoFailure(GeoIssue.denied);
            }
            throw const GeoFailure(GeoIssue.unavailable);
          });

  @override
  Future<bool> openSettings({required bool app}) =>
      app ? Geolocator.openAppSettings() : Geolocator.openLocationSettings();
}
