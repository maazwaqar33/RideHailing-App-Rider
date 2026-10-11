import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../../mock/mock_driver_telemetry.dart';
import '../../../mock/mock_ride_repository.dart';
import '../../rides/application/ride_providers.dart';
import '../../rides/domain/ride_models.dart';
import '../domain/driver_telemetry.dart';
import '../domain/ride_status_machine.dart';

/// Poll interval for ride status. Overridden in tests.
final pollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: Env.pollIntervalMs),
);

/// MOCK driver position source (no live-location endpoint in the backend).
final driverTelemetryProvider = Provider<DriverTelemetrySource>(
  (ref) => const MockDriverTelemetry(legSeconds: Env.mockDriverLegSeconds),
);

class RideTrackingState {
  const RideTrackingState({
    this.ride,
    this.error,
    this.loading = true,
    this.failureCount = 0,
    this.lastSyncedAt,
    this.events = const [],
    this.stopped = false,
  });

  final Ride? ride;

  /// Latest polling failure (kept alongside the last good [ride] so the UI can show a "reconnecting" strip).
  final ApiException? error;
  final bool loading;
  final int failureCount;
  final DateTime? lastSyncedAt;

  /// Milestones crossed by the most recent poll (arrival alert etc.). Replaced on every transition.
  final List<RideEvent> events;

  /// Polling ended (terminal status, 401, or 404).
  final bool stopped;

  TrackingStage? get stage =>
      ride == null ? null : RideStatusMachine.stageOf(ride!.status);

  RideTrackingState copyWith({
    Ride? ride,
    ApiException? error,
    bool clearError = false,
    bool? loading,
    int? failureCount,
    DateTime? lastSyncedAt,
    List<RideEvent>? events,
    bool? stopped,
  }) => RideTrackingState(
    ride: ride ?? this.ride,
    error: clearError ? null : (error ?? this.error),
    loading: loading ?? this.loading,
    failureCount: failureCount ?? this.failureCount,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    events: events ?? this.events,
    stopped: stopped ?? this.stopped,
  );
}

/// Polls GET rides/{id} (the backend has no websocket/realtime). One request at a time,
/// next poll scheduled only after the previous finished; interval backs off while failing
/// and polling stops at a terminal status.
class RideTrackingController extends Notifier<RideTrackingState> {
  RideTrackingController(this.rideId);

  final int rideId;
  Timer? _timer;
  Timer? _simTimer;
  bool _disposed = false;
  bool _inFlight = false;

