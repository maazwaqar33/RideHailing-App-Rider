import 'package:latlong2/latlong.dart';

import '../core/geo/geo.dart';
import '../features/map/domain/map_models.dart';
import '../features/map/domain/map_repositories.dart';

/// MOCK adapter: there is no routing backend. The "route" is a straight line subdivided
/// into points; distance is the haversine (great-circle) length and duration assumes
/// [kAssumedAverageSpeedKmh]. Always an ESTIMATE.
class MockRouteService implements RouteRepository {
  const MockRouteService();

  @override
  Future<RouteInfo> route(LatLng from, LatLng to) async {
    final meters = haversineMeters(from, to);
    return RouteInfo(
      points: interpolatePolyline(from, to),
      distanceMeters: meters.round(),
      durationSeconds: estimateDurationSeconds(meters),
    );
  }
}
