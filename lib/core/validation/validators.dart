/// Pure form validators. Each returns an error message or `null` when valid.
/// Password rules mirror the backend (`Password::min(10)->letters()->mixedCase()->numbers()`),
/// so the app rejects what the API would reject with a 422.
abstract final class Validators {
  static final _email = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
  );
  static final _phone = RegExp(r'^\+?[0-9 ()-]{6,32}$');

  static String? required(String? value, [String field = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$field is required.';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required.';
    if (v.length > 255 || !_email.hasMatch(v)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  /// Login only checks presence: the server owns the real credential check.
  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    return null;
  }

  static const passwordMinLength = 10;

  static List<PasswordRule> passwordRules(String value) => [
    PasswordRule(
      'At least $passwordMinLength characters',
      value.length >= passwordMinLength,
    ),
    PasswordRule(
      'Upper and lower case letters',
      RegExp('[a-z]').hasMatch(value) && RegExp('[A-Z]').hasMatch(value),
    ),
    PasswordRule('At least 1 number', RegExp('[0-9]').hasMatch(value)),
  ];

  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required.';
    final failed = passwordRules(v).where((r) => !r.satisfied);
    if (failed.isNotEmpty) {
      return 'Password needs: ${failed.map((r) => r.label.toLowerCase()).join(', ')}.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  /// Number of satisfied rules, 0-3, for the strength meter.
  static int passwordStrength(String value) =>
      passwordRules(value).where((r) => r.satisfied).length;

  /// Optional phone: empty is fine, otherwise must match the backend regex.
  static String? optionalPhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!_phone.hasMatch(v)) {
      return 'Enter a valid phone number, e.g. +47 941 23 891.';
    }
    return null;
  }

  /// The API needs first AND last name; the sign-up form has one "full name" field.
  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Full name is required.';
    if (splitName(v).$2.isEmpty) return 'Enter your first and last name.';
    if (v.length > 200) return 'Name is too long.';
    return null;
  }

  /// "Mary Anne Smith" -> ("Mary Anne", "Smith"). Single names yield an empty last name.
  static (String first, String last) splitName(String full) {
    final parts = full.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return (parts.first, '');
    return (parts.sublist(0, parts.length - 1).join(' '), parts.last);
  }

  static String? resetToken(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Paste the reset token from your email.';
    }
    return null;
  }
}

class PasswordRule {
  const PasswordRule(this.label, this.satisfied);

  final String label;
  final bool satisfied;
}
