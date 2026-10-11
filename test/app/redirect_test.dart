import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/app/app_router.dart';
import 'package:rider_app/features/auth/application/session_controller.dart';

import '../helpers/test_helpers.dart';

void main() {
  String? r(SessionState s, String loc, {bool seen = true}) =>
      appRedirect(session: s, onboardingSeen: seen, location: loc);

  test('restoring keeps everything on splash', () {
    expect(r(const SessionRestoring(), '/home'), '/splash');
    expect(r(const SessionRestoring(), '/splash'), isNull);
  });

  test('restore failed stays on splash (retry button lives there)', () {
    expect(r(const SessionRestoreFailed('x'), '/login'), '/splash');
  });

  test(
    'signed-out users leave splash for onboarding (first run) or welcome',
    () {
      expect(
        r(const SessionUnauthenticated(), '/splash', seen: false),
        '/onboarding',
      );
      expect(
        r(const SessionUnauthenticated(), '/splash', seen: true),
        '/welcome',
      );
    },
  );

  test('signed-out users cannot reach protected routes', () {
    for (final p in [
      '/home',
      '/trips',
      '/ride/3',
      '/choose-ride',
      '/profile',
    ]) {
      expect(r(const SessionUnauthenticated(), p), '/welcome', reason: p);
    }
  });

  test('public auth routes stay reachable when signed out', () {
    for (final p in [
      '/welcome',
      '/login',
      '/signup',
      '/forgot',
      '/reset',
      '/terms',
      '/privacy',
      '/onboarding',
    ]) {
      expect(r(const SessionUnauthenticated(), p), isNull, reason: p);
    }
  });

  test('signed-in users are moved off auth screens to /home', () {
    for (final p in [
      '/splash',
      '/login',
      '/welcome',
      '/signup',
      '/onboarding',
    ]) {
      expect(r(const SessionAuthenticated(sampleUser), p), '/home', reason: p);
    }
    expect(r(const SessionAuthenticated(sampleUser), '/trips'), isNull);
    expect(r(const SessionAuthenticated(sampleUser), '/ride/9'), isNull);
  });
}
