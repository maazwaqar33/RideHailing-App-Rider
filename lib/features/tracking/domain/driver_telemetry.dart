import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../../rides/domain/ride_models.dart';

/// A driver position for the map.
class DriverPosition extends Equatable {
  const DriverPosition({
    required this.position,
    required this.headingDegrees,
    required this.isSimulated,
    this.etaSeconds,
    this.remainingMeters,
  });

  final LatLng position;
  final double headingDegrees;

  /// TRUE for the mock adapter. The UI must label simulated positions as such.
  final bool isSimulated;

  /// Seconds until the driver reaches the current leg's target (pickup or drop-off), if known.
  final int? etaSeconds;
  final double? remainingMeters;

  @override
  List<Object?> get props => [
    position,
    headingDegrees,
    isSimulated,
    etaSeconds,
    remainingMeters,
  ];
}

/// Source of driver positions. The backend has NO live-location endpoint, so the only
/// implementation is the mock adapter in `lib/mock/mock_driver_telemetry.dart`.
/// A real source (websocket / polling endpoint) would implement this same interface.
abstract class DriverTelemetrySource {
  /// Position of the assigned driver for [ride] at [now], or null when no driver is on the map yet.
  DriverPosition? positionAt(Ride ride, DateTime now);
}
