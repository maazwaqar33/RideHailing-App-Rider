import '../../rides/domain/ride_models.dart';
import 'trip_models.dart';

/// Rating/comment/tip storage.
///
/// There is no backend endpoint for ratings, reviews or tips. The only implementation
/// (`LocalFeedbackRepository`, in `lib/mock`) keeps them on the device. Swap it for a real
/// API-backed repository when the endpoint exists.
abstract class FeedbackRepository {
  Future<void> save(RideFeedback feedback);
  Future<RideFeedback?> get(int rideId);
}

/// "Report a problem". No backend endpoint exists; mock/local only.
abstract class ProblemReportRepository {
  Future<void> submit(ProblemReport report);
  Future<List<ProblemReport>> forRide(int rideId);
}

/// Payment confirmation. DEMO ONLY: nothing is ever charged and the backend ride keeps
/// `payment.status = not_charged`. The mock implementation records the rider's chosen method locally.
abstract class PaymentService {
  Future<PaymentReceipt> confirm({
    required Ride ride,
    required PaymentMethodType method,
    int tipMinor = 0,
  });
  Future<PaymentReceipt?> receiptFor(int rideId);
}
