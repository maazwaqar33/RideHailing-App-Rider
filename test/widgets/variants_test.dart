import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rider_app/app/app.dart';
import 'package:rider_app/app/app_router.dart';
import 'package:rider_app/core/network/api_client.dart';
import 'package:rider_app/core/providers.dart';
import 'package:rider_app/core/storage/token_store.dart';
import 'package:rider_app/features/auth/application/session_controller.dart';
import 'package:rider_app/features/map/application/map_providers.dart';
import 'package:rider_app/features/map/domain/map_repositories.dart';
import 'package:rider_app/mock/demo_content.dart';

import '../helpers/test_helpers.dart';

class _NoLocation implements LocationService {
  @override
  Future<LocationResult> current() async =>
      const LocationResult(status: LocationStatus.denied);
}

Future<(List<Override>, ScriptedAdapter, InMemoryTokenStore)> _env({
  bool seen = true,
}) async {
  final store = InMemoryTokenStore();
  final adapter = ScriptedAdapter();
  final base = await baseOverrides(
    tokenStore: store,
    prefs: {'flag.onboarding_seen': seen},
  );
  return (
    [
      ...base,
      locationServiceProvider.overrideWithValue(_NoLocation()),
      dioProvider.overrideWith(
        (ref) => createApiClient(
          tokenStore: store,
          baseUrl: 'http://test',
          adapter: adapter,
          onUnauthorized: () =>
              ref.read(sessionControllerProvider.notifier).handleUnauthorized(),
        ),
      ),
    ],
    adapter,
    store,
  );
}

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const RiderApp()),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('demo security PIN (mock, no backend PIN exists)', () {
    test('ride #42 shows the Stitch value and every PIN has 4 digits', () {
      expect(demoSecurityPin(42), '4821');
      for (final id in [1, 2, 7, 99, 1000, 123456]) {
        expect(demoSecurityPin(id), matches(RegExp(r'^[1-9]\d{3}$')));
      }
      expect(demoSecurityPin(1), isNot(demoSecurityPin(2)));
    });

    test('CO2 estimate is derived from the distance (120 g/km)', () {
      expect(co2SavedKg(10000), '1.2');
      expect(co2SavedKg(0), '0.0');
    });
  });

  group('UI variants (login_sign_up, splash_onboarding)', () {
    test('hub variant sends logged-out users to /intro or /auth', () {
      const out = SessionUnauthenticated();
      expect(
        appRedirect(
          session: out,
          onboardingSeen: false,
          location: '/splash',
          hubVariant: true,
        ),
        '/intro',
      );
      expect(
        appRedirect(
          session: out,
          onboardingSeen: true,
          location: '/splash',
          hubVariant: true,
        ),
        '/auth',
      );
      // Classic flow is unchanged.
      expect(
        appRedirect(session: out, onboardingSeen: true, location: '/splash'),
        '/welcome',
      );
      // Both variants are public routes in either mode.
      expect(
        appRedirect(session: out, onboardingSeen: true, location: '/auth'),
        isNull,
      );
      expect(
        appRedirect(session: out, onboardingSeen: false, location: '/intro'),
        isNull,
      );
    });

    testWidgets(
      'login_sign_up: e-mail login calls POST auth/login; New Rider opens sign-up',
      (tester) async {
        final (o, a, store) = await _env();
        a
          ..json('POST', '/auth/login', 200, loginJson())
          ..json('GET', '/rides', 200, {
            'data': [],
            'meta': {'current_page': 1, 'last_page': 1},
          });
        await _pump(tester, o);
        GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/auth');
        await tester.pumpAndSettle();
        expect(find.text('Welcome to Nordic Ride'), findsOneWidget);

        // Unbuilt providers / biometrics are not shown.
        for (final k in [
          'hub_google',
          'hub_vipps',
          'hub_biometric',
          'hub_language',
        ]) {
          expect(find.byKey(Key(k)), findsNothing);
        }

        await tester.enterText(
          find.byKey(const Key('hub_email')),
          'rider1@example.com',
        );
        await tester.enterText(
          find.byKey(const Key('hub_password')),
          'Password123!',
        );
        await tester.ensureVisible(find.byKey(const Key('hub_submit')));
        await tester.tap(find.byKey(const Key('hub_submit')));
        await tester.pumpAndSettle();
        final body = a.where('POST', '/auth/login').single.data as Map;
        expect(body['email'], 'rider1@example.com');
        expect((await store.read())!.token, 'tok_123');
      },
    );

    testWidgets(
      'login_sign_up: the New Rider tab leads to the real sign-up flow',
      (tester) async {
        final (o, _, _) = await _env();
        await _pump(tester, o);
        GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/auth');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('hub_tab_1')));
        await tester.pump();
        await tester.ensureVisible(find.byKey(const Key('hub_submit')));
        await tester.tap(find.byKey(const Key('hub_submit')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('signup_name')), findsOneWidget);
      },
    );

    testWidgets(
      'splash_onboarding: three slides, Skip and Sign In mark onboarding as seen',
      (tester) async {
        final (o, _, _) = await _env(seen: false);
        await _pump(tester, o);
        GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/intro');
        await tester.pumpAndSettle();
        expect(find.text('Book a ride in seconds.'), findsOneWidget);
        await tester.tap(find.byKey(const Key('intro_next')));
        await tester.pumpAndSettle();
        expect(find.text('Track your driver live.'), findsOneWidget);
        await tester.tap(find.byKey(const Key('intro_next')));
        await tester.pumpAndSettle();
        expect(find.text('Pay your way.'), findsOneWidget);
        expect(find.text('Get started'), findsOneWidget);
        await tester.tap(find.byKey(const Key('intro_next')));
        await tester.pumpAndSettle();
        expect(find.text('Your ride in Oslo'), findsOneWidget);
      },
    );
  });
}
