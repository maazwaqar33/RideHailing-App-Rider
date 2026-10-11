import 'package:latlong2/latlong.dart';

import 'map_models.dart';

/// Destination/pickup suggestions. The backend has no places endpoint,
/// so the only implementation today is the mock Oslo dataset.
abstract class PlaceSearchRepository {
  Future<List<Place>> search(String query, {LatLng? near});

  /// Popular/suggested places shown before typing.
  Future<List<Place>> suggestions({LatLng? near});

  /// Nearest known place to a map pin, or null if none is close.
  Future<Place?> nearestKnownPlace(
    LatLng position, {
    double withinMeters = 150,
  });
}

abstract class RouteRepository {
  Future<RouteInfo> route(LatLng from, LatLng to);
}

abstract class NearbyCarsRepository {
  Future<List<NearbyCar>> carsNear(LatLng position);
}

enum LocationStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  unavailable,
}

class LocationResult {
  const LocationResult({required this.status, this.position});

  final LocationStatus status;
  final LatLng? position;

  bool get hasPosition => position != null;
}

/// Device location. Implementations must never throw: failures become a [LocationResult].
abstract class LocationService {
  Future<LocationResult> current();
}
