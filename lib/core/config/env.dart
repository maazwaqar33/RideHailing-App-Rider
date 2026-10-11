import 'package:flutter/foundation.dart';

/// Typed build-time configuration. No secrets live in the app; everything here is
/// either a public endpoint or a feature switch supplied with `--dart-define`.
///
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8001
/// ```
abstract final class Env {
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// How often a ride in progress is re-fetched (the backend has no websocket).
  static const int pollIntervalMs = int.fromEnvironment(
    'POLL_INTERVAL_MS',
    defaultValue: 5000,
  );

  /// When true the fare estimate falls back to a clearly-labelled mock calculator
  /// ONLY if the backend is unreachable (never on a 4xx/5xx answer).
  static const bool mockEstimateFallback = bool.fromEnvironment(
    'MOCK_ESTIMATE_FALLBACK',
    defaultValue: true,
  );

  /// Minimum splash duration, in milliseconds.
  static const int splashMinMs = int.fromEnvironment(
    'SPLASH_MIN_MS',
    defaultValue: 1400,
  );

  /// Compresses the simulated driver journey so the demo is watchable (seconds per leg).
  static const int mockDriverLegSeconds = int.fromEnvironment(
    'MOCK_DRIVER_LEG_SECONDS',
    defaultValue: 90,
  );

  /// Which logged-out entry flow is the default: `classic` = splash > 3-page onboarding > welcome >
  /// login / sign-up screens; `hub` = single-page intro (`splash_onboarding`) > combined
  /// `login_sign_up` screen. Both are always reachable at `/intro` and `/auth`.
  static const String uiVariant = String.fromEnvironment(
    'UI_VARIANT',
    defaultValue: 'classic',
  );

  /// Device label sent to the API on login/register (stored in the audit log).
  static const String deviceName = String.fromEnvironment(
    'DEVICE_NAME',
    defaultValue: 'nordic-rider-app',
  );

  /// Platform-aware default: the Android emulator reaches the host through 10.0.2.2.
  static String get apiBaseUrl =>
      resolveApiBaseUrl(_apiBaseUrl, defaultTargetPlatform, kIsWeb);

  static String resolveApiBaseUrl(
    String override,
    TargetPlatform platform,
    bool isWeb,
  ) {
    if (override.isNotEmpty) {
      return override.endsWith('/')
          ? override.substring(0, override.length - 1)
          : override;
    }
    if (!isWeb && platform == TargetPlatform.android) {
      return 'http://10.0.2.2:8001';
    }
    return 'http://127.0.0.1:8001';
  }

  /// Origins to try, in order. An explicit `API_BASE_URL` wins and is never probed. On Android
  /// without an override: `127.0.0.1:8001` (a real phone with `adb reverse tcp:8001 tcp:8001`) then
  /// `10.0.2.2:8001` (the emulator). Desktop and web use `127.0.0.1:8001`.
  static List<String> get apiBaseUrlCandidates =>
      candidatesFor(_apiBaseUrl, defaultTargetPlatform, kIsWeb);

  static List<String> candidatesFor(
    String override,
    TargetPlatform platform,
    bool isWeb,
  ) {
    if (override.isNotEmpty || isWeb || platform != TargetPlatform.android) {
      return [resolveApiBaseUrl(override, platform, isWeb)];
    }
    return const ['http://127.0.0.1:8001', 'http://10.0.2.2:8001'];
  }

  /// All backend routes live under this prefix.
  static const String apiPrefix = '/api/v1';
}
