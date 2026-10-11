import 'fare_models.dart';

/// Computes fare estimates. The real implementation calls POST fares/estimate.
abstract class FareRepository {
  Future<FareEstimate> estimate(FareEstimateRequest request);
}
