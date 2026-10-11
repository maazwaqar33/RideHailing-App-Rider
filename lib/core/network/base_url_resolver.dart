import 'dart:async';

import 'package:dio/dio.dart';

import '../config/env.dart';

/// Returns true when something answers HTTP at [baseUrl] (any status counts).
typedef ReachabilityProbe = Future<bool> Function(String baseUrl);

/// Picks the backend origin when the app was built WITHOUT `--dart-define=API_BASE_URL`.
///
/// On Android the right origin depends on where the app runs: `127.0.0.1:8001` on a real phone with
/// `adb reverse tcp:8001 tcp:8001`, `10.0.2.2:8001` inside the emulator. The candidates are probed in
/// order (short timeout each), the first reachable one is cached for the session, and a connection
/// error/timeout later triggers one re-probe (see `createApiClient`). With a single candidate (explicit
/// override, desktop, web) nothing is probed.
class BaseUrlResolver {
  BaseUrlResolver({
    required List<String> candidates,
    ReachabilityProbe? probe,
    Duration failureCooldown = const Duration(seconds: 3),
    DateTime Function()? clock,
  }) : assert(candidates.isNotEmpty),
       candidates = List.unmodifiable(candidates),
       _probe = probe ?? probeWithDio,
       _cooldown = failureCooldown,
       _now = clock ?? DateTime.now;

  /// Fixed origin, never probed.
  BaseUrlResolver.fixed(String url) : this(candidates: [url]);

  final List<String> candidates;
  final ReachabilityProbe _probe;
  final Duration _cooldown;
  final DateTime Function() _now;

  String? _cached;
  Future<String>? _inFlight;
  DateTime? _lastAllFailed;

  /// More than one candidate, so probing / re-probing makes sense.
  bool get probes => candidates.length > 1;

  /// The origin chosen so far (null before the first resolve / after [invalidate]).
  String? get current => _cached;

  /// The origin to use: cached, or the first reachable candidate. When none answers the first
  /// candidate is returned (the request then fails with the normal network error) and the result is
  /// not cached; probing is skipped for a few seconds so failing calls stay fast.
  Future<String> resolve() {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    if (!probes) return Future.value(candidates.first);
    final last = _lastAllFailed;
    if (last != null && _now().difference(last) < _cooldown) {
      return Future.value(candidates.first);
    }
    return _inFlight ??= _probeAll().whenComplete(() => _inFlight = null);
  }

  Future<String> _probeAll() async {
    for (final c in candidates) {
      if (await _probe(c)) {
        _cached = c;
        _lastAllFailed = null;
        return c;
      }
    }
    _lastAllFailed = _now();
    return candidates.first;
  }

  /// Forget the cached origin so the next [resolve] probes again.
  void invalidate() {
    _cached = null;
    _lastAllFailed = null;
  }

  /// Default probe: `GET <base>/api/v1/auth/me`, 1.5 s connect/receive timeout. Any HTTP answer
  /// (401 included) means reachable.
  static Future<bool> probeWithDio(String baseUrl) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: '$baseUrl${Env.apiPrefix}',
        connectTimeout: const Duration(milliseconds: 1500),
        receiveTimeout: const Duration(milliseconds: 1500),
        sendTimeout: const Duration(milliseconds: 1500),
        validateStatus: (_) => true,
      ),
    );
    try {
      final r = await dio.get<dynamic>(
        '/auth/me',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      return r.statusCode != null;
    } on DioException catch (e) {
      return e.response != null;
    } catch (_) {
      return false;
    } finally {
      dio.close(force: true);
    }
  }
}
