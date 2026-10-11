import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/core/validation/validators.dart';

void main() {
  group('email', () {
    test('accepts valid addresses', () {
      for (final e in [
        'rider1@example.com',
        'a.b+c@sub.example.no',
        ' user@example.org ',
      ]) {
        expect(Validators.email(e), isNull, reason: e);
      }
    });
    test('rejects empty and malformed', () {
      expect(Validators.email(''), 'Email is required.');
      expect(Validators.email(null), 'Email is required.');
      for (final e in [
        'plain',
        'a@b',
        '@example.com',
        'a@@example.com',
        'a b@example.com',
      ]) {
        expect(Validators.email(e), isNotNull, reason: e);
      }
    });
  });

  group('password rules mirror the backend (min 10, mixed case, number)', () {
    test('valid', () => expect(Validators.newPassword('Password123!'), isNull));
    test(
      'too short',
      () => expect(Validators.newPassword('Abcdef1'), contains('at least 10')),
    );
    test(
      'no uppercase',
      () => expect(
        Validators.newPassword('password1234'),
        contains('upper and lower'),
      ),
    );
    test(
      'no lowercase',
      () => expect(
        Validators.newPassword('PASSWORD1234'),
        contains('upper and lower'),
      ),
    );
    test(
      'no number',
      () => expect(
        Validators.newPassword('PasswordPassword'),
        contains('number'),
      ),
    );
    test(
      'empty',
      () => expect(Validators.newPassword(''), 'Password is required.'),
    );
    test('strength counts satisfied rules', () {
      expect(Validators.passwordStrength(''), 0);
      expect(Validators.passwordStrength('abc'), 0);
      expect(Validators.passwordStrength('abcdefghijkl'), 1);
      expect(Validators.passwordStrength('Abcdefghijkl'), 2);
      expect(Validators.passwordStrength('Abcdefghijk1'), 3);
    });
    test('confirm must match', () {
      expect(Validators.confirmPassword('x', 'y'), 'Passwords do not match.');
      expect(Validators.confirmPassword('', 'y'), isNotNull);
      expect(Validators.confirmPassword('same', 'same'), isNull);
    });
    test('login only requires presence', () {
      expect(Validators.loginPassword(''), isNotNull);
      expect(Validators.loginPassword('x'), isNull);
    });
  });

  group('phone (optional, backend regex)', () {
    test('empty is fine', () => expect(Validators.optionalPhone(''), isNull));
    test('valid', () {
      expect(Validators.optionalPhone('+47 941 23 891'), isNull);
      expect(Validators.optionalPhone('(020) 7946-0958'), isNull);
    });
    test('invalid', () {
      expect(Validators.optionalPhone('abc'), isNotNull);
      expect(Validators.optionalPhone('12'), isNotNull);
    });
  });

  group('full name', () {
    test('requires first and last', () {
      expect(Validators.fullName('Sara'), 'Enter your first and last name.');
      expect(Validators.fullName(''), 'Full name is required.');
      expect(Validators.fullName('Sara Hansen'), isNull);
    });
    test('split keeps compound first names', () {
      expect(Validators.splitName('Mary Anne Smith'), ('Mary Anne', 'Smith'));
      expect(Validators.splitName('  Sara   Hansen '), ('Sara', 'Hansen'));
      expect(Validators.splitName('Sara'), ('Sara', ''));
    });
  });

  test('reset token required', () {
    expect(Validators.resetToken(' '), isNotNull);
    expect(Validators.resetToken('abc'), isNull);
  });
}
