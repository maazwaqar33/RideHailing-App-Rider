import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/ride_models.dart';
import '../domain/ride_repository.dart';

class RideRepositoryImpl implements RideRepository {
  RideRepositoryImpl(this._dio);

  final Dio _dio;

  Ride _ride(Response<dynamic> r) =>
      Ride.fromJson(Map<String, dynamic>.from((r.data as Map)['data'] as Map));

  @override
  Future<Ride> create(
    CreateRideRequest request, {
    required String idempotencyKey,
  }) {
    return ApiErrorMapper.guard(() async {
      final r = await _dio.post<dynamic>(
        '/rides',
        data: request.toJson(),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return _ride(r);
    });
  }

  @override
  Future<Ride> get(int id) => ApiErrorMapper.guard(
    () async => _ride(await _dio.get<dynamic>('/rides/$id')),
  );

  @override
  Future<RidePage> list({int page = 1, int perPage = 15, RideStatus? status}) {
    return ApiErrorMapper.guard(() async {
      final r = await _dio.get<dynamic>(
        '/rides',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (status != null) 'status': status.apiValue,
        },
      );
      final body = Map<String, dynamic>.from(r.data as Map);
      final meta = (body['meta'] as Map?) ?? const {};
      return RidePage(
        rides: ((body['data'] as List?) ?? const [])
            .map((e) => Ride.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        currentPage: (meta['current_page'] as num?)?.toInt() ?? page,
        lastPage: (meta['last_page'] as num?)?.toInt() ?? page,
      );
    });
  }

  @override
  Future<List<TimelineEntry>> timeline(int id) {
    return ApiErrorMapper.guard(() async {
      final r = await _dio.get<dynamic>('/rides/$id/timeline');
      return ((r.data as Map)['data'] as List)
          .map(
            (e) => TimelineEntry.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    });
  }

  @override
  Future<Ride> cancel(int id, String reason) {
    return ApiErrorMapper.guard(
      () async => _ride(
        await _dio.post<dynamic>('/rides/$id/cancel', data: {'reason': reason}),
      ),
    );
  }
}

/// Fallback wrapper for RideRepository.
/// Uses the real backend when available; automatically falls back to in-memory
/// MockRideRepository when offline, unhosted, or upon network failure.
class FallbackRideRepository implements RideRepository {
  FallbackRideRepository({required this.real, required this.mock});

  final RideRepository real;
  final RideRepository mock;

  @override
  Future<Ride> create(
    CreateRideRequest request, {
    required String idempotencyKey,
  }) async {
    try {
      return await real.create(request, idempotencyKey: idempotencyKey);
    } on ApiException catch (e) {
      if (e.isNetwork || e.kind == ApiErrorKind.server || e.kind == ApiErrorKind.timeout) {
        return mock.create(request, idempotencyKey: idempotencyKey);
      }
      rethrow;
    } catch (_) {
      return mock.create(request, idempotencyKey: idempotencyKey);
    }
  }

  @override
  Future<Ride> get(int id) async {
    try {
      return await real.get(id);
    } catch (_) {
      return mock.get(id);
    }
  }

  @override
  Future<RidePage> list({int page = 1, int perPage = 15, RideStatus? status}) async {
    try {
      return await real.list(page: page, perPage: perPage, status: status);
    } catch (_) {
      return mock.list(page: page, perPage: perPage, status: status);
    }
  }

  @override
  Future<List<TimelineEntry>> timeline(int id) async {
    try {
      return await real.timeline(id);
    } catch (_) {
      return mock.timeline(id);
    }
  }

  @override
  Future<Ride> cancel(int id, String reason) async {
    try {
      return await real.cancel(id, reason);
    } catch (_) {
      return mock.cancel(id, reason);
    }
  }
}
