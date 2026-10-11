import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Oslo Sentralstasjon: default map centre / fallback when no location is available.
const LatLng kOsloCentre = LatLng(59.9111, 10.7528);

/// Great-circle distance in metres (haversine). The app has no routing backend, so
/// every client-computed distance is a straight-line ESTIMATE.
double haversineMeters(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = _rad(b.latitude - a.latitude);
  final dLon = _rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.latitude)) *
          math.cos(_rad(b.latitude)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

double _rad(double deg) => deg * math.pi / 180;

/// Average urban speed used for duration estimates (km/h).
const double kAssumedAverageSpeedKmh = 30;

/// Duration estimate in seconds for a straight-line distance (never below 60 s).
int estimateDurationSeconds(double meters) {
  final seconds = meters / (kAssumedAverageSpeedKmh * 1000 / 3600);
  return math.max(60, seconds.round());
}

/// Straight line subdivided into [segments] points. Used as the mock "route".
List<LatLng> interpolatePolyline(LatLng a, LatLng b, {int segments = 24}) {
  return List.generate(segments + 1, (i) {
    final t = i / segments;
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  });
}

LatLng lerpLatLng(LatLng a, LatLng b, double t) {
  final c = t.clamp(0.0, 1.0);
  return LatLng(
    a.latitude + (b.latitude - a.latitude) * c,
    a.longitude + (b.longitude - a.longitude) * c,
  );
}
