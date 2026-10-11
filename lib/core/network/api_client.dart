import 'dart:async';

import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/token_store.dart';
import 'base_url_resolver.dart';

/// `extra` flag: a 401 on this request is a normal answer (wrong password), not an expired session,
/// and the request needs no bearer token handling (login, register, refresh, logout).
const String kSkipUnauthorizedHandling = 'skipUnauthorizedHandling';

/// `extra` flag set on the single retry that follows a successful refresh.
const String _kRetriedAfterRefresh = 'retriedAfterRefresh';

typedef UnauthorizedCallback = void Function();

/// The refresh endpoint answered with a client error (401 invalid/expired/revoked/session limit,
/// 403 inactive account, ...): the session is over. 429 and 5xx are transient.
bool _refreshRefused(int? code) =>
    code != null && code >= 400 && code < 500 && code != 429;

/// Refresh the access token when fewer than this much time remains (backend doc, section 2).
const Duration kRefreshThreshold = Duration(minutes: 5);

/// Builds the app's Dio instance.
///
/// JWT handling (backend v1.1):
/// * attaches `Authorization: Bearer <token>` from [tokenStore];
/// * **proactive refresh**: before a request is sent, if fewer than [kRefreshThreshold] remain on
///   the stored token, `POST auth/refresh` first (the old token dies immediately, so the refresh is
///   **single-flight**: concurrent requests wait for the one refresh and then use the new token);
/// * **reactive refresh**: a 401 on an authenticated request triggers ONE refresh and ONE retry of
///   the request; if the refresh also fails with 401/403 (or there is no session) the session is
///   cleared and [onUnauthorized] fires once per burst (the app returns to login);
/// * a refresh that fails for a network reason never signs the user out.
Dio createApiClient({
  required TokenStore tokenStore,
  required UnauthorizedCallback onUnauthorized,
  String? baseUrl,
  BaseUrlResolver? resolver,
  HttpClientAdapter? adapter,
  DateTime Function()? clock,
}) {
  // An explicit [baseUrl] (tests) is fixed; otherwise the resolver picks (and may probe) the origin.
  final urls =
      resolver ??
      (baseUrl != null
          ? BaseUrlResolver.fixed(baseUrl)
          : BaseUrlResolver(candidates: Env.apiBaseUrlCandidates));
  final options = BaseOptions(
    baseUrl: '${urls.candidates.first}${Env.apiPrefix}',
    connectTimeout: const Duration(seconds: 8),
    sendTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
    // Let 4xx/5xx arrive as DioException(badResponse) so mapping is uniform.
    validateStatus: (status) => status != null && status >= 200 && status < 300,
  );
  final dio = Dio(options);
  if (adapter != null) dio.httpClientAdapter = adapter;
  // The refresh call uses a bare client (no interceptors) that shares the same adapter.
  final bare = Dio(options.copyWith())
    ..httpClientAdapter = dio.httpClientAdapter;
  final now = clock ?? DateTime.now;

  Future<StoredSession?>? inFlight;

  /// Single-flight `POST auth/refresh`. [usedToken] is the token the caller sent (or read) before
  /// calling; if the store already holds a different one, somebody else refreshed meanwhile.
  Future<StoredSession?> refresh(String usedToken) {
    final running = inFlight;
    if (running != null) return running;
    final future = () async {
      final current = await tokenStore.read();
      if (current == null) return null;
      if (current.token != usedToken) {
        return current; // already rotated by another caller
      }
      final response = await bare.post<dynamic>(
        '/auth/refresh',
        options: Options(headers: {'Authorization': 'Bearer ${current.token}'}),
      );
      final body = Map<String, dynamic>.from(response.data as Map);
      final fresh = StoredSession(
        token: body['token'] as String,
        expiresAt: DateTime.tryParse((body['expires_at'] as String?) ?? ''),
      );
      await tokenStore.write(fresh);
      return fresh;
    }();
    inFlight = future;
    future.whenComplete(() => inFlight = null).ignore();
    return future;
  }

  DateTime? last401;

  void signOutOnce() {
    final t = now();
    final recentlyHandled =
        last401 != null && t.difference(last401!) < const Duration(seconds: 1);
    if (recentlyHandled) return;
    // One sign-out per burst of parallel failures (no timer: nothing may outlive the app/tests).
    last401 = t;
    onUnauthorized();
  }

  // Base-URL selection (first interceptor). Probing only happens with several candidates.
  if (urls.probes) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, handler) async {
          final origin = await urls.resolve();
          final base = '$origin${Env.apiPrefix}';
          o.baseUrl = base;
          dio.options.baseUrl = base;
          bare.options.baseUrl = base;
          handler.next(o);
        },
        onError: (error, handler) async {
          final o = error.requestOptions;
          final network =
              error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout;
          if (!network || o.extra['reprobed'] == true) {
            return handler.next(error);
          }
          // One re-probe: the cached origin may be stale (adb reverse dropped, emulator <-> phone).
          final before = urls.current;
          urls.invalidate();
          final origin = await urls.resolve();
          if (origin == before) return handler.next(error);
          try {
            final base = '$origin${Env.apiPrefix}';
            dio.options.baseUrl = base;
            bare.options.baseUrl = base;
            final response = await dio.fetch<dynamic>(
              o.copyWith(baseUrl: base, extra: {...o.extra, 'reprobed': true}),
            );
            handler.resolve(response);
          } on DioException catch (e) {
            handler.next(e);
          }
        },
      ),
    );
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (o, handler) async {
        if (o.headers.containsKey('Authorization')) return handler.next(o);
        final stored = await tokenStore.read();
        final skipRefresh = o.extra[kSkipUnauthorizedHandling] == true;
        if (stored != null) {
          var session = stored;
          final left = session.expiresAt?.difference(now());
          // Still valid but about to expire: rotate first. (An already expired token cannot be
          // refreshed; it is sent as is and the 401 path signs the user out.)
          if (!skipRefresh &&
              left != null &&
              left > Duration.zero &&
              left < kRefreshThreshold) {
            try {
              session = await refresh(session.token) ?? session;
            } on DioException catch (e) {
              final code = e.response?.statusCode;
              if (_refreshRefused(code)) {
                await tokenStore.clear();
                signOutOnce();
                return handler.reject(
                  DioException(
                    requestOptions: o,
                    response: e.response,
                    type: DioExceptionType.badResponse,
                  ),
                );
              }
              // Network trouble: try the request with the token we have.
            }
          }
          o.headers['Authorization'] = 'Bearer ${session.token}';
        }
        handler.next(o);
      },
      onError: (error, handler) async {
        final o = error.requestOptions;
        final authenticated = o.headers.containsKey('Authorization');
        final skip = o.extra[kSkipUnauthorizedHandling] == true;
        if (error.response?.statusCode != 401 || !authenticated || skip) {
          return handler.next(error);
        }
        if (o.extra[_kRetriedAfterRefresh] == true) {
          // Second 401 for the same request: give up.
          await tokenStore.clear();
          signOutOnce();
          return handler.next(error);
        }
        final sent = (o.headers['Authorization'] as String).replaceFirst(
          'Bearer ',
          '',
        );
        try {
          final fresh = await refresh(sent);
          if (fresh == null) {
            signOutOnce();
            return handler.next(error);
          }
          final retry = o.copyWith(
            headers: {...o.headers, 'Authorization': 'Bearer ${fresh.token}'},
            extra: {...o.extra, _kRetriedAfterRefresh: true},
          );
          final response = await dio.fetch<dynamic>(retry);
          return handler.resolve(response);
        } on DioException catch (e) {
          final code = e.response?.statusCode;
          final fromRefresh = e.requestOptions.path.endsWith('/auth/refresh');
          if (fromRefresh && (_refreshRefused(code))) {
            await tokenStore.clear();
            signOutOnce();
            return handler.next(error);
          }
          // Retry failed (any status) or a transient refresh failure: surface that error.
          return handler.next(fromRefresh ? error : e);
        }
      },
    ),
  );
  return dio;
}
