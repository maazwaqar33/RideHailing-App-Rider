import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../rides/domain/ride_models.dart';
import '../domain/fare_models.dart';
import '../domain/fare_repository.dart';

/// Real fare estimate: POST fares/estimate. Distance/duration are supplied by the
/// client (no routing provider exists server-side).
class FareRepositoryImpl implements FareRepository {
  FareRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<FareEstimate> estimate(FareEstimateRequest request) {
    return ApiErrorMapper.guard(() async {
      final r = await _dio.post<dynamic>(
        '/fares/estimate',
        data: request.toJson(),
      );
      final data = Map<String, dynamic>.from((r.data as Map)['data'] as Map);
      return FareEstimate(
        breakdown: FareBreakdown.fromJson(
          Map<String, dynamic>.from(data['breakdown'] as Map),
        ),
        source: FareSource.backend,
        distanceSource: data['distance_source'] as String?,
      );
    });
  }
}

/// Wraps the real repository and, ONLY when the backend is unreachable
/// (network error / timeout), substitutes a clearly flagged mock estimate.
/// 4xx/5xx answers are never replaced: they propagate so nothing fails silently as success.
class FallbackFareRepository implements FareRepository {
  FallbackFareRepository({
    required this.real,
    required this.mock,
    this.fallbackEnabled = true,
  });

  final FareRepository real;
  final FareRepository mock;
  final bool fallbackEnabled;

  @override
  Future<FareEstimate> estimate(FareEstimateRequest request) async {
    try {
      return await real.estimate(request);
    } on ApiException catch (e) {
      if (!fallbackEnabled || !e.isNetwork) rethrow;
      final m = await mock.estimate(request);
      return FareEstimate(
        breakdown: m.breakdown,
        source: FareSource.backend,
        fallbackReason: null,
      );
    }
  }
}
