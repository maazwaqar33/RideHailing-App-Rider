import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers.dart';

/// Name and email of the last rider who signed in on this device. NON-secret (no token, no password):
/// it only personalises the login screen ("returning rider" card) like the Stitch design.
class RememberedUser {
  const RememberedUser({required this.name, required this.email});

  final String name;
  final String email;

  static const _nameKey = 'last_user_name';
  static const _emailKey = 'last_user_email';

  static RememberedUser? read(SharedPreferences prefs) {
    final name = prefs.getString(_nameKey);
    final email = prefs.getString(_emailKey);
    return (name == null || email == null)
        ? null
        : RememberedUser(name: name, email: email);
  }

  static Future<void> write(SharedPreferences prefs, RememberedUser u) async {
    await prefs.setString(_nameKey, u.name);
    await prefs.setString(_emailKey, u.email);
  }

  /// "Erlend Kvist" -> "Erlend K."
  String get shortName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.length < 2 ? parts.first : '${parts.first} ${parts.last[0]}.';
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : ''))
        .toUpperCase();
  }
}

final rememberedUserProvider = Provider<RememberedUser?>((ref) {
  try {
    return RememberedUser.read(ref.watch(sharedPreferencesProvider));
  } catch (_) {
    return null; // prefs not available (tests that do not override it)
  }
});
