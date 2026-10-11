import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../features/map/domain/map_models.dart';
import '../features/map/domain/map_repositories.dart';

/// MOCK adapter: deterministic pseudo-random cars around a point. These markers are
/// NOT real vehicles (the backend has no nearby-cars endpoint) and are labelled as demo.
class MockNearbyCarsRepository implements NearbyCarsRepository {
  const MockNearbyCarsRepository({this.count = 4});

  final int count;

  @override
  Future<List<NearbyCar>> carsNear(LatLng position) async {
    // Seed from the rounded position so cars don't jump on every rebuild.
    final seed =
        (position.latitude * 1000).round() * 31 +
        (position.longitude * 1000).round();
    final rnd = math.Random(seed);
    return List.generate(count, (i) {
      final bearing = rnd.nextDouble() * 2 * math.pi;
      final distanceDeg =
          0.022 + rnd.nextDouble() * 0.035; // ~2.5-6 km (city overview)
      final lat = position.latitude + distanceDeg * math.cos(bearing);
      final lng = position.longitude + distanceDeg * math.sin(bearing) * 2;
      return NearbyCar(
        id: 'mock-car-$i',
        position: LatLng(lat, lng),
        etaMinutes: 2 + rnd.nextInt(6),
      );
    });
  }
}

/// MOCK: re-centres the demo cars on [center] within about 0.4-1 km so they are visible on zoomed-in
/// route maps (ride selection, fleets). Same cars and ETAs, only the positions change.
List<NearbyCar> carsAround(LatLng center, List<NearbyCar> cars) => [
  for (final (i, c) in cars.indexed)
    NearbyCar(
      id: c.id,
      etaMinutes: c.etaMinutes,
      position: LatLng(
        center.latitude + 0.0045 * math.cos(i * 1.7 + 0.6) * (1 + i % 2 * 0.5),
        center.longitude + 0.0095 * math.sin(i * 1.7 + 0.6) * (1 + i % 2 * 0.5),
      ),
    ),
];
