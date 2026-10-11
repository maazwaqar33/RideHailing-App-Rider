import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Ride lifecycle exactly as the backend state machine defines it
/// (requested > offered > accepted > driver_en_route > arrived > in_progress > completed | cancelled).
enum RideStatus {
  requested('requested'),
  offered('offered'),
  accepted('accepted'),
  driverEnRoute('driver_en_route'),
  arrived('arrived'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled'),
  unknown('unknown');

  const RideStatus(this.apiValue);

  final String apiValue;

  static RideStatus parse(String? value) => RideStatus.values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => RideStatus.unknown,
  );

  bool get isTerminal => this == completed || this == cancelled;
  bool get isActive => !isTerminal && this != unknown;

  /// Searching for a driver: requested (queue) or offered (waiting for the driver to accept).
  bool get isSearching => this == requested || this == offered;

  /// Rider may still cancel before pickup (API allows cancel until in_progress).
  bool get canRiderCancel =>
      this == requested ||
      this == offered ||
      this == accepted ||
      this == driverEnRoute ||
      this == arrived;

  /// A driver/vehicle is assigned and details are shown to the rider.
  bool get hasDriver =>
      this == accepted ||
      this == driverEnRoute ||
      this == arrived ||
      this == inProgress ||
      this == completed;

  String get label => switch (this) {
    requested => 'Requested',
    offered => 'Finding a driver',
    accepted => 'Driver assigned',
    driverEnRoute => 'Driver on the way',
    arrived => 'Driver arrived',
    inProgress => 'In trip',
    completed => 'Completed',
    cancelled => 'Cancelled',
    unknown => 'Unknown',
  };
}

/// Backend `PaymentMethod` enum values the rider can pick. (`invoice` exists server-side but is staff-only.)
enum PaymentMethodType {
  cash('cash', 'Cash to driver'),
  card('card', 'Card');

  const PaymentMethodType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PaymentMethodType parse(String? value) =>
      PaymentMethodType.values.firstWhere(
        (m) => m.apiValue == value,
        orElse: () => PaymentMethodType.cash,
      );
}

class RideLocation extends Equatable {
  const RideLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  factory RideLocation.fromJson(Map<String, dynamic> json) => RideLocation(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    address: json['address'] as String?,
  );

  final double latitude;
  final double longitude;
  final String? address;

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
    'latitude': double.parse(latitude.toStringAsFixed(6)),
    'longitude': double.parse(longitude.toStringAsFixed(6)),
    if (address != null) 'address': address,
  };

  String get title => (address == null || address!.trim().isEmpty)
      ? '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}'
      : address!;

  @override
  List<Object?> get props => [latitude, longitude, address];
}

/// Driver data a rider may see (`RideResource.driver`): no photo, no rating exist in the API.
class RideDriver extends Equatable {
  const RideDriver({required this.id, required this.firstName, this.phone});

  factory RideDriver.fromJson(Map<String, dynamic> json) => RideDriver(
    id: (json['id'] as num).toInt(),
    firstName: (json['first_name'] as String?) ?? 'Driver',
    phone: json['phone'] as String?,
  );

  final int id;
  final String firstName;
  final String? phone;

  @override
  List<Object?> get props => [id, firstName, phone];
}

class RideVehicle extends Equatable {
  const RideVehicle({
    required this.plateNumber,
    this.make,
    this.model,
    this.colour,
  });

  factory RideVehicle.fromJson(Map<String, dynamic> json) => RideVehicle(
    plateNumber: (json['plate_number'] as String?) ?? '',
    make: json['make'] as String?,
    model: json['model'] as String?,
    colour: json['colour'] as String?,
  );

  final String plateNumber;
  final String? make;
  final String? model;
  final String? colour;

  String get displayName =>
      [make, model].where((s) => s != null && s.isNotEmpty).join(' ');

  @override
  List<Object?> get props => [plateNumber, make, model, colour];
}

/// `fare.breakdown` (rider view: commission and rule id are hidden by the API).
class FareBreakdown extends Equatable {
  const FareBreakdown({
    required this.currency,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.baseFareMinor,
    required this.distanceChargeMinor,
    required this.timeChargeMinor,
    required this.rawFareMinor,
    required this.minimumFareAdjustmentMinor,
    required this.fareMinor,
    required this.bookingFeeMinor,
    required this.taxMinor,
    required this.totalMinor,
  });

