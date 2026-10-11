import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../domain/map_repositories.dart';

/// Real device location via geolocator. Permission denial, disabled services,
/// timeouts and platform errors all degrade to a status; this never throws.
class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(status: LocationStatus.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(status: LocationStatus.denied);
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(status: LocationStatus.deniedForever);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LocationResult(
        status: LocationStatus.granted,
        position: LatLng(pos.latitude, pos.longitude),
      );
    } catch (_) {
      return const LocationResult(status: LocationStatus.unavailable);
    }
  }
}
