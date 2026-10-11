import 'package:equatable/equatable.dart';

/// `UserResource` as returned by `auth/login`, `auth/register` and `auth/me`.
class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.status = 'active',
    this.roles = const [],
    this.permissions = const [],
    this.riderId,
    this.driverId,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: (json['id'] as num).toInt(),
    name: (json['name'] as String?) ?? '',
    email: (json['email'] as String?) ?? '',
    phone: json['phone'] as String?,
    status: (json['status'] as String?) ?? 'active',
    roles: ((json['roles'] as List?) ?? const [])
        .map((r) => (r as Map)['slug']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList(),
    permissions: ((json['permissions'] as List?) ?? const [])
        .map((p) => p.toString())
        .toList(),
    riderId: (json['rider_id'] as num?)?.toInt(),
    driverId: (json['driver_id'] as num?)?.toInt(),
  );

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String status;
  final List<String> roles;
  final List<String> permissions;
  final int? riderId;
  final int? driverId;

  /// This app is for riders only: staff/driver accounts have no rider profile.
  bool get isRider => riderId != null;

  String get firstName =>
      name.trim().isEmpty ? 'there' : name.trim().split(RegExp(r'\s+')).first;

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    phone,
    status,
    roles,
    permissions,
    riderId,
    driverId,
  ];
}

/// Result of a successful login / register call.
class AuthSession extends Equatable {
  const AuthSession({
    required this.token,
    required this.expiresAt,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    token: json['token'] as String,
    expiresAt: DateTime.tryParse((json['expires_at'] as String?) ?? ''),
    user: AuthUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
  );

  final String token;
  final DateTime? expiresAt;
  final AuthUser user;

  @override
  List<Object?> get props => [token, expiresAt, user];
}

class RegisterRequest {
  const RegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    this.phone,
    this.defaultPaymentMethod,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String? phone;
  final String? defaultPaymentMethod;
}

/// `RiderResource` from `GET/PATCH me/rider`.
class RiderProfile extends Equatable {
  const RiderProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.defaultPaymentMethod = 'cash',
    this.email,
  });

  factory RiderProfile.fromJson(Map<String, dynamic> json) => RiderProfile(
    id: (json['id'] as num).toInt(),
    firstName: (json['first_name'] as String?) ?? '',
    lastName: (json['last_name'] as String?) ?? '',
    phone: json['phone'] as String?,
    defaultPaymentMethod: (json['default_payment_method'] as String?) ?? 'cash',
    email: json['email'] as String?,
  );

  final int id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String defaultPaymentMethod;
  final String? email;

  @override
  List<Object?> get props => [
    id,
    firstName,
    lastName,
    phone,
    defaultPaymentMethod,
    email,
  ];
}
