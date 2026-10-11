import 'ride_models.dart';

/// Rider-facing ride API (`/api/v1/rides*`). The rider is always the token's user.
abstract class RideRepository {
  /// POST rides. Pass the same [idempotencyKey] when retrying the same attempt:
  /// the server returns the original ride (HTTP 200) instead of a duplicate.
  /// Throws `ApiException(kind: conflict)` when the rider already has an active ride.
  Future<Ride> create(
    CreateRideRequest request, {
    required String idempotencyKey,
  });

  /// GET rides/{id} (includes timeline).
  Future<Ride> get(int id);

  /// GET rides?page=&per_page=&status= (rider sees only their own rides, newest first).
  Future<RidePage> list({int page = 1, int perPage = 15, RideStatus? status});

  /// GET rides/{id}/timeline.
  Future<List<TimelineEntry>> timeline(int id);

  /// POST rides/{id}/cancel {reason}.
  Future<Ride> cancel(int id, String reason);
}
