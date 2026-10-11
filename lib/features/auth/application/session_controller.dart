import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/storage/token_store.dart';
import '../data/remembered_user.dart';
import '../domain/auth_models.dart';

sealed class SessionState {
  const SessionState();
}

/// App just started: checking the stored token against GET auth/me.
class SessionRestoring extends SessionState {
  const SessionRestoring();
}

class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated({this.notice});

  /// Why the user is signed out (e.g. "Your session has expired").
  final String? notice;
}

class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.user);

  final AuthUser user;
}

/// Restore failed for a transient reason (offline/server down). The token is kept.
class SessionRestoreFailed extends SessionState {
  const SessionRestoreFailed(this.message);

  final String message;
}

const kRiderOnlyMessage =
    'This app is for riders. Please sign in with a rider account.';

/// Owns the signed-in state. The JWT (backend v1.1) is rotated by the Dio client: shortly before
/// expiry, and once on a 401. When that fails (expired token, 14-day session limit) the user is
/// returned to the login screen.
class SessionController extends Notifier<SessionState> {
  /// Minimum time the splash is visible (0 in tests).
  Duration splashMin = Duration.zero;

  /// Longest the splash waits for GET auth/me before offering "Try again" / "Sign in again".
  Duration restoreTimeout = const Duration(seconds: 8);

  @override
  SessionState build() => const SessionRestoring();

  TokenStore get _store => ref.read(tokenStoreProvider);

  /// Called once at launch and from the splash "Try again" button.
  Future<void> restore() async {
    state = const SessionRestoring();
    final started = DateTime.now();
    final next = await _restore();
    final remaining = splashMin - DateTime.now().difference(started);
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    state = next;
  }

  Future<SessionState> _restore() async {
    final stored = await _store.read();
    if (stored == null) return const SessionUnauthenticated();
    if (stored.isExpired()) {
      await _store.clear();
      return const SessionUnauthenticated(
        notice: ApiErrorMapper.sessionExpiredMessage,
      );
    }
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .me(timeout: restoreTimeout)
          // Safety net on top of the Dio timeouts (e.g. a refresh that hangs).
          .timeout(
            restoreTimeout + const Duration(seconds: 2),
            onTimeout: () => throw const ApiException(
              kind: ApiErrorKind.timeout,
              message: ApiErrorMapper.timeoutMessage,
            ),
          );
      if (!user.isRider) {
        await _store.clear();
        return const SessionUnauthenticated(notice: kRiderOnlyMessage);
      }
      return SessionAuthenticated(user);
    } on ApiException catch (e) {
      if (e.isUnauthorized || e.kind == ApiErrorKind.forbidden) {
        await _store.clear();
        return SessionUnauthenticated(
          notice: e.isUnauthorized
              ? ApiErrorMapper.sessionExpiredMessage
              : e.message,
        );
      }
      return SessionRestoreFailed(e.message);
    }
  }

  /// Splash "Sign in again": drop the stored session (kept after a failed restore) and go to the
  /// signed-out flow.
  Future<void> signInAgain() async {
    await _store.clear();
    state = const SessionUnauthenticated();
  }

  /// Direct sign-in as Demo Rider for offline evaluation and when live server is unreachable.
  Future<void> loginAsDemoRider({String? email}) async {
    final session = AuthSession(
      token: 'mock-demo-rider-jwt-token',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      user: AuthUser(
        id: 1,
        name: 'Sara Nordmann',
        email: (email != null && email.trim().isNotEmpty)
            ? email.trim()
            : 'rider1@example.com',
        phone: '+47 912 34 567',
        riderId: 1,
        roles: const ['rider'],
      ),
    );
    await _accept(session);
  }

  Future<void> login({required String email, required String password}) async {
    final session = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    await _accept(session);
  }

  Future<void> register(RegisterRequest request) async {
    final session = await ref.read(authRepositoryProvider).register(request);
    await _accept(session);
  }

  Future<void> _accept(AuthSession session) async {
    if (!session.user.isRider) {
      // Staff / driver credentials: refuse and revoke so nothing lingers server-side.
      await _store.write(
        StoredSession(token: session.token, expiresAt: session.expiresAt),
      );
      try {
        await ref.read(authRepositoryProvider).logout();
      } catch (_) {}
      await _store.clear();
      throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: kRiderOnlyMessage,
        statusCode: 403,
      );
    }
    await _store.write(
      StoredSession(token: session.token, expiresAt: session.expiresAt),
    );
    try {
      await RememberedUser.write(
        ref.read(sharedPreferencesProvider),
        RememberedUser(name: session.user.name, email: session.user.email),
      );
    } catch (_) {
      // Personalisation only; never block sign-in on it.
    }
    state = SessionAuthenticated(session.user);
  }

  /// POST auth/logout then clear local state. Always signs out locally, even if the call fails.
  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {
      // Offline / already-expired token: local sign-out is what matters.
    }
    await _store.clear();
    state = const SessionUnauthenticated();
  }

  /// App returned to the foreground: one cheap authenticated call. The Dio client refreshes the
  /// token first when fewer than 5 minutes remain (and signs out if the session is gone).
  Future<void> onResume() async {
    if (state is! SessionAuthenticated) return;
    try {
      await ref.read(authRepositoryProvider).me();
    } catch (_) {
      // 401 handling is done by the interceptor; network errors are ignored here.
    }
  }

  /// Called by the Dio interceptor when an authenticated request returns 401.
  Future<void> handleUnauthorized() async {
    if (state is! SessionAuthenticated) return;
    await _store.clear();
    state = const SessionUnauthenticated(
      notice: ApiErrorMapper.sessionExpiredMessage,
    );
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
