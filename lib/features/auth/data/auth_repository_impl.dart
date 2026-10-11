import 'package:dio/dio.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dio);

  final Dio _dio;

  static const wrongCredentials = 'Email or password is incorrect.';

  Map<String, dynamic> _data(Response<dynamic> r) =>
      Map<String, dynamic>.from((r.data as Map)['data'] as Map);

  @override
  Future<AuthSession> login({required String email, required String password}) {
    return ApiErrorMapper.guard(() async {
      final r = await _dio.post<dynamic>(
        '/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
          'device_name': Env.deviceName,
        },
        options: Options(extra: {kSkipUnauthorizedHandling: true}),
      );
      return AuthSession.fromJson(Map<String, dynamic>.from(r.data as Map));
    }, unauthorizedMessage: wrongCredentials);
  }

  @override
  Future<AuthSession> register(RegisterRequest request) {
    return ApiErrorMapper.guard(() async {
      final r = await _dio.post<dynamic>(
        '/auth/register',
        data: {
          'first_name': request.firstName,
          'last_name': request.lastName,
          'email': request.email.trim(),
          'password': request.password,
          'password_confirmation': request.password,
          if (request.phone != null && request.phone!.trim().isNotEmpty)
            'phone': request.phone!.trim(),
          if (request.defaultPaymentMethod != null)
            'default_payment_method': request.defaultPaymentMethod,
          'device_name': Env.deviceName,
        },
        options: Options(extra: {kSkipUnauthorizedHandling: true}),
      );
      return AuthSession.fromJson(Map<String, dynamic>.from(r.data as Map));
    });
  }

  @override
  Future<AuthUser> me({Duration? timeout}) {
    return ApiErrorMapper.guard(() async {
      final r = await _dio.get<dynamic>(
        '/auth/me',
        options: timeout == null
            ? null
            : Options(receiveTimeout: timeout, sendTimeout: timeout),
      );
      return AuthUser.fromJson(_data(r));
    });
  }

  @override
  Future<void> logout() {
    return ApiErrorMapper.guard(() async {
      await _dio.post<dynamic>(
        '/auth/logout',
        options: Options(extra: {kSkipUnauthorizedHandling: true}),
      );
    });
  }

  @override
  Future<String> forgotPassword(String email) {
    return ApiErrorMapper.guard(() async {
      final r = await _dio.post<dynamic>(
        '/auth/password/forgot',
        data: {'email': email.trim()},
      );
      return ((r.data as Map)['message'] as String?) ??
          'If the account exists, a reset link has been sent.';
    });
  }

  @override
  Future<String> resetPassword({
    required String email,
    required String token,
    required String password,
  }) {
    return ApiErrorMapper.guard(() async {
      final r = await _dio.post<dynamic>(
        '/auth/password/reset',
        data: {
          'email': email.trim(),
          'token': token.trim(),
          'password': password,
          'password_confirmation': password,
        },
      );
      return ((r.data as Map)['message'] as String?) ??
          'Your password has been reset.';
    });
  }

  @override
  Future<RiderProfile> riderProfile() {
    return ApiErrorMapper.guard(() async {
      final r = await _dio.get<dynamic>('/me/rider');
      return RiderProfile.fromJson(_data(r));
    });
  }

  @override
  Future<RiderProfile> updateDefaultPaymentMethod(String method) {
    return ApiErrorMapper.guard(() async {
      final r = await _dio.patch<dynamic>(
        '/me/rider',
        data: {'default_payment_method': method},
      );
      return RiderProfile.fromJson(_data(r));
    });
  }
}
