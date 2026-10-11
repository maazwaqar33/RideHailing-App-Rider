import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_exception.dart';
import '../../rides/application/ride_providers.dart';
import '../../rides/domain/ride_models.dart';

enum BookingStatus { idle, submitting, failed, created }

class BookingState {
  const BookingState({
    this.status = BookingStatus.idle,
    this.ride,
    this.error,
    this.idempotencyKey,
    this.lastRequest,
  });

  final BookingStatus status;
  final Ride? ride;
  final ApiException? error;

  /// Reused when the SAME request is retried so the server returns the original ride instead of a duplicate.
  final String? idempotencyKey;
  final CreateRideRequest? lastRequest;

  bool get isSubmitting => status == BookingStatus.submitting;

  /// 409 from POST rides: the rider already has an active ride.
  bool get hasActiveRideConflict => error?.isConflict ?? false;
}

class BookingController extends Notifier<BookingState> {
  static const _uuid = Uuid();

  @override
  BookingState build() => const BookingState();

  /// Requests a ride. Returns the created ride or null on failure.
  ///
  /// * Re-entrancy guard: taps while a request is in flight are ignored.
  /// * Idempotency-Key: one key per distinct request, reused for retries of the same body.
  Future<Ride?> submit(CreateRideRequest request) async {
    if (state.isSubmitting) return null;
    final key = (state.lastRequest == request && state.idempotencyKey != null)
        ? state.idempotencyKey!
        : _uuid.v4();
    state = BookingState(
      status: BookingStatus.submitting,
      idempotencyKey: key,
      lastRequest: request,
    );
    try {
      final ride = await ref
          .read(rideRepositoryProvider)
          .create(request, idempotencyKey: key);
      ref.invalidate(activeRideProvider);
      state = BookingState(
        status: BookingStatus.created,
        ride: ride,
        idempotencyKey: key,
        lastRequest: request,
      );
      return ride;
    } on ApiException catch (e) {
      state = BookingState(
        status: BookingStatus.failed,
        error: e,
        idempotencyKey: key,
        lastRequest: request,
      );
      return null;
    }
  }

  /// Forget the previous attempt (new booking = new idempotency key).
  void reset() => state = const BookingState();
}

final bookingControllerProvider =
    NotifierProvider<BookingController, BookingState>(BookingController.new);