  factory FareBreakdown.fromJson(
    Map<String, dynamic> json, {
    String? fallbackCurrency,
  }) {
    int i(String key) => (json[key] as num?)?.toInt() ?? 0;
    return FareBreakdown(
      currency: (json['currency'] as String?) ?? fallbackCurrency ?? 'EUR',
      distanceMeters: i('distance_meters'),
      durationSeconds: i('duration_seconds'),
      baseFareMinor: i('base_fare_minor'),
      distanceChargeMinor: i('distance_charge_minor'),
      timeChargeMinor: i('time_charge_minor'),
      rawFareMinor: i('raw_fare_minor'),
      minimumFareAdjustmentMinor: i('minimum_fare_adjustment_minor'),
      fareMinor: i('fare_minor'),
      bookingFeeMinor: i('booking_fee_minor'),
      taxMinor: i('tax_minor'),
      totalMinor: i('total_minor'),
    );
  }

  final String currency;
  final int distanceMeters;
  final int durationSeconds;
  final int baseFareMinor;
  final int distanceChargeMinor;
  final int timeChargeMinor;
  final int rawFareMinor;
  final int minimumFareAdjustmentMinor;
  final int fareMinor;
  final int bookingFeeMinor;
  final int taxMinor;
  final int totalMinor;

  @override
  List<Object?> get props => [
    currency,
    distanceMeters,
    durationSeconds,
    baseFareMinor,
    distanceChargeMinor,
    timeChargeMinor,
    rawFareMinor,
    minimumFareAdjustmentMinor,
    fareMinor,
    bookingFeeMinor,
    taxMinor,
    totalMinor,
  ];
}

class RideFare extends Equatable {
  const RideFare({
    required this.currency,
    this.estimateMinor,
    this.finalMinor,
    this.breakdown,
  });

  factory RideFare.fromJson(Map<String, dynamic> json) {
    final currency = (json['currency'] as String?) ?? 'EUR';
    final b = json['breakdown'];
    return RideFare(
      currency: currency,
      estimateMinor: (json['estimate_minor'] as num?)?.toInt(),
      finalMinor: (json['final_minor'] as num?)?.toInt(),
      breakdown: b is Map && b.isNotEmpty
          ? FareBreakdown.fromJson(
              Map<String, dynamic>.from(b),
              fallbackCurrency: currency,
            )
          : null,
    );
  }

  final String currency;
  final int? estimateMinor;
  final int? finalMinor;
  final FareBreakdown? breakdown;

  /// What the rider owes: final fare once completed, otherwise the estimate.
  int? get payableMinor => finalMinor ?? estimateMinor;

  @override
  List<Object?> get props => [currency, estimateMinor, finalMinor, breakdown];
}

class RidePayment extends Equatable {
  const RidePayment({required this.method, required this.status});

  factory RidePayment.fromJson(Map<String, dynamic> json) => RidePayment(
    method: (json['method'] as String?) ?? 'cash',
    status: (json['status'] as String?) ?? 'not_charged',
  );

  /// Raw backend values (`cash|card|invoice`, `not_charged|pending`). Demo only: nothing is ever charged.
  final String method;
  final String status;

  @override
  List<Object?> get props => [method, status];
}

class TimelineEntry extends Equatable {
  const TimelineEntry({
    required this.id,
    this.fromStatus,
    required this.toStatus,
    this.actorRole,
    this.reason,
    this.createdAt,
  });

  factory TimelineEntry.fromJson(Map<String, dynamic> json) => TimelineEntry(
    id: (json['id'] as num).toInt(),
    fromStatus: json['from_status'] as String?,
    toStatus: RideStatus.parse(json['to_status'] as String?),
    actorRole: json['actor_role'] as String?,
    reason: json['reason'] as String?,
    createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
  );

  final int id;
  final String? fromStatus;
  final RideStatus toStatus;
  final String? actorRole;
  final String? reason;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [
    id,
    fromStatus,
    toStatus,
    actorRole,
    reason,
    createdAt,
  ];
}

