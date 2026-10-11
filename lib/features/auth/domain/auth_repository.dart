import 'auth_models.dart';

/// Contract for everything auth-related that talks to `/api/v1/auth/*` and `/me/rider`.
abstract class AuthRepository {
  /// POST auth/login. Throws `ApiException` (401 -> wrong credentials, 403 -> disabled, 429 -> throttled).
  Future<AuthSession> login({required String email, required String password});

  /// POST auth/register (rider self-registration).
  Future<AuthSession> register(RegisterRequest request);

  /// GET auth/me. A 401 means the stored token is dead.
  /// [timeout] overrides the response timeout for this one call (used by the splash restore).
  Future<AuthUser> me({Duration? timeout});

  /// POST auth/logout (revokes the current token). Failures are non-fatal for the caller.
  Future<void> logout();

  /// POST auth/password/forgot. Always 202 to avoid account enumeration.
  Future<String> forgotPassword(String email);

  /// POST auth/password/reset with the emailed token.
  Future<String> resetPassword({
    required String email,
    required String token,
    required String password,
  });

  /// GET me/rider.
  Future<RiderProfile> riderProfile();

  /// PATCH me/rider {default_payment_method}.
  Future<RiderProfile> updateDefaultPaymentMethod(String method);
}
