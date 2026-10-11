import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../mock/local_trip_stores.dart';
import '../domain/trip_models.dart';
import '../domain/trip_repositories.dart';

/// LOCAL/MOCK: no rating/review/tip endpoint exists in the backend.
final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => LocalFeedbackRepository(ref.watch(sharedPreferencesProvider)),
);

/// LOCAL/MOCK: no "report a problem" endpoint exists in the backend.
final problemReportRepositoryProvider = Provider<ProblemReportRepository>(
  (ref) => LocalProblemReportRepository(ref.watch(sharedPreferencesProvider)),
);

/// MOCK payment: nothing is charged; backend payment.status stays `not_charged`.
final paymentServiceProvider = Provider<PaymentService>(
  (ref) => MockPaymentService(ref.watch(sharedPreferencesProvider)),
);

final savedFeedbackProvider = FutureProvider.autoDispose
    .family<RideFeedback?, int>(
      (ref, rideId) => ref.watch(feedbackRepositoryProvider).get(rideId),
    );

final mockReceiptProvider = FutureProvider.autoDispose
    .family<PaymentReceipt?, int>(
      (ref, rideId) => ref.watch(paymentServiceProvider).receiptFor(rideId),
    );