  @override
  RideTrackingState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
      _simTimer?.cancel();
    });
    // Defer the first fetch until after build() returns the initial state.
    Future.microtask(poll);
    return const RideTrackingState();
  }

  Duration get _interval => ref.read(pollIntervalProvider);

  /// Fetches once. Safe to call manually (pull to refresh / after cancel).
  Future<void> poll() async {
    if (_disposed || _inFlight) return;
    _inFlight = true;
    _timer?.cancel();
    try {
      final ride = await ref.read(rideRepositoryProvider).get(rideId);
      if (_disposed) return;
      applyRide(ride);
    } on ApiException catch (e) {
      if (_disposed) return;
      final stop = e.isUnauthorized || e.kind == ApiErrorKind.notFound;
      state = state.copyWith(
        error: e,
        loading: false,
        failureCount: state.failureCount + 1,
        stopped: stop,
      );
      if (!stop) _schedule();
    } finally {
      _inFlight = false;
    }
  }

  /// Applies a ride received from anywhere (poll, cancel response). Detects milestones.
  void applyRide(Ride ride) {
    final previous = state.ride?.status;
    final events = RideStatusMachine.eventsBetween(
      previous,
      ride.status,
      ride.id,
    );
    final keepPolling = RideStatusMachine.shouldKeepPolling(ride.status);
    state = state.copyWith(
      ride: ride,
      loading: false,
      clearError: true,
      failureCount: 0,
      lastSyncedAt: DateTime.now(),
      events: events.isEmpty ? state.events : events,
      stopped: !keepPolling,
    );
    if (keepPolling) {
      _schedule();
      _maybeSimulateProgress(ride);
    } else {
      _timer?.cancel();
      _simTimer?.cancel();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (_disposed) return;
    final backoff = state.failureCount.clamp(0, 4) + 1;
    _timer = Timer(_interval * backoff, poll);
  }

  /// Simulates realistic driver dispatch & ride progression matching Stitch screens:
  /// Searching (3.5s) -> Erik Larsen matched (6s) -> En Route (6s) -> Arrived w/ PIN (6s) -> In Trip (7s) -> Complete.
  void _maybeSimulateProgress(Ride ride) {
    _simTimer?.cancel();
    if (_disposed || ride.status.isTerminal) return;

    final Duration delay;
    final Ride Function(Ride) nextStep;

    switch (ride.status) {
      case RideStatus.requested:
      case RideStatus.offered:
        delay = const Duration(milliseconds: 3500);
        nextStep = (r) {
          final now = DateTime.now();
          return r.copyWith(
            status: RideStatus.accepted,
            acceptedAt: now,
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
            timeline: [
              ...r.timeline,
              TimelineEntry(
                id: r.timeline.length + 1,
                fromStatus: r.status.apiValue,
                toStatus: RideStatus.accepted,
                actorRole: 'driver',
                createdAt: now,
              ),
            ],
          );
        };
      case RideStatus.accepted:
        delay = const Duration(seconds: 6);
        nextStep = (r) {
          final now = DateTime.now();
          return r.copyWith(
            status: RideStatus.driverEnRoute,
            driverEnRouteAt: now,
            timeline: [
              ...r.timeline,
              TimelineEntry(
                id: r.timeline.length + 1,
                fromStatus: r.status.apiValue,
                toStatus: RideStatus.driverEnRoute,
                actorRole: 'driver',
                createdAt: now,
              ),
            ],
          );
        };
      case RideStatus.driverEnRoute:
        delay = const Duration(seconds: 6);
        nextStep = (r) {
          final now = DateTime.now();
          return r.copyWith(
            status: RideStatus.arrived,
            arrivedAt: now,
            timeline: [
              ...r.timeline,
              TimelineEntry(
                id: r.timeline.length + 1,
                fromStatus: r.status.apiValue,
                toStatus: RideStatus.arrived,
                actorRole: 'driver',
                createdAt: now,
              ),
            ],
          );
        };
      case RideStatus.arrived:
        delay = const Duration(seconds: 6);
        nextStep = (r) {
          final now = DateTime.now();
          return r.copyWith(
            status: RideStatus.inProgress,
            startedAt: now,
            timeline: [
              ...r.timeline,
              TimelineEntry(
                id: r.timeline.length + 1,
                fromStatus: r.status.apiValue,
                toStatus: RideStatus.inProgress,
                actorRole: 'driver',
                createdAt: now,
              ),
            ],
          );
        };
      case RideStatus.inProgress:
        delay = const Duration(seconds: 7);
        nextStep = (r) {
          final now = DateTime.now();
          return r.copyWith(
            status: RideStatus.completed,
            completedAt: now,
            timeline: [
              ...r.timeline,
              TimelineEntry(
                id: r.timeline.length + 1,
                fromStatus: r.status.apiValue,
                toStatus: RideStatus.completed,
                actorRole: 'driver',
                createdAt: now,
              ),
            ],
          );
        };
      case RideStatus.completed:
      case RideStatus.cancelled:
      case RideStatus.unknown:
        return;
    }

    _simTimer = Timer(delay, () {
      if (_disposed) return;
      final current = state.ride;
      if (current == null || current.status != ride.status) return;
      final next = nextStep(current);
      MockRideRepository.updateRide(next);
      applyRide(next);
    });
  }

  /// Allows instantly advancing to the next stage during demonstration or testing.
  void advanceDemoStage() {
    _simTimer?.cancel();
    final current = state.ride;
    if (current == null || current.status.isTerminal) return;
    final now = DateTime.now();

    final Ride next;
    switch (current.status) {
      case RideStatus.requested:
      case RideStatus.offered:
        next = current.copyWith(
          status: RideStatus.accepted,
          acceptedAt: now,
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
          timeline: [
            ...current.timeline,
            TimelineEntry(
              id: current.timeline.length + 1,
              fromStatus: current.status.apiValue,
              toStatus: RideStatus.accepted,
              actorRole: 'driver',
              createdAt: now,
            ),
          ],
        );
      case RideStatus.accepted:
        next = current.copyWith(
          status: RideStatus.driverEnRoute,
          driverEnRouteAt: now,
          timeline: [
            ...current.timeline,
            TimelineEntry(
              id: current.timeline.length + 1,
              fromStatus: current.status.apiValue,
              toStatus: RideStatus.driverEnRoute,
              actorRole: 'driver',
              createdAt: now,
            ),
          ],
        );
      case RideStatus.driverEnRoute:
        next = current.copyWith(
          status: RideStatus.arrived,
          arrivedAt: now,
          timeline: [
            ...current.timeline,
            TimelineEntry(
              id: current.timeline.length + 1,
              fromStatus: current.status.apiValue,
              toStatus: RideStatus.arrived,
              actorRole: 'driver',
              createdAt: now,
            ),
          ],
        );
      case RideStatus.arrived:
        next = current.copyWith(
          status: RideStatus.inProgress,
          startedAt: now,
          timeline: [
            ...current.timeline,
            TimelineEntry(
              id: current.timeline.length + 1,
              fromStatus: current.status.apiValue,
              toStatus: RideStatus.inProgress,
              actorRole: 'driver',
              createdAt: now,
            ),
          ],
        );
      case RideStatus.inProgress:
        next = current.copyWith(
          status: RideStatus.completed,
          completedAt: now,
          timeline: [
            ...current.timeline,
            TimelineEntry(
              id: current.timeline.length + 1,
              fromStatus: current.status.apiValue,
              toStatus: RideStatus.completed,
              actorRole: 'driver',
              createdAt: now,
            ),
          ],
        );
      default:
        return;
    }

    MockRideRepository.updateRide(next);
    applyRide(next);
  }
}

final rideTrackingProvider = NotifierProvider.autoDispose
    .family<RideTrackingController, RideTrackingState, int>(
      RideTrackingController.new,
    );
