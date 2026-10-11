import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/domain/auth_models.dart';
import '../features/auth/domain/auth_repository.dart';

/// Full in-memory + SharedPreferences backed mock auth repository.
/// Allows any login / registration credentials, maintains session, and profile.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _kUserKey = 'mock_auth_user_v1';
  static const _kPaymentKey = 'mock_rider_payment_method_v1';

  AuthUser? _cachedUser;

  String _cleanName(String email) {
    if (email.toLowerCase().contains('rider1')) return 'Sara Hansen';
    if (email.toLowerCase().contains('rider2')) return 'Lukas Berg';
    final parts = email.split('@').first.split(RegExp(r'[._-]'));
    return parts.map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}').join(' ').trim();
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    // Artificial small delay for realistic UX touch (150ms)
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final trimmedEmail = email.trim();
    final name = _cleanName(trimmedEmail);

    final user = AuthUser(
      id: 1,
      name: name.isEmpty ? 'Sara Hansen' : name,
      email: trimmedEmail.isEmpty ? 'rider1@example.com' : trimmedEmail,
      phone: '+47 912 34 567',
      status: 'active',
      roles: const ['rider'],
      permissions: const ['rides.create', 'rides.view_own'],
      riderId: 1,
    );

    _cachedUser = user;
    await _saveUser(user);

    return AuthSession(
      token: 'mock_jwt_svea_${DateTime.now().millisecondsSinceEpoch}',
      expiresAt: DateTime.now().add(const Duration(days: 365)),
      user: user,
    );
  }

  @override
  Future<AuthSession> register(RegisterRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final name = '${request.firstName.trim()} ${request.lastName.trim()}'.trim();
    final user = AuthUser(
      id: 1,
      name: name.isEmpty ? 'Sara Hansen' : name,
      email: request.email.trim(),
      phone: request.phone ?? '+47 912 34 567',
      status: 'active',
      roles: const ['rider'],
      permissions: const ['rides.create', 'rides.view_own'],
      riderId: 1,
    );

    _cachedUser = user;
    await _saveUser(user);
    if (request.defaultPaymentMethod != null) {
      await _prefs.setString(_kPaymentKey, request.defaultPaymentMethod!);
    }

    return AuthSession(
      token: 'mock_jwt_svea_${DateTime.now().millisecondsSinceEpoch}',
      expiresAt: DateTime.now().add(const Duration(days: 365)),
      user: user,
    );
  }

  @override
  Future<AuthUser> me({Duration? timeout}) async {
    if (_cachedUser != null) return _cachedUser!;
    final restored = _loadUser();
    if (restored != null) {
      _cachedUser = restored;
      return restored;
    }
    return const AuthUser(
      id: 1,
      name: 'Sara Hansen',
      email: 'rider1@example.com',
      phone: '+47 912 34 567',
      status: 'active',
      roles: ['rider'],
      permissions: ['rides.create', 'rides.view_own'],
      riderId: 1,
    );
  }

  @override
  Future<void> logout() async {
    _cachedUser = null;
    await _prefs.remove(_kUserKey);
  }

  @override
  Future<String> forgotPassword(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return 'Password reset link sent to $email.';
  }

  @override
  Future<String> resetPassword({
    required String email,
    required String token,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return 'Password has been reset successfully.';
  }

  @override
  Future<RiderProfile> riderProfile() async {
    final user = _cachedUser ?? _loadUser();
    final nameParts = (user?.name ?? 'Sara Hansen').split(' ');
    final first = nameParts.isNotEmpty ? nameParts.first : 'Sara';
    final last = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Hansen';
    final payment = _prefs.getString(_kPaymentKey) ?? 'card';

    return RiderProfile(
      id: 1,
      firstName: first,
      lastName: last,
      phone: user?.phone ?? '+47 912 34 567',
      email: user?.email ?? 'rider1@example.com',
      defaultPaymentMethod: payment,
    );
  }

  @override
  Future<RiderProfile> updateDefaultPaymentMethod(String method) async {
    await _prefs.setString(_kPaymentKey, method);
    return riderProfile();
  }

  Future<void> _saveUser(AuthUser user) async {
    final map = {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'status': user.status,
      'roles': user.roles.map((r) => {'slug': r}).toList(),
      'permissions': user.permissions,
      'rider_id': user.riderId,
      'driver_id': user.driverId,
    };
    await _prefs.setString(_kUserKey, jsonEncode(map));
  }

  AuthUser? _loadUser() {
    final raw = _prefs.getString(_kUserKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return AuthUser.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}
