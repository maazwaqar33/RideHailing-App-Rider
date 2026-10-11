import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../features/rides/domain/ride_models.dart';
import '../features/trip/domain/trip_models.dart';
import '../features/trip/domain/trip_repositories.dart';

/// Local map store keyed by ride id, persisted as JSON in SharedPreferences (non-secret data only).
class _JsonMapStore {
  _JsonMapStore(this._prefs, this._key);

  final SharedPreferences _prefs;
  final String _key;

  Map<String, dynamic> _read() {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) return {};
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> put(String id, Object value) async {
    final map = _read()..[id] = value;
    await _prefs.setString(_key, jsonEncode(map));
  }

  Object? get(String id) => _read()[id];
}

/// MOCK/LOCAL: rating, comment and tip are stored on this device only.
/// They are NOT sent to the backend (no endpoint exists) and will not show up in Admin.
class LocalFeedbackRepository implements FeedbackRepository {
  LocalFeedbackRepository(SharedPreferences prefs)
    : _store = _JsonMapStore(prefs, 'mock.feedback.v1');

  final _JsonMapStore _store;

  @override
  Future<void> save(RideFeedback feedback) =>
      _store.put('${feedback.rideId}', feedback.toJson());

  @override
  Future<RideFeedback?> get(int rideId) async {
    final raw = _store.get('$rideId');
    return raw is Map
        ? RideFeedback.fromJson(Map<String, dynamic>.from(raw))
        : null;
  }
}

/// MOCK/LOCAL: problem reports are kept on the device and never delivered.
class LocalProblemReportRepository implements ProblemReportRepository {
  LocalProblemReportRepository(SharedPreferences prefs)
    : _store = _JsonMapStore(prefs, 'mock.reports.v1');

  final _JsonMapStore _store;

  @override
  Future<void> submit(ProblemReport report) async {
    final existing = await forRide(report.rideId);
    await _store.put(
      '${report.rideId}',
      [...existing, report].map((r) => r.toJson()).toList(),
    );
  }

  @override
  Future<List<ProblemReport>> forRide(int rideId) async {
    final raw = _store.get('$rideId');
    if (raw is! List) return const [];
    return raw
        .map((e) => ProblemReport.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

/// MOCK payment: records the rider's chosen method locally and returns a fake reference.
/// It NEVER charges anything, and the backend ride stays `payment.status = not_charged`.
class MockPaymentService implements PaymentService {
  MockPaymentService(SharedPreferences prefs, {DateTime Function()? clock})
    : _store = _JsonMapStore(prefs, 'mock.payments.v1'),
      _clock = clock ?? DateTime.now;

  final _JsonMapStore _store;
  final DateTime Function() _clock;

  @override
  Future<PaymentReceipt> confirm({
    required Ride ride,
    required PaymentMethodType method,
    int tipMinor = 0,
  }) async {
    final existing = await receiptFor(ride.id);
    if (existing != null) {
      return existing; // confirming twice must not create a second receipt
    }
    final amount = ride.fare.finalMinor ?? ride.fare.estimateMinor ?? 0;
    final receipt = PaymentReceipt(
      rideId: ride.id,
      method: method,
      amountMinor: amount,
      tipMinor: tipMinor,
      currency: ride.fare.currency,
      reference: 'TXN-${ride.id}-${(math.Random().nextInt(9000) + 1000)}',
      confirmedAt: _clock(),
    );
    await _store.put('${ride.id}', receipt.toJson());
    return receipt;
  }

  @override
  Future<PaymentReceipt?> receiptFor(int rideId) async {
    final raw = _store.get('$rideId');
    return raw is Map
        ? PaymentReceipt.fromJson(Map<String, dynamic>.from(raw))
        : null;
  }
}
