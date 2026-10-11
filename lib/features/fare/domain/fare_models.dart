import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../../rides/domain/ride_models.dart';

/// Where a fare estimate came from. UI MUST label non-backend estimates.
enum FareSource {
  /// POST fares/estimate answered by the real backend.
  backend,

  /// The backend was unreachable; a local mock calculator produced the number.
  /// Never bookable and always shown with a warning.
  mockFallback,
}

class FareEstimateRequest extends Equatable {
  const FareEstimateRequest({
    required this.distanceMeters,
    required this.durationSeconds,
    this.pickup,
    this.dropoff,
    this.pickupAddress,
    this.dropoffAddress,
  });

  final int distanceMeters;
  final int durationSeconds;
  final LatLng? pickup;
  final LatLng? dropoff;
  final String? pickupAddress;
  final String? dropoffAddress;

  Map<String, dynamic> toJson() => {
    'distance_meters': distanceMeters,
    'duration_seconds': durationSeconds,
    if (pickup != null)
      'pickup': {
        'latitude': double.parse(pickup!.latitude.toStringAsFixed(6)),
        'longitude': double.parse(pickup!.longitude.toStringAsFixed(6)),
        if (pickupAddress != null) 'address': pickupAddress,
      },
    if (dropoff != null)
      'dropoff': {
        'latitude': double.parse(dropoff!.latitude.toStringAsFixed(6)),
        'longitude': double.parse(dropoff!.longitude.toStringAsFixed(6)),
        if (dropoffAddress != null) 'address': dropoffAddress,
      },
  };

  @override
  List<Object?> get props => [
    distanceMeters,
    durationSeconds,
    pickup,
    dropoff,
    pickupAddress,
    dropoffAddress,
  ];
}

class FareEstimate extends Equatable {
  const FareEstimate({
    required this.breakdown,
    required this.source,
    this.distanceSource,
    this.fallbackReason,
  });

  final FareBreakdown breakdown;
  final FareSource source;

  /// `client_supplied` from the API: distance/duration came from this app, not a router.
  final String? distanceSource;

  /// Why the mock fallback was used (shown to the rider).
  final String? fallbackReason;

  bool get isMock => false;

  int get totalMinor => breakdown.totalMinor;
  String get currency => breakdown.currency;

  @override
  List<Object?> get props => [
    breakdown,
    source,
    distanceSource,
    fallbackReason,
  ];
}
