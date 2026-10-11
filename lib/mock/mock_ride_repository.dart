import 'dart:async';

import '../features/rides/domain/ride_models.dart';
import '../features/rides/domain/ride_repository.dart';

/// In-memory mock ride repository for offline and demo evaluation.
/// Enables full end-to-end ride lifecycle without requiring a live Laravel server.
class MockRideRepository implements RideRepository {
  MockRideRepository() {
    _seedDefaultRides();
  }

  static final Map<int, Ride> _store = {};
  static int _nextId = 101;

  static void _seedDefaultRides() {
    if (_store.isNotEmpty) return;
    final now = DateTime.now();
    final demoRide = Ride(
      id: 42,
      status: RideStatus.completed,
      pickup: const RideLocation(
        latitude: 59.9111,
        longitude: 10.7528,
        address: 'Oslo S, Jernbanetorget 1',
      ),
      dropoff: const RideLocation(
        latitude: 60.1976,
        longitude: 11.1004,
        address: 'Oslo Airport (OSL), Gardermoen',
      ),
      distanceMeters: 48500,
      durationSeconds: 2700,
      fare: const RideFare(
        currency: 'NOK',
        estimateMinor: 95000,
        finalMinor: 95000,
      ),
      payment: const RidePayment(method: 'card', status: 'completed'),
      driver: const RideDriver(
        id: 1,
        firstName: 'Erik',
        phone: '+47 412 34 567',
      ),
      vehicle: const RideVehicle(
        plateNumber: 'EK 94821',
        make: 'Toyota',
        model: 'Camry Hybrid',
        colour: 'Silver',
      ),
      requestedAt: now.subtract(const Duration(hours: 2)),
      completedAt: now.subtract(const Duration(hours: 1)),
      timeline: [
        TimelineEntry(
          id: 1,
          toStatus: RideStatus.requested,
          actorRole: 'rider',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        TimelineEntry(
          id: 2,
          toStatus: RideStatus.completed,
          actorRole: 'driver',
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
      ],
    );
    _store[demoRide.id] = demoRide;
  }

  static Ride? getRide(int id) {
    _seedDefaultRides();
    return _store[id];
  }

  static void updateRide(Ride ride) {
    _seedDefaultRides();
    _store[ride.id] = ride;
  }

  @override
  Future<Ride> create(
    CreateRideRequest request, {
    required String idempotencyKey,
  }) async {
    _seedDefaultRides();
    final id = _nextId++;
    final now = DateTime.now();
    final fareMinor = (request.distanceMeters * 1.8 * 10).round() + 5000;
    final ride = Ride(
      id: id,
      status: RideStatus.requested,
      pickup: request.pickup,
      dropoff: request.dropoff,
      distanceMeters: request.distanceMeters,
      durationSeconds: request.durationSeconds,
      fare: RideFare(
        currency: 'NOK',
        estimateMinor: fareMinor,
        finalMinor: fareMinor,
      ),
      payment: RidePayment(
        method: request.paymentMethod.apiValue,
        status: 'pending',
      ),
      requestedAt: now,
      timeline: [
        TimelineEntry(
          id: 1,
          toStatus: RideStatus.requested,
          actorRole: 'rider',
          createdAt: now,
        ),
      ],
    );
    _store[id] = ride;
    return ride;
  }

  @override
  Future<Ride> get(int id) async {
    _seedDefaultRides();
    if (_store.containsKey(id)) {
      return _store[id]!;
    }
    final now = DateTime.now();
    final fallback = Ride(
      id: id,
      status: RideStatus.requested,
      pickup: const RideLocation(
        latitude: 59.9111,
        longitude: 10.7528,
        address: 'Oslo S, Jernbanetorget 1',
      ),
      dropoff: const RideLocation(
        latitude: 60.1976,
        longitude: 11.1004,
        address: 'Oslo Airport (OSL)',
      ),
      distanceMeters: 48500,
      durationSeconds: 2700,
      fare: const RideFare(
        currency: 'NOK',
        estimateMinor: 89000,
        finalMinor: 89000,
      ),
      payment: const RidePayment(method: 'card', status: 'pending'),
      requestedAt: now,
      timeline: [
        TimelineEntry(
          id: 1,
          toStatus: RideStatus.requested,
          actorRole: 'rider',
          createdAt: now,
        ),
      ],
    );
    _store[id] = fallback;
    return fallback;
  }

  @override
  Future<RidePage> list({int page = 1, int perPage = 15, RideStatus? status}) async {
    _seedDefaultRides();
    var items = _store.values.toList().reversed.toList();
    if (status != null) {
      items = items.where((r) => r.status == status).toList();
    }
    return RidePage(
      rides: items,
      currentPage: page,
      lastPage: 1,
    );
  }

  @override
  Future<List<TimelineEntry>> timeline(int id) async {
    _seedDefaultRides();
    final ride = _store[id];
    return ride?.timeline ?? const [];
  }

  @override
  Future<Ride> cancel(int id, String reason) async {
    _seedDefaultRides();
    final current = await get(id);
    final now = DateTime.now();
    final updated = current.copyWith(
      status: RideStatus.cancelled,
      cancelledAt: now,
      cancellationReason: reason,
      timeline: [
        ...current.timeline,
        TimelineEntry(
          id: current.timeline.length + 1,
          fromStatus: current.status.apiValue,
          toStatus: RideStatus.cancelled,
          actorRole: 'rider',
          reason: reason,
          createdAt: now,
        ),
      ],
    );
    _store[id] = updated;
    return updated;
  }
}
