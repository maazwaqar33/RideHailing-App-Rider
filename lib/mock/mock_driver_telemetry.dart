import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../core/geo/geo.dart';
import '../features/rides/domain/ride_models.dart';
import '../features/tracking/domain/driver_telemetry.dart';

/// MOCK adapter. Simulates a driver moving in a straight line:
///   accepted / driver_en_route : start point (~1.2 km from pickup) -> pickup
///   arrived                    : parked at pickup
///   in_progress                : pickup -> drop-off
///   completed                  : at drop-off
/// Timing is derived from the REAL status timestamps in the ride, but each leg is
/// compressed to [legSeconds] so the demo is watchable. This is NOT telemetry.
class MockDriverTelemetry implements DriverTelemetrySource {
  const MockDriverTelemetry({this.legSeconds = 90});

  final int legSeconds;

  /// Deterministic start point ~1.2 km from pickup, bearing derived from the ride id.
  static LatLng startPointFor(Ride ride) {
    final bearing = (ride.id * 67 % 360) * math.pi / 180;
    const d = 0.0108; // ~1.2 km in degrees of latitude
    final p = ride.pickup.latLng;
    return LatLng(
      p.latitude + d * math.cos(bearing),
      p.longitude + d * math.sin(bearing) * 2,
    );
  }

  double _progress(DateTime? since, DateTime now) {
    if (since == null) return 0;
    final elapsed = now.difference(since).inMilliseconds / 1000;
    return (elapsed / legSeconds).clamp(0.0, 0.98);
  }

  static double bearing(LatLng a, LatLng b) {
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  @override
  DriverPosition? positionAt(Ride ride, DateTime now) {
    final pickup = ride.pickup.latLng;
    final dropoff = ride.dropoff.latLng;
    switch (ride.status) {
      case RideStatus.accepted:
      case RideStatus.driverEnRoute:
        final start = startPointFor(ride);
        final p = _progress(ride.driverEnRouteAt ?? ride.acceptedAt, now);
        final remaining = haversineMeters(lerpLatLng(start, pickup, p), pickup);
        return DriverPosition(
          position: lerpLatLng(start, pickup, p),
          headingDegrees: bearing(start, pickup),
          isSimulated: true,
          remainingMeters: remaining,
          etaSeconds: estimateDurationSeconds(remaining),
        );
      case RideStatus.arrived:
        return DriverPosition(
          position: pickup,
          headingDegrees: bearing(startPointFor(ride), pickup),
          isSimulated: true,
          remainingMeters: 0,
          etaSeconds: 0,
        );
      case RideStatus.inProgress:
        final p = _progress(ride.startedAt, now);
        final pos = lerpLatLng(pickup, dropoff, p);
        final remaining = haversineMeters(pos, dropoff);
        return DriverPosition(
          position: pos,
          headingDegrees: bearing(pickup, dropoff),
          isSimulated: true,
          remainingMeters: remaining,
          etaSeconds: estimateDurationSeconds(remaining),
        );
      case RideStatus.completed:
        return DriverPosition(
          position: dropoff,
          headingDegrees: bearing(pickup, dropoff),
          isSimulated: true,
        );
      case RideStatus.requested:
      case RideStatus.offered:
      case RideStatus.cancelled:
      case RideStatus.unknown:
        return null;
    }
  }
}
