import 'package:equatable/equatable.dart';

import '../../rides/domain/ride_models.dart';

/// Rating + comment + tip chosen by the rider.
///
/// NOT sent to the backend: the API has no rating, review or tip endpoint, so this
/// is stored on the device only and will never appear in Admin.
class RideFeedback extends Equatable {
  const RideFeedback({
    required this.rideId,
    required this.rating,
    this.comment = '',
    this.tags = const [],
    this.tipMinor = 0,
    this.savedAt,
  });

  factory RideFeedback.fromJson(Map<String, dynamic> json) => RideFeedback(
    rideId: (json['rideId'] as num).toInt(),
    rating: (json['rating'] as num).toInt(),
    comment: (json['comment'] as String?) ?? '',
    tags: ((json['tags'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    tipMinor: (json['tipMinor'] as num?)?.toInt() ?? 0,
    savedAt: DateTime.tryParse((json['savedAt'] as String?) ?? ''),
  );

  final int rideId;
  final int rating;
  final String comment;
  final List<String> tags;
  final int tipMinor;
  final DateTime? savedAt;

  Map<String, dynamic> toJson() => {
    'rideId': rideId,
    'rating': rating,
    'comment': comment,
    'tags': tags,
    'tipMinor': tipMinor,
    'savedAt': (savedAt ?? DateTime.now()).toIso8601String(),
  };

  @override
  List<Object?> get props => [rideId, rating, comment, tags, tipMinor, savedAt];
}

/// "Report a problem" submission. MOCK: stored locally, never delivered anywhere.
class ProblemReport extends Equatable {
  const ProblemReport({
    required this.rideId,
    required this.category,
    required this.details,
    required this.createdAt,
  });

  factory ProblemReport.fromJson(Map<String, dynamic> json) => ProblemReport(
    rideId: (json['rideId'] as num).toInt(),
    category: (json['category'] as String?) ?? 'Other',
    details: (json['details'] as String?) ?? '',
    createdAt:
        DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
        DateTime.now(),
  );

  final int rideId;
  final String category;
  final String details;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'rideId': rideId,
    'category': category,
    'details': details,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [rideId, category, details, createdAt];
}

const List<String> kProblemCategories = [
  'Driver behaviour',
  'Vehicle condition',
  'Wrong fare',
  'Route issue',
  'Lost item',
  'Other',
];

/// Result of the MOCK payment confirmation. `isMock` is always true: nothing is charged.
/// The backend ride keeps `payment.status = not_charged`.
class PaymentReceipt extends Equatable {
  const PaymentReceipt({
    required this.rideId,
    required this.method,
    required this.amountMinor,
    required this.tipMinor,
    required this.currency,
    required this.reference,
    required this.confirmedAt,
  });

  factory PaymentReceipt.fromJson(Map<String, dynamic> json) => PaymentReceipt(
    rideId: (json['rideId'] as num).toInt(),
    method: PaymentMethodType.parse(json['method'] as String?),
    amountMinor: (json['amountMinor'] as num).toInt(),
    tipMinor: (json['tipMinor'] as num?)?.toInt() ?? 0,
    currency: (json['currency'] as String?) ?? 'EUR',
    reference: (json['reference'] as String?) ?? '',
    confirmedAt:
        DateTime.tryParse((json['confirmedAt'] as String?) ?? '') ??
        DateTime.now(),
  );

  final int rideId;
  final PaymentMethodType method;
  final int amountMinor;
  final int tipMinor;
  final String currency;
  final String reference;
  final DateTime confirmedAt;

  bool get isMock => true;

  Map<String, dynamic> toJson() => {
    'rideId': rideId,
    'method': method.apiValue,
    'amountMinor': amountMinor,
    'tipMinor': tipMinor,
    'currency': currency,
    'reference': reference,
    'confirmedAt': confirmedAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    rideId,
    method,
    amountMinor,
    tipMinor,
    currency,
    reference,
    confirmedAt,
  ];
}

/// Tip presets in minor units (rider currency comes from the ride). 0 = no tip.
const List<int> kTipPresetsMinor = [0, 200, 500, 1000];

const List<String> kRatingTags = [
  'Punctual arrival',
  'Smooth driving',
  'Clean cabin',
  'Quiet ride',
  'Great conversation',
];

String ratingHeadline(int rating) => switch (rating) {
  0 => 'Tap a star to rate',
  1 => 'Poor experience',
  2 => 'Could be better',
  3 => 'Good ride',
  4 => 'Great ride',
  _ => 'Exceptional experience',
};
