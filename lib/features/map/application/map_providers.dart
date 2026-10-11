import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/geo/geo.dart';
import '../../../core/providers.dart';
import '../../../mock/mock_fare_estimator.dart';
import '../../../mock/mock_nearby_cars.dart';
import '../../../mock/mock_place_search.dart';
import '../../../mock/mock_route_service.dart';
import '../../fare/domain/fare_models.dart';
import '../../fare/domain/fare_repository.dart';
import '../../rides/domain/ride_models.dart';
import '../data/geolocator_location_service.dart';
import '../data/local_places_store.dart';
import '../domain/map_models.dart';
import '../domain/map_repositories.dart';

// ---------------------------------------------------------------------------
// Repository selection. Swap a mock for a real implementation by overriding
// the matching provider (see README "How to replace mocks").
// ---------------------------------------------------------------------------

/// MOCK: no places API exists.
final placeSearchRepositoryProvider = Provider<PlaceSearchRepository>(
  (ref) => const MockPlaceSearchRepository(),
);

/// MOCK: no routing backend exists (straight line + haversine).
final routeRepositoryProvider = Provider<RouteRepository>(
  (ref) => const MockRouteService(),
);

/// MOCK: no nearby-cars endpoint exists.
final nearbyCarsRepositoryProvider = Provider<NearbyCarsRepository>(
  (ref) => const MockNearbyCarsRepository(),
);

final locationServiceProvider = Provider<LocationService>(
  (ref) => GeolocatorLocationService(),
);

final fareRepositoryProvider = Provider<FareRepository>((ref) {
  return const MockFareEstimator();
});

final localPlacesStoreProvider = Provider<LocalPlacesStore>(
  (ref) => LocalPlacesStore(ref.watch(sharedPreferencesProvider)),
);

// ---------------------------------------------------------------------------
// Location bootstrap
// ---------------------------------------------------------------------------

/// Devices further than this from Oslo are treated as "outside the demo area".
const double kDemoAreaRadiusMeters = 60000;

class StartLocation {
  const StartLocation({
    required this.position,
    required this.status,
    this.bannerMessage,
    this.isFallback = false,
  });

  final LatLng position;
  final LocationStatus status;

  /// Friendly explanation shown over the map when we fell back to Oslo.
  final String? bannerMessage;
  final bool isFallback;
}

/// Resolves where the map/pickup should start. Permission denied, GPS off, an error or a device
/// outside Oslo all fall back to Oslo S with a friendly banner: it never throws.
final startLocationProvider = FutureProvider<StartLocation>((ref) async {
  final result = await ref.watch(locationServiceProvider).current();
  final pos = result.position;
  if (pos != null) {
    if (haversineMeters(pos, kOsloCentre) <= kDemoAreaRadiusMeters) {
      return StartLocation(position: pos, status: result.status);
    }
    return StartLocation(
      position: kOsloCentre,
      status: result.status,
      isFallback: true,
      bannerMessage: null,
    );
  }
  final message = switch (result.status) {
    LocationStatus.denied => 'Location permission denied. Showing Oslo S. You can still pick a pickup point.',
    LocationStatus.deniedForever => 'Location is blocked for this app. Showing Oslo S. Enable it in system settings to use your position.',
    LocationStatus.serviceDisabled =>
      'Location services are off. Showing Oslo S.',
    _ => "We couldn't get your location. Showing Oslo S.",
  };
  return StartLocation(
    position: kOsloCentre,
    status: result.status,
    isFallback: true,
    bannerMessage: message,
  );
});

// ---------------------------------------------------------------------------
// Trip plan (pickup, drop-off, vehicle preference, payment choice)
// ---------------------------------------------------------------------------

@immutable
class TripPlan {
  const TripPlan({
    this.pickup,
    this.dropoff,
    this.vehicle = VehicleChoice.sedan,
    this.payment = PaymentMethodType.cash,
    this.pickupNote = '',
  });

  final Place? pickup;
  final Place? dropoff;

  /// Optional hint for the driver. The API has no note field, so it is appended to the pickup
  /// `address` string (drivers see the address) when the ride is requested.
  final String pickupNote;
  final VehicleChoice vehicle;
  final PaymentMethodType payment;

  bool get isComplete => pickup != null && dropoff != null;

