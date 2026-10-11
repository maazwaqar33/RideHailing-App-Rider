import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Bearer token + its server-side expiry (`expires_at` from login/register).
class StoredSession {
  const StoredSession({required this.token, required this.expiresAt});

  final String token;
  final DateTime? expiresAt;

  bool isExpired([DateTime? now]) =>
      expiresAt != null && !expiresAt!.isAfter(now ?? DateTime.now());
}

/// Where the bearer token lives. The real implementation uses the platform
/// keystore / keychain; tests use [InMemoryTokenStore].
abstract class TokenStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _expiresKey = 'auth_expires_at';
  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null || token.isEmpty) return null;
      final expires = await _storage.read(key: _expiresKey);
      return StoredSession(
        token: token,
        expiresAt: expires == null ? null : DateTime.tryParse(expires),
      );
    } catch (_) {
      // A corrupted keystore must never crash startup: treat as signed out.
      return null;
    }
  }

  @override
  Future<void> write(StoredSession session) async {
    await _storage.write(key: _tokenKey, value: session.token);
    await _storage.write(
      key: _expiresKey,
      value: session.expiresAt?.toIso8601String(),
    );
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _expiresKey);
    } catch (_) {}
  }
}

class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._session]);

  StoredSession? _session;

  @override
  Future<StoredSession?> read() async => _session;

  @override
  Future<void> write(StoredSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
