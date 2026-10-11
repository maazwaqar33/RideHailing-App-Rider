import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rider_app/app/app.dart';
import 'package:rider_app/core/network/api_client.dart';
import 'package:rider_app/core/providers.dart';
import 'package:rider_app/core/storage/token_store.dart';
import 'package:rider_app/features/auth/application/session_controller.dart';
import 'package:rider_app/features/map/application/map_providers.dart';
import 'package:rider_app/features/map/domain/map_repositories.dart';

import '../helpers/test_helpers.dart';

class _NoLocation implements LocationService {
  @override
  Future<LocationResult> current() async =>
      const LocationResult(status: LocationStatus.denied);
}

Future<(List<Override>, ScriptedAdapter, InMemoryTokenStore)> _setup({
  Map<String, Object>? prefs,
  StoredSession? stored,
}) async {
  final store = InMemoryTokenStore(stored);
  final adapter = ScriptedAdapter();
  final base = await baseOverrides(tokenStore: store, prefs: prefs);
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

Future<void> _pumpApp(WidgetTester tester, List<Override> overrides) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const RiderApp()),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'first run: splash -> 3 onboarding pages -> welcome; onboarding flag persisted',
    (tester) async {
      final (overrides, adapter, _) = await _setup();
      await _pumpApp(tester, overrides);
      expect(find.text('Book in seconds'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      expect(find.text('Track your driver live'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      expect(find.text('Pay your way'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      expect(find.text('Your ride in Oslo'), findsOneWidget);
      expect(
        adapter.requests,
        isEmpty,
        reason: 'no token stored, so no /auth/me call',
      );
    },
  );

  testWidgets(
    'returning user (onboarding seen) lands on welcome and can skip onboarding',
    (tester) async {
      final (overrides, _, _) = await _setup(
        prefs: {'flag.onboarding_seen': true},
      );
      await _pumpApp(tester, overrides);
      expect(find.byKey(const Key('welcome_login')), findsOneWidget);
    },
  );

  testWidgets('Skip on onboarding goes to welcome', (tester) async {
    final (overrides, _, _) = await _setup();
    await _pumpApp(tester, overrides);
    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome_create_account')), findsOneWidget);
  });

  group('login screen', () {
    Future<(List<Override>, ScriptedAdapter, InMemoryTokenStore)> toLogin(
      WidgetTester tester,
    ) async {
      final r = await _setup(prefs: {'flag.onboarding_seen': true});
      await _pumpApp(tester, r.$1);
      await tester.tap(find.byKey(const Key('welcome_login')));
      await tester.pumpAndSettle();
      return r;
    }

    testWidgets('client-side validation blocks the request', (tester) async {
      final (_, adapter, _) = await toLogin(tester);
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Email is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('login_email')),
        'not-an-email',
      );
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(adapter.requests, isEmpty);
    });

    testWidgets('wrong credentials: one uniform friendly message', (
      tester,
    ) async {
      final (_, adapter, _) = await toLogin(tester);
      adapter.json('POST', '/auth/login', 401, {
        'message': 'Invalid credentials.',
      });
      await tester.enterText(
        find.byKey(const Key('login_email')),
        'rider1@example.com',
      );
      await tester.enterText(find.byKey(const Key('login_password')), 'wrong');
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      expect(find.byKey(const Key('login_error')), findsOneWidget);
    });

    testWidgets('429 shows the rate-limit message with retry-after', (
      tester,
    ) async {
      final (_, adapter, _) = await toLogin(tester);
      adapter.json(
        'POST',
        '/auth/login',
        429,
        {'message': 'Too Many Attempts.'},
        headers: {
          'retry-after': ['42'],
        },
      );
      await tester.enterText(
        find.byKey(const Key('login_email')),
        'rider1@example.com',
      );
      await tester.enterText(find.byKey(const Key('login_password')), 'x');
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('wait 42 seconds'), findsOneWidget);
    });

    testWidgets('403 disabled account message', (tester) async {
      final (_, adapter, _) = await toLogin(tester);
      adapter.json('POST', '/auth/login', 403, {
        'message': 'This account is not active.',
      });
      await tester.enterText(
        find.byKey(const Key('login_email')),
        'rider1@example.com',
      );
      await tester.enterText(find.byKey(const Key('login_password')), 'x');
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('account is not active'), findsOneWidget);
    });

    testWidgets('offline shows the network message', (tester) async {
      final (_, adapter, _) = await toLogin(tester);
      adapter.networkDown('POST', '/auth/login');
      await tester.enterText(
        find.byKey(const Key('login_email')),
        'rider1@example.com',
      );
      await tester.enterText(find.byKey(const Key('login_password')), 'x');
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining("Can't reach the server"), findsOneWidget);
    });

    testWidgets(
      'login screen has clean email/password and no third-party logins',
      (tester) async {
        await toLogin(tester);
        expect(find.byKey(const Key('login_email')), findsOneWidget);
        expect(find.byKey(const Key('login_password')), findsOneWidget);
        expect(find.byKey(const Key('login_submit')), findsOneWidget);
        // Unbuilt sign-in methods are not shown at all (no disabled / "soon" controls).
        for (final k in [
          'login_google',
          'login_apple',
          'login_vipps',
          'login_biometric',
        ]) {
          expect(find.byKey(Key(k)), findsNothing);
        }
        expect(find.textContaining('Vipps'), findsNothing);
        expect(find.textContaining('Google'), findsNothing);
        expect(find.textContaining('BankID'), findsNothing);
      },
    );

    testWidgets(
      'successful login persists the token and shows the home screen',
      (tester) async {
        final (_, adapter, store) = await toLogin(tester);
        adapter
          ..json('POST', '/auth/login', 200, loginJson())
          ..json('GET', '/rides', 200, {
            'data': [],
            'meta': {'current_page': 1, 'last_page': 1},
          });
        await tester.enterText(
          find.byKey(const Key('login_email')),
          'rider1@example.com',
        );
        await tester.enterText(
          find.byKey(const Key('login_password')),
          'Password123!',
        );
        await tester.tap(find.byKey(const Key('login_submit')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('bottom_nav')), findsOneWidget);
        expect((await store.read())!.token, 'tok_123');
        expect(find.byKey(const Key('home_greeting')), findsOneWidget);
        expect(find.textContaining('Kari'), findsWidgets);
      },
    );
  });

  testWidgets(
    'session restore across restart: stored token + valid /auth/me goes straight to home',
    (tester) async {
      final (overrides, adapter, _) = await _setup(
        prefs: {'flag.onboarding_seen': true},
        stored: StoredSession(
          token: 'persisted',
          expiresAt: DateTime.now().add(const Duration(hours: 5)),
        ),
      );
      adapter
        ..json('GET', '/auth/me', 200, {'data': userJson()})
        ..json('GET', '/rides', 200, {
          'data': [],
          'meta': {'current_page': 1, 'last_page': 1},
        });
      await _pumpApp(tester, overrides);
      expect(find.byKey(const Key('bottom_nav')), findsOneWidget);
      expect(
        adapter.where('GET', '/auth/me').single.headers['Authorization'],
        'Bearer persisted',
      );
    },
  );

  testWidgets(
    'expired server session on restore returns to welcome with a notice',
    (tester) async {
      final (overrides, adapter, store) = await _setup(
        prefs: {'flag.onboarding_seen': true},
        stored: StoredSession(
          token: 'dead',
          expiresAt: DateTime.now().add(const Duration(hours: 5)),
        ),
      );
      adapter.json('GET', '/auth/me', 401, {'message': 'Unauthenticated.'});
      await _pumpApp(tester, overrides);
      expect(find.byKey(const Key('welcome_login')), findsOneWidget);
      expect(
        find.text('Your session has expired. Please log in again.'),
        findsOneWidget,
      );
      expect(await store.read(), isNull);
    },
  );

  testWidgets(
    'restore offline: splash shows retry, token kept, retry succeeds',
    (tester) async {
      final (overrides, adapter, store) = await _setup(
        prefs: {'flag.onboarding_seen': true},
        stored: StoredSession(
          token: 'abc',
          expiresAt: DateTime.now().add(const Duration(hours: 5)),
        ),
      );
      adapter.networkDown('GET', '/auth/me');
      await _pumpApp(tester, overrides);
      expect(find.text('Could not restore your session'), findsOneWidget);
      expect(await store.read(), isNotNull);
      adapter
        ..json('GET', '/auth/me', 200, {'data': userJson()})
        ..json('GET', '/rides', 200, {
          'data': [],
          'meta': {'current_page': 1, 'last_page': 1},
        });
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bottom_nav')), findsOneWidget);
    },
  );

  testWidgets(
    'restore timeout: friendly card with Try again + Sign in again, token kept; retry works',
    (tester) async {
      final (overrides, adapter, store) = await _setup(
        prefs: {'flag.onboarding_seen': true},
        stored: StoredSession(
          token: 'abc',
          expiresAt: DateTime.now().add(const Duration(hours: 5)),
        ),
      );
      adapter.timeoutOut('GET', '/auth/me');
      await _pumpApp(tester, overrides);
      expect(find.text('Could not restore your session'), findsOneWidget);
      expect(
        find.text('The server took too long to respond. Please try again.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('splash_retry')), findsOneWidget);
      expect(find.byKey(const Key('splash_sign_in_again')), findsOneWidget);
      expect(await store.read(), isNotNull);
      adapter
        ..json('GET', '/auth/me', 200, {'data': userJson()})
        ..json('GET', '/rides', 200, {
          'data': [],
          'meta': {'current_page': 1, 'last_page': 1},
        });
      await tester.tap(find.byKey(const Key('splash_retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bottom_nav')), findsOneWidget);
    },
  );

  testWidgets(
    'restore timeout: "Sign in again" clears the session and opens the welcome/login flow',
    (tester) async {
      final (overrides, adapter, store) = await _setup(
        prefs: {'flag.onboarding_seen': true},
        stored: StoredSession(
          token: 'abc',
          expiresAt: DateTime.now().add(const Duration(hours: 5)),
        ),
      );
      adapter.timeoutOut('GET', '/auth/me');
      await _pumpApp(tester, overrides);
      await tester.tap(find.byKey(const Key('splash_sign_in_again')));
      await tester.pumpAndSettle();
      expect(await store.read(), isNull);
      expect(find.byKey(const Key('welcome_login')), findsOneWidget);
      expect(find.byKey(const Key('splash_retry')), findsNothing);
    },
  );

  group('sign-up', () {
    Future<(List<Override>, ScriptedAdapter, InMemoryTokenStore)> toSignup(
      WidgetTester tester,
    ) async {
      final r = await _setup(prefs: {'flag.onboarding_seen': true});
      await _pumpApp(tester, r.$1);
      await tester.tap(find.byKey(const Key('welcome_create_account')));
      await tester.pumpAndSettle();
      return r;
    }

    Future<void> fillStep1(
      WidgetTester tester, {
      String password = 'Password123!',
      String? phone,
    }) async {
      await tester.enterText(
        find.byKey(const Key('signup_name')),
        'Sara Hansen',
      );
      await tester.enterText(
        find.byKey(const Key('signup_email')),
        'sara@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('signup_password')),
        password,
      );
      if (phone != null) {
        await tester.enterText(find.byKey(const Key('signup_phone')), phone);
      }
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('signup_continue')));
      await tester.tap(find.byKey(const Key('signup_continue')));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'weak password is rejected with the backend rules and the checklist updates',
      (tester) async {
        await toSignup(tester);
        await tester.enterText(
          find.byKey(const Key('signup_password')),
          'short',
        );
        await tester.pump();
        await tester.ensureVisible(find.byKey(const Key('signup_continue')));
        await tester.tap(find.byKey(const Key('signup_continue')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Password needs'), findsOneWidget);
        expect(find.text('At least 10 characters'), findsOneWidget);
      },
    );

    testWidgets('single-word name is rejected', (tester) async {
      await toSignup(tester);
      await tester.enterText(find.byKey(const Key('signup_name')), 'Sara');
      await tester.ensureVisible(find.byKey(const Key('signup_continue')));
      await tester.tap(find.byKey(const Key('signup_continue')));
      await tester.pumpAndSettle();
      expect(find.text('Enter your first and last name.'), findsOneWidget);
    });

    testWidgets(
      'two-step flow: no SMS/OTP step, phone is optional and validated on step 1',
      (tester) async {
        await toSignup(tester);
        expect(find.text('Step 1 of 2'), findsOneWidget);
        expect(find.textContaining('SMS'), findsNothing);
        expect(find.textContaining('BankID'), findsNothing);
        await fillStep1(tester, phone: 'abc');
        expect(find.textContaining('valid phone number'), findsOneWidget);
        expect(find.text('Step 1 of 2'), findsOneWidget);
        await fillStep1(tester, phone: '');
        expect(find.text('STEP 2 OF 2'), findsWidgets);
        // Step 2 only keeps the real consents.
        expect(find.byKey(const Key('signup_terms')), findsOneWidget);
        expect(find.byKey(const Key('signup_biometric')), findsNothing);
        expect(find.byKey(const Key('signup_telemetry')), findsNothing);
        expect(find.byKey(const Key('signup_marketing')), findsNothing);
      },
    );

    testWidgets(
      'terms must be accepted; then register is called with split name',
      (tester) async {
        final (_, adapter, store) = await toSignup(tester);
        adapter
          ..json('POST', '/auth/register', 201, loginJson())
          ..json('GET', '/rides', 200, {
            'data': [],
            'meta': {'current_page': 1, 'last_page': 1},
          });
        await fillStep1(tester, phone: '+47 941 23 891');

        await tester.ensureVisible(find.byKey(const Key('signup_create')));
        await tester.tap(find.byKey(const Key('signup_create')));
        await tester.pumpAndSettle();
        expect(find.textContaining('must accept the Terms'), findsOneWidget);
        expect(adapter.requests, isEmpty);

        await tester.ensureVisible(find.byKey(const Key('signup_terms')));
        await tester.tap(find.byKey(const Key('signup_terms')));
        await tester.pump();
        await tester.ensureVisible(find.byKey(const Key('signup_create')));
        await tester.tap(find.byKey(const Key('signup_create')));
        await tester.pumpAndSettle();

        final body = adapter.where('POST', '/auth/register').single.data as Map;
        expect(body['first_name'], 'Sara');
        expect(body['last_name'], 'Hansen');
        expect(body['phone'], '+47 941 23 891');
        expect((await store.read())!.token, 'tok_123');
        expect(find.byKey(const Key('bottom_nav')), findsOneWidget);
      },
    );

    testWidgets(
      '422 duplicate email sends the rider back to step 1 with the field error',
      (tester) async {
        final (_, adapter, _) = await toSignup(tester);
        adapter.json('POST', '/auth/register', 422, {
          'message': 'The email has already been taken.',
          'errors': {
            'email': ['The email has already been taken.'],
          },
        });
        await fillStep1(tester);
        await tester.ensureVisible(find.byKey(const Key('signup_terms')));
        await tester.tap(find.byKey(const Key('signup_terms')));
        await tester.pump();
        await tester.ensureVisible(find.byKey(const Key('signup_create')));
        await tester.tap(find.byKey(const Key('signup_create')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('signup_email')), findsOneWidget);
        expect(find.text('The email has already been taken.'), findsWidgets);
      },
    );
  });

  group('forgot / reset password', () {
    testWidgets('forgot posts the email and shows the generic 202 message', (
      tester,
    ) async {
      final r = await _setup(prefs: {'flag.onboarding_seen': true});
      await _pumpApp(tester, r.$1);
      r.$2.json('POST', '/auth/password/forgot', 202, {
        'message': 'If the account exists, a reset link has been sent.',
      });
      await tester.tap(find.byKey(const Key('welcome_login')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('login_forgot')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('forgot_email')),
        'rider1@example.com',
      );
      await tester.tap(find.byKey(const Key('forgot_submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('forgot_success')), findsOneWidget);
      expect((r.$2.requests.single.data as Map)['email'], 'rider1@example.com');
    });

    testWidgets('reset form validates and surfaces an invalid token error', (
      tester,
    ) async {
      final r = await _setup(prefs: {'flag.onboarding_seen': true});
      await _pumpApp(tester, r.$1);
      r.$2.json('POST', '/auth/password/reset', 422, {
        'message': 'This password reset token is invalid.',
        'errors': {
          'email': ['This password reset token is invalid.'],
        },
      });
      final router = GoRouter.of(
        tester.element(find.byKey(const Key('welcome_login'))),
      );
      router.push('/reset?email=rider1%40example.com');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reset_submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('Paste the reset token from your email.'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('reset_token')), 'tok');
      await tester.enterText(
        find.byKey(const Key('reset_password')),
        'NewPassword123',
      );
      await tester.enterText(
        find.byKey(const Key('reset_confirm')),
        'NewPassword123',
      );
      await tester.ensureVisible(find.byKey(const Key('reset_submit')));
      await tester.tap(find.byKey(const Key('reset_submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reset_error')), findsOneWidget);
      final body =
          r.$2.where('POST', '/auth/password/reset').single.data as Map;
      expect(body['token'], 'tok');
      expect(body['password_confirmation'], 'NewPassword123');
    });
  });

  testWidgets('logout calls POST auth/logout and returns to welcome', (
    tester,
  ) async {
    final (overrides, adapter, store) = await _setup(
      prefs: {'flag.onboarding_seen': true},
      stored: StoredSession(
        token: 'persisted',
        expiresAt: DateTime.now().add(const Duration(hours: 5)),
      ),
    );
    adapter
      ..json('GET', '/auth/me', 200, {'data': userJson()})
      ..json('GET', '/rides', 200, {
        'data': [],
        'meta': {'current_page': 1, 'last_page': 1},
      })
      ..json('POST', '/auth/logout', 204, {});
    await _pumpApp(tester, overrides);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_email')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('logout')));
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_logout')));
    await tester.pumpAndSettle();
    expect(adapter.where('POST', '/auth/logout'), hasLength(1));
    expect(await store.read(), isNull);
    expect(find.byKey(const Key('welcome_login')), findsOneWidget);
  });
}