class Ride extends Equatable {
  const Ride({
    required this.id,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.fare,
    required this.payment,
    this.driver,
    this.vehicle,
    this.requestedAt,
    this.acceptedAt,
    this.driverEnRouteAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.timeline = const [],
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    DateTime? ts(Map? m, String k) =>
        m == null ? null : DateTime.tryParse((m[k] as String?) ?? '');
    final t = json['timestamps'] as Map?;
    final cancellation = json['cancellation'] as Map?;
    final driver = json['driver'];
    final vehicle = json['vehicle'];
    return Ride(
      id: (json['id'] as num).toInt(),
      status: RideStatus.parse(json['status'] as String?),
      pickup: RideLocation.fromJson(
        Map<String, dynamic>.from(json['pickup'] as Map),
      ),
      dropoff: RideLocation.fromJson(
        Map<String, dynamic>.from(json['dropoff'] as Map),
      ),
      distanceMeters: (json['distance_meters'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      fare: RideFare.fromJson(
        Map<String, dynamic>.from((json['fare'] as Map?) ?? const {}),
      ),
      payment: RidePayment.fromJson(
        Map<String, dynamic>.from((json['payment'] as Map?) ?? const {}),
      ),
      driver: driver is Map
          ? RideDriver.fromJson(Map<String, dynamic>.from(driver))
          : null,
      vehicle: vehicle is Map
          ? RideVehicle.fromJson(Map<String, dynamic>.from(vehicle))
          : null,
      requestedAt: ts(t, 'requested_at'),
      acceptedAt: ts(t, 'accepted_at'),
      driverEnRouteAt: ts(t, 'driver_en_route_at'),
      arrivedAt: ts(t, 'arrived_at'),
      startedAt: ts(t, 'started_at'),
      completedAt: ts(t, 'completed_at'),
      cancelledAt: ts(t, 'cancelled_at'),
      cancellationReason: cancellation?['reason'] as String?,
      timeline: ((json['timeline'] as List?) ?? const [])
          .map(
            (e) => TimelineEntry.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }

  final int id;
  final RideStatus status;
  final RideLocation pickup;
  final RideLocation dropoff;
  final int distanceMeters;
  final int durationSeconds;
  final RideFare fare;
  final RidePayment payment;
  final RideDriver? driver;
  final RideVehicle? vehicle;
  final DateTime? requestedAt;
  final DateTime? acceptedAt;
  final DateTime? driverEnRouteAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final List<TimelineEntry> timeline;

  Ride copyWith({
    int? id,
    RideStatus? status,
    RideLocation? pickup,
    RideLocation? dropoff,
    int? distanceMeters,
    int? durationSeconds,
    RideFare? fare,
    RidePayment? payment,
    RideDriver? driver,
    RideVehicle? vehicle,
    DateTime? requestedAt,
    DateTime? acceptedAt,
    DateTime? driverEnRouteAt,
    DateTime? arrivedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    List<TimelineEntry>? timeline,
  }) => Ride(
    id: id ?? this.id,
    status: status ?? this.status,
    pickup: pickup ?? this.pickup,
    dropoff: dropoff ?? this.dropoff,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    fare: fare ?? this.fare,
    payment: payment ?? this.payment,
    driver: driver ?? this.driver,
    vehicle: vehicle ?? this.vehicle,
    requestedAt: requestedAt ?? this.requestedAt,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    driverEnRouteAt: driverEnRouteAt ?? this.driverEnRouteAt,
    arrivedAt: arrivedAt ?? this.arrivedAt,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    cancellationReason: cancellationReason ?? this.cancellationReason,
    timeline: timeline ?? this.timeline,
  );

  @override
  List<Object?> get props => [
    id,
    status,
    pickup,
    dropoff,
    distanceMeters,
    durationSeconds,
    fare,
    payment,
    driver,
    vehicle,
    requestedAt,
    acceptedAt,
    driverEnRouteAt,
    arrivedAt,
    startedAt,
    completedAt,
    cancelledAt,
    cancellationReason,
    timeline,
  ];
}

/// Body of POST rides. `vehicle type` is deliberately absent: the API has no such field.
class CreateRideRequest extends Equatable {
  const CreateRideRequest({
    required this.pickup,
    required this.dropoff,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.paymentMethod,
  });

  final RideLocation pickup;
  final RideLocation dropoff;
  final int distanceMeters;
  final int durationSeconds;
  final PaymentMethodType paymentMethod;

  Map<String, dynamic> toJson() => {
    'pickup': pickup.toJson(),
    'dropoff': dropoff.toJson(),
    'distance_meters': distanceMeters,
    'duration_seconds': durationSeconds,
    'payment_method': paymentMethod.apiValue,
  };

  @override
  List<Object?> get props => [
    pickup,
    dropoff,
    distanceMeters,
    durationSeconds,
    paymentMethod,
  ];
}

/// One page of the rider's ride history.
class RidePage {
  const RidePage({
    required this.rides,
    required this.currentPage,
    required this.lastPage,
  });

  final List<Ride> rides;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;
}

/// Reasons offered when cancelling. The backend stores a free-text `reason`.
const List<String> kCancelReasons = [
  'Plans changed',
  'Waiting too long',
  'Booked by mistake',
  'Found another ride',
  'Wrong pickup location',
  'Other',
];
