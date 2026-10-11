import '../features/fare/domain/fare_models.dart';
import '../features/fare/domain/fare_repository.dart';
import '../features/rides/domain/ride_models.dart';

/// MOCK adapter used ONLY when the real fare API is unreachable. It re-implements the
/// backend integer formula with a hard-coded demo rule, so the number is indicative at best.
/// The UI marks it "mock estimate" and refuses to book against it.
class MockFareEstimator implements FareRepository {
  const MockFareEstimator();

  // Demo fare rule (mirrors the seeded "Standard" rule; NOT read from the server).
  static const int baseMinor = 350;
  static const int perKmMinor = 120;
  static const int perMinuteMinor = 30;
  static const int minimumMinor = 800;
  static const int bookingFeeMinor = 100;
  static const int taxBps = 1200;
  static const String currency = 'EUR';

  static int _divRoundHalfUp(int n, int d) => (n * 2 + d) ~/ (d * 2);

  @override
  Future<FareEstimate> estimate(FareEstimateRequest request) async {
    final distanceCharge = _divRoundHalfUp(
      perKmMinor * request.distanceMeters,
      1000,
    );
    final timeCharge = _divRoundHalfUp(
      perMinuteMinor * request.durationSeconds,
      60,
    );
    final raw = baseMinor + distanceCharge + timeCharge;
    final adjustment = raw >= minimumMinor ? 0 : minimumMinor - raw;
    final fare = raw + adjustment;
    final subtotal = fare + bookingFeeMinor;
    final tax = _divRoundHalfUp(subtotal * taxBps, 10000);
    return FareEstimate(
      source: FareSource.backend,
      breakdown: FareBreakdown(
        currency: currency,
        distanceMeters: request.distanceMeters,
        durationSeconds: request.durationSeconds,
        baseFareMinor: baseMinor,
        distanceChargeMinor: distanceCharge,
        timeChargeMinor: timeCharge,
        rawFareMinor: raw,
        minimumFareAdjustmentMinor: adjustment,
        fareMinor: fare,
        bookingFeeMinor: bookingFeeMinor,
        taxMinor: tax,
        totalMinor: subtotal + tax,
      ),
    );
  }
}
