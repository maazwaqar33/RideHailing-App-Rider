import '../../rides/domain/ride_models.dart';

/// Rider-visible things that happen while polling a ride.
enum RideEventType {
  driverAssigned,
  driverEnRoute,
  driverArrived,
  tripStarted,
  tripCompleted,
  rideCancelled,
}

class RideEvent {
  const RideEvent(this.type, this.rideId);

  final RideEventType type;
  final int rideId;

  @override
  String toString() => 'RideEvent($type, ride $rideId)';
}

/// The stage shown in the tracking UI. Derived only from the REAL ride status
/// returned by polling: nothing here is invented client-side.
enum TrackingStage {
  searching,
  driverAssigned,
  driverOnTheWay,
  driverArrived,
  inTrip,
  completed,
  cancelled,
}

abstract final class RideStatusMachine {
  /// Position of a status in the forward-only lifecycle. `offered` may regress to `requested` (driver declined).
  static int _rank(RideStatus s) => switch (s) {
    RideStatus.requested => 0,
    RideStatus.offered => 1,
    RideStatus.accepted => 2,
    RideStatus.driverEnRoute => 3,
    RideStatus.arrived => 4,
    RideStatus.inProgress => 5,
    RideStatus.completed => 6,
    RideStatus.cancelled => 6,
    RideStatus.unknown => -1,
  };

  static TrackingStage stageOf(RideStatus s) => switch (s) {
    RideStatus.requested ||
    RideStatus.offered ||
    RideStatus.unknown => TrackingStage.searching,
    RideStatus.accepted => TrackingStage.driverAssigned,
    RideStatus.driverEnRoute => TrackingStage.driverOnTheWay,
    RideStatus.arrived => TrackingStage.driverArrived,
    RideStatus.inProgress => TrackingStage.inTrip,
    RideStatus.completed => TrackingStage.completed,
    RideStatus.cancelled => TrackingStage.cancelled,
  };

  /// Events produced by moving from [from] (null = first fetch) to [to].
  /// Polling can skip intermediate states (e.g. a scripted driver moving faster than the poll),
  /// so every milestone crossed is reported, in order. The first fetch emits nothing:
  /// opening a ride that is already `arrived` must not re-fire the arrival alert.
  static List<RideEvent> eventsBetween(
    RideStatus? from,
    RideStatus to,
    int rideId,
  ) {
    if (from == null || from == to || to == RideStatus.unknown) return const [];
    if (to == RideStatus.cancelled) {
      return [RideEvent(RideEventType.rideCancelled, rideId)];
    }
    final events = <RideEvent>[];
    final fromRank = _rank(from);
    void crossed(RideStatus milestone, RideEventType type) {
      final r = _rank(milestone);
      if (fromRank < r && _rank(to) >= r) events.add(RideEvent(type, rideId));
    }

    crossed(RideStatus.accepted, RideEventType.driverAssigned);
    crossed(RideStatus.driverEnRoute, RideEventType.driverEnRoute);
    crossed(RideStatus.arrived, RideEventType.driverArrived);
    crossed(RideStatus.inProgress, RideEventType.tripStarted);
    crossed(RideStatus.completed, RideEventType.tripCompleted);
    return events;
  }

  /// Polling stops once the ride is terminal.
  static bool shouldKeepPolling(RideStatus s) => !s.isTerminal;
}
