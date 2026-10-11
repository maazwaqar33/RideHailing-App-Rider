import 'package:latlong2/latlong.dart';

import '../core/geo/geo.dart';
import '../features/map/domain/map_models.dart';
import '../features/map/domain/map_repositories.dart';
import 'oslo_places.dart';

/// MOCK adapter: searches the local Oslo dataset. Replace with a real geocoder/places
/// provider by implementing [PlaceSearchRepository] and overriding the provider.
class MockPlaceSearchRepository implements PlaceSearchRepository {
  const MockPlaceSearchRepository({this.places = kOsloPlaces});

  final List<Place> places;

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('ø', 'o')
      .replaceAll('å', 'a')
      .replaceAll('æ', 'ae')
      .replaceAll('ü', 'u')
      .trim();

  @override
  Future<List<Place>> search(String query, {LatLng? near}) async {
    final q = _norm(query);
    if (q.isEmpty) return suggestions(near: near);
    final hits = places
        .where((p) => _norm(p.name).contains(q) || _norm(p.address).contains(q))
        .toList();
    return _sortByDistance(hits, near);
  }

  @override
  Future<List<Place>> suggestions({LatLng? near}) async =>
      _sortByDistance(places.take(8).toList(), near);

  @override
  Future<Place?> nearestKnownPlace(
    LatLng position, {
    double withinMeters = 150,
  }) async {
    Place? best;
    var bestDistance = double.infinity;
    for (final p in places) {
      final d = haversineMeters(position, p.position);
      if (d < bestDistance) {
        bestDistance = d;
        best = p;
      }
    }
    return bestDistance <= withinMeters ? best : null;
  }

  List<Place> _sortByDistance(List<Place> list, LatLng? near) {
    if (near == null) return list;
    final copy = [...list];
    copy.sort(
      (a, b) => haversineMeters(
        near,
        a.position,
      ).compareTo(haversineMeters(near, b.position)),
    );
    return copy;
  }
}
