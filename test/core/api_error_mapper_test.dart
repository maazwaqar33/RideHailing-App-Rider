import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/core/network/api_exception.dart';

DioException _bad(
  int status,
  Object? data, {
  Map<String, List<String>>? headers,
}) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: req,
      statusCode: status,
      data: data,
      headers: Headers.fromMap(headers ?? {}),
    ),
  );
}

void main() {
  test('401 maps to unauthorized with session message by default', () {
    final e = ApiErrorMapper.fromDio(
      _bad(401, {'message': 'Unauthenticated.'}),
    );
    expect(e.kind, ApiErrorKind.unauthorized);
    expect(e.message, ApiErrorMapper.sessionExpiredMessage);
  });

  test('401 on login uses the supplied uniform message', () {
    final e = ApiErrorMapper.fromDio(
      _bad(401, {'message': 'Invalid credentials.'}),
      unauthorizedMessage: 'Email or password is incorrect.',
    );
    expect(e.message, 'Email or password is incorrect.');
  });

  test('403 not active is friendly', () {
    final e = ApiErrorMapper.fromDio(
      _bad(403, {'message': 'This account is not active.'}),
    );
    expect(e.kind, ApiErrorKind.forbidden);
    expect(e.message, contains('not active'));
  });

  test('403 generic', () {
    final e = ApiErrorMapper.fromDio(
      _bad(403, {'message': 'This action is unauthorized.'}),
    );
    expect(e.message, "You don't have permission to do that.");
  });

  test('422 exposes field errors and first message', () {
    final e = ApiErrorMapper.fromDio(
      _bad(422, {
        'message': 'The email has already been taken.',
        'errors': {
          'email': ['The email has already been taken.'],
          'password': [
            'The password field confirmation does not match.',
            'second',
          ],
        },
      }),
    );
    expect(e.kind, ApiErrorKind.validation);
    expect(e.fieldError('email'), 'The email has already been taken.');
    expect(
      e.fieldError('password'),
      'The password field confirmation does not match.',
    );
    expect(e.fieldError('phone'), isNull);
    expect(e.message, 'The email has already been taken.');
  });

  test('429 reads Retry-After', () {
    final e = ApiErrorMapper.fromDio(
      _bad(
        429,
        {'message': 'Too Many Attempts.'},
        headers: {
          'retry-after': ['37'],
        },
      ),
    );
    expect(e.kind, ApiErrorKind.rateLimited);
    expect(e.retryAfterSeconds, 37);
    expect(e.message, contains('37 seconds'));
  });

  test('429 without header still friendly', () {
    final e = ApiErrorMapper.fromDio(_bad(429, {'message': 'x'}));
    expect(e.message, contains('wait a minute'));
  });

  test('409 keeps the server message (one active ride)', () {
    final e = ApiErrorMapper.fromDio(
      _bad(409, {'message': 'You already have an active ride.'}),
    );
    expect(e.isConflict, isTrue);
    expect(e.message, 'You already have an active ride.');
  });

  test('404 is non-disclosing and friendly', () {
    final e = ApiErrorMapper.fromDio(
      _bad(404, {'message': 'Resource not found.'}),
    );
    expect(e.kind, ApiErrorKind.notFound);
  });

  test('5xx is a generic server error (no leaked detail)', () {
    final e = ApiErrorMapper.fromDio(
      _bad(500, {'message': 'SQLSTATE[HY000] secret'}),
    );
    expect(e.kind, ApiErrorKind.server);
    expect(e.message, isNot(contains('SQLSTATE')));
  });

  test('connection errors and timeouts', () {
    final req = RequestOptions(path: '/x');
    expect(
      ApiErrorMapper.fromDio(
        DioException.connectionError(requestOptions: req, reason: 'x'),
      ).kind,
      ApiErrorKind.network,
    );
    expect(
      ApiErrorMapper.fromDio(
        DioException.connectionTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: req,
        ),
      ).kind,
      ApiErrorKind.timeout,
    );
    expect(
      ApiErrorMapper.fromDio(
        DioException.receiveTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: req,
        ),
      ).isNetwork,
      isTrue,
    );
  });

  test('unknown without response is treated as network', () {
    final e = ApiErrorMapper.fromDio(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.unknown,
      ),
    );
    expect(e.kind, ApiErrorKind.network);
  });

  test('non-JSON body does not crash', () {
    final e = ApiErrorMapper.fromDio(_bad(500, '<html>oops</html>'));
    expect(e.kind, ApiErrorKind.server);
  });
}