  TripPlan copyWith({
    Place? pickup,
    Place? dropoff,
    bool clearDropoff = false,
    VehicleChoice? vehicle,
    PaymentMethodType? payment,
    String? pickupNote,
  }) => TripPlan(
    pickup: pickup ?? this.pickup,
    dropoff: clearDropoff ? null : (dropoff ?? this.dropoff),
    vehicle: vehicle ?? this.vehicle,
    payment: payment ?? this.payment,
    pickupNote: pickupNote ?? this.pickupNote,
  );
}

class TripPlanController extends Notifier<TripPlan> {
  @override
  TripPlan build() => const TripPlan();

  /// Sets pickup from the device (or Oslo fallback) once, if the rider hasn't chosen one.
  Future<void> ensurePickup() async {
    if (state.pickup != null) return;
    final start = await ref.read(startLocationProvider.future);
    if (state.pickup != null) return;
    final known = await ref
        .read(placeSearchRepositoryProvider)
        .nearestKnownPlace(start.position);
    final place =
        known ??
        Place(
          id: 'current',
          name: start.isFallback ? 'Oslo S (default)' : 'Current location',
          address: start.isFallback
              ? 'Jernbanetorget, Oslo'
              : '${start.position.latitude.toStringAsFixed(5)}, ${start.position.longitude.toStringAsFixed(5)}',
          position: start.position,
          kind: PlaceKind.pin,
        );
    state = state.copyWith(pickup: place);
  }

  /// Re-book: reuse a past ride's pickup and drop-off.
  void prefillFromRide(Ride ride) {
    Place place(RideLocation l, String id) => Place(
      id: id,
      name: l.title,
      address:
          '${l.latitude.toStringAsFixed(5)}, ${l.longitude.toStringAsFixed(5)}',
      position: l.latLng,
      kind: PlaceKind.pin,
    );
    state = state.copyWith(
      pickup: place(ride.pickup, 'rebook-pickup'),
      dropoff: place(ride.dropoff, 'rebook-dropoff'),
    );
  }

  void setPickup(Place place) => state = state.copyWith(pickup: place);
  void setDropoff(Place place) => state = state.copyWith(dropoff: place);
  void clearDropoff() => state = state.copyWith(clearDropoff: true);
  void setVehicle(VehicleChoice v) => state = state.copyWith(vehicle: v);
  void setPayment(PaymentMethodType m) => state = state.copyWith(payment: m);
  void setPickupNote(String note) =>
      state = state.copyWith(pickupNote: note.trim());

  /// After a ride is booked the destination is cleared; pickup is kept.
  void resetAfterBooking() => state = TripPlan(
    pickup: state.pickup,
    payment: state.payment,
    vehicle: state.vehicle,
  );
}

final tripPlanProvider = NotifierProvider<TripPlanController, TripPlan>(
  TripPlanController.new,
);

/// Client-computed (mock) route for the current plan, or null until both ends are set.
final routeProvider = FutureProvider.autoDispose<RouteInfo?>((ref) async {
  final pickup = ref.watch(tripPlanProvider.select((p) => p.pickup));
  final dropoff = ref.watch(tripPlanProvider.select((p) => p.dropoff));
  if (pickup == null || dropoff == null) return null;
  return ref
      .watch(routeRepositoryProvider)
      .route(pickup.position, dropoff.position);
});

/// REAL POST fares/estimate for the computed route (mock fallback only if unreachable).
final fareEstimateProvider = FutureProvider.autoDispose<FareEstimate?>((
  ref,
) async {
  final route = await ref.watch(routeProvider.future);
  final pickup = ref.watch(tripPlanProvider.select((p) => p.pickup));
  final dropoff = ref.watch(tripPlanProvider.select((p) => p.dropoff));
  if (route == null || pickup == null || dropoff == null) return null;
  return ref
      .watch(fareRepositoryProvider)
      .estimate(
        FareEstimateRequest(
          distanceMeters: route.distanceMeters,
          durationSeconds: route.durationSeconds,
          pickup: pickup.position,
          dropoff: dropoff.position,
          pickupAddress: pickup.apiAddress,
          dropoffAddress: dropoff.apiAddress,
        ),
      );
});

/// MOCK nearby cars around the pickup.
final nearbyCarsProvider = FutureProvider.autoDispose<List<NearbyCar>>((
  ref,
) async {
  final pickup = ref.watch(tripPlanProvider.select((p) => p.pickup));
  final centre =
      pickup?.position ??
      (await ref.watch(startLocationProvider.future)).position;
  return ref.watch(nearbyCarsRepositoryProvider).carsNear(centre);
});

/// Minimum distance to book (the API rejects 0 m rides; also avoids silly trips).
const int kMinTripMeters = 100;
