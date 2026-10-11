import 'package:dio/dio.dart';

enum ApiErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  conflict,
  rateLimited,
  server,
  cancelled,
  unknown,
}

/// Error surfaced by every repository. Carries a user-friendly [message]
/// plus structured data (field errors, status code, retry-after) for the UI.
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
    this.retryAfterSeconds,
    this.serverMessage,
  });

  final ApiErrorKind kind;

  /// Friendly text safe to show to the rider.
  final String message;
  final int? statusCode;

  /// Laravel 422 `errors` object: field -> messages.
  final Map<String, List<String>> fieldErrors;
  final int? retryAfterSeconds;

  /// Raw `message` from the API (debug/logging only).
  final String? serverMessage;

  bool get isNetwork =>
      kind == ApiErrorKind.network || kind == ApiErrorKind.timeout;
  bool get isUnauthorized => kind == ApiErrorKind.unauthorized;
  bool get isConflict => kind == ApiErrorKind.conflict;

  /// First message for a field (e.g. `email`), if the API reported one.
  String? fieldError(String field) {
    final list = fieldErrors[field];
    return (list == null || list.isEmpty) ? null : list.first;
  }

  @override
  String toString() => 'ApiException($kind, $statusCode, $message)';
}

/// Central place that turns transport / HTTP failures into [ApiException].
abstract final class ApiErrorMapper {
  static const networkMessage =
      "Can't reach the server. Check your connection and try again.";
  static const timeoutMessage =
      'The server took too long to respond. Please try again.';
  static const sessionExpiredMessage =
      'Your session has expired. Please log in again.';

  /// [unauthorizedMessage] lets login screens say "wrong email or password"
  /// instead of "session expired" for the same 401.
  static ApiException fromDio(DioException e, {String? unauthorizedMessage}) {
    final inner = e.error;
    if (inner is ApiException) return inner;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          kind: ApiErrorKind.timeout,
          message: timeoutMessage,
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          kind: ApiErrorKind.network,
          message: networkMessage,
        );
      case DioExceptionType.cancel:
        return const ApiException(
          kind: ApiErrorKind.cancelled,
          message: 'Request cancelled.',
        );
      case DioExceptionType.badCertificate:
        return const ApiException(
          kind: ApiErrorKind.network,
          message: 'A secure connection could not be established.',
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    final response = e.response;
    if (response == null) {
      // Socket exceptions surface as `unknown` on some platforms.
      return const ApiException(
        kind: ApiErrorKind.network,
        message: networkMessage,
      );
    }
    return fromResponse(
      response.statusCode ?? 0,
      response.data,
      response.headers,
      unauthorizedMessage: unauthorizedMessage,
    );
  }

  static ApiException fromResponse(
    int status,
    Object? data,
    Headers? headers, {
    String? unauthorizedMessage,
  }) {
    final serverMessage = data is Map ? data['message']?.toString() : null;
    final fieldErrors = <String, List<String>>{};
    if (data is Map && data['errors'] is Map) {
      (data['errors'] as Map).forEach((key, value) {
        fieldErrors[key.toString()] = value is List
            ? value.map((v) => v.toString()).toList()
            : [value.toString()];
      });
    }

    switch (status) {
      case 401:
        return ApiException(
          kind: ApiErrorKind.unauthorized,
          statusCode: 401,
          message: unauthorizedMessage ?? sessionExpiredMessage,
          serverMessage: serverMessage,
        );
      case 403:
        final inactive =
            serverMessage != null &&
            serverMessage.toLowerCase().contains('not active');
        return ApiException(
          kind: ApiErrorKind.forbidden,
          statusCode: 403,
          message: inactive
              ? 'This account is not active. Please contact support.'
              : "You don't have permission to do that.",
          serverMessage: serverMessage,
        );
      case 404:
        return ApiException(
          kind: ApiErrorKind.notFound,
          statusCode: 404,
          message: "We couldn't find what you were looking for.",
          serverMessage: serverMessage,
        );
      case 409:
        return ApiException(
          kind: ApiErrorKind.conflict,
          statusCode: 409,
          message: serverMessage ?? 'That action conflicts with the current state. Please refresh and try again.',
          serverMessage: serverMessage,
        );
      case 422:
        final first =
            fieldErrors.values.isNotEmpty && fieldErrors.values.first.isNotEmpty
            ? fieldErrors.values.first.first
            : null;
        return ApiException(
          kind: ApiErrorKind.validation,
          statusCode: 422,
          message:
              first ?? serverMessage ?? 'Please check the highlighted fields.',
          fieldErrors: fieldErrors,
          serverMessage: serverMessage,
        );
      case 429:
        final retry = int.tryParse(headers?.value('retry-after') ?? '');
        return ApiException(
          kind: ApiErrorKind.rateLimited,
          statusCode: 429,
          retryAfterSeconds: retry,
          message: retry != null
              ? 'Too many attempts. Please wait $retry seconds and try again.'
              : 'Too many attempts. Please wait a minute and try again.',
          serverMessage: serverMessage,
        );
      default:
        if (status >= 500) {
          return ApiException(
            kind: ApiErrorKind.server,
            statusCode: status,
            message:
                'Something went wrong on our side. Please try again shortly.',
            serverMessage: serverMessage,
          );
        }
        return ApiException(
          kind: ApiErrorKind.unknown,
          statusCode: status,
          message: serverMessage ?? 'Something went wrong. Please try again.',
          serverMessage: serverMessage,
        );
    }
  }

  /// Runs [action], converting any [DioException] to [ApiException].
  static Future<T> guard<T>(
    Future<T> Function() action, {
    String? unauthorizedMessage,
  }) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw fromDio(e, unauthorizedMessage: unauthorizedMessage);
    }
  }
}
