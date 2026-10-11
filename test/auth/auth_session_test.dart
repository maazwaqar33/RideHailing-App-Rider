import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/core/network/api_client.dart';
import 'package:rider_app/core/network/api_exception.dart';
import 'package:rider_app/core/providers.dart';
import 'package:rider_app/core/storage/token_store.dart';
import 'package:rider_app/features/auth/application/session_controller.dart';
import 'package:rider_app/features/auth/data/auth_repository_impl.dart';
import 'package:rider_app/features/auth/domain/auth_models.dart';

import '../helpers/test_helpers.dart';

ProviderContainer _container(
  ScriptedAdapter adapter,
  InMemoryTokenStore store,
) {
  final c = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(store),
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
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('session restore (validate stored token via GET auth/me)', () {
    test('no stored token -> unauthenticated, no network call', () async {
      final adapter = ScriptedAdapter();
      final c = _container(adapter, InMemoryTokenStore());
      await c.read(sessionControllerProvider.notifier).restore();
      expect(c.read(sessionControllerProvider), isA<SessionUnauthenticated>());
      expect(adapter.requests, isEmpty);
    });

    test('valid token -> authenticated with user from /auth/me, bearer header sent', () async {
      final adapter = ScriptedAdapter()
        ..json('GET', '/auth/me', 200, {'data': userJson()});
      final store = InMemoryTokenStore(
        StoredSession(
          token: 'abc',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      final c = _container(adapter, store);
      await c.read(sessionControllerProvider.notifier).restore();
      final state = c.read(sessionControllerProvider);
      expect(state, isA<SessionAuthenticated>());
      expect((state as SessionAuthenticated).user.email, 'rider1@example.com');
      expect(adapter.requests.single.headers['Authorization'], 'Bearer abc');
    });

    test('server says 401 and the refresh is refused too -> token cleared, signed out with notice', () async {
      final adapter = ScriptedAdapter()
        ..json('GET', '/auth/me', 401, {'message': 'Unauthenticated.'})
        ..json('POST', '/auth/refresh', 401, {
          'message': 'Session expired. Please log in again.',
        });
      final store = InMemoryTokenStore(
        StoredSession(
          token: 'dead',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      final c = _container(adapter, store);
      await c.read(sessionControllerProvider.notifier).restore();
      final state = c.read(sessionControllerProvider);
      expect(state, isA<SessionUnauthenticated>());
      expect(
        (state as SessionUnauthenticated).notice,
        ApiErrorMapper.sessionExpiredMessage,
      );
      expect(await store.read(), isNull);
      expect(adapter.requests.map((r) => '${r.method} ${r.path}').toList(), [
        'GET /auth/me',
        'POST /auth/refresh',
      ], reason: 'one refresh attempt, no retry because it was refused');
    });

    test(
      'locally expired token is dropped without calling the server',
      () async {
        final adapter = ScriptedAdapter();
        final store = InMemoryTokenStore(
          StoredSession(
            token: 'old',
            expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          ),
        );
        final c = _container(adapter, store);
        await c.read(sessionControllerProvider.notifier).restore();
        expect(
          c.read(sessionControllerProvider),
          isA<SessionUnauthenticated>(),
        );
        expect(adapter.requests, isEmpty);
        expect(await store.read(), isNull);
      },
    );

    test(
      'network failure keeps the token and offers retry (does not log out)',
      () async {
        final adapter = ScriptedAdapter()..networkDown('GET', '/auth/me');
        final store = InMemoryTokenStore(
          StoredSession(
            token: 'abc',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );
        final c = _container(adapter, store);
        await c.read(sessionControllerProvider.notifier).restore();
        expect(c.read(sessionControllerProvider), isA<SessionRestoreFailed>());
        expect(await store.read(), isNotNull);

        adapter.json('GET', '/auth/me', 200, {'data': userJson()});
        await c.read(sessionControllerProvider.notifier).restore();
        expect(c.read(sessionControllerProvider), isA<SessionAuthenticated>());
      },
    );

    test('timeout keeps the token (RestoreFailed with the friendly message); signInAgain clears it', () async {
      final adapter = ScriptedAdapter()..timeoutOut('GET', '/auth/me');
      final store = InMemoryTokenStore(
        StoredSession(
          token: 'abc',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      final c = _container(adapter, store);
      final n = c.read(sessionControllerProvider.notifier);
      await n.restore();
      final state = c.read(sessionControllerProvider);
      expect(state, isA<SessionRestoreFailed>());
      expect(
        (state as SessionRestoreFailed).message,
        ApiErrorMapper.timeoutMessage,
      );
      expect(await store.read(), isNotNull);
      expect(adapter.requests.single.receiveTimeout, n.restoreTimeout);

      await n.signInAgain();
      expect(c.read(sessionControllerProvider), isA<SessionUnauthenticated>());
      expect(await store.read(), isNull);
    });

    test('a non-rider account (no rider profile) is refused', () async {
      final adapter = ScriptedAdapter()
        ..json('GET', '/auth/me', 200, {'data': userJson(riderId: null)});
      final store = InMemoryTokenStore(
        StoredSession(token: 'abc', expiresAt: null),
      );
      final c = _container(adapter, store);
      await c.read(sessionControllerProvider.notifier).restore();
      final state = c.read(sessionControllerProvider);
      expect(state, isA<SessionUnauthenticated>());
      expect((state as SessionUnauthenticated).notice, kRiderOnlyMessage);
      expect(await store.read(), isNull);
    });
  });

  group('login / logout', () {
    test('login stores the token and authenticates', () async {
      final adapter = ScriptedAdapter()
        ..json('POST', '/auth/login', 200, loginJson());
      final store = InMemoryTokenStore();
      final c = _container(adapter, store);
      await c
          .read(sessionControllerProvider.notifier)
          .login(email: 'rider1@example.com', password: 'Password123!');
      expect(c.read(sessionControllerProvider), isA<SessionAuthenticated>());
      expect((await store.read())!.token, 'tok_123');
      final body = adapter.requests.single.data as Map;
      expect(body['device_name'], isNotEmpty);
      expect(body['email'], 'rider1@example.com');
    });

    test(
      'wrong password: uniform 401 message and NOT treated as expired session',
      () async {
        final adapter = ScriptedAdapter()
          ..json('POST', '/auth/login', 401, {
            'message': 'Invalid credentials.',
          });
        final c = _container(adapter, InMemoryTokenStore());
        c.read(sessionControllerProvider.notifier);
        await expectLater(
          c
              .read(sessionControllerProvider.notifier)
              .login(email: 'x@example.com', password: 'bad'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              AuthRepositoryImpl.wrongCredentials,
            ),
          ),
        );
      },
    );

    test('rate limited login surfaces 429', () async {
      final adapter = ScriptedAdapter()
        ..json(
          'POST',
          '/auth/login',
          429,
          {'message': 'Too Many Attempts.'},
          headers: {
            'retry-after': ['30'],
          },
        );
      final c = _container(adapter, InMemoryTokenStore());
      await expectLater(
        c
            .read(sessionControllerProvider.notifier)
            .login(email: 'x@example.com', password: 'bad'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.rateLimited,
          ),
        ),
      );
    });

    test('disabled account surfaces 403', () async {
      final adapter = ScriptedAdapter()
        ..json('POST', '/auth/login', 403, {
          'message': 'This account is not active.',
        });
      final c = _container(adapter, InMemoryTokenStore());
      await expectLater(
        c
            .read(sessionControllerProvider.notifier)
            .login(email: 'x@example.com', password: 'bad'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.forbidden,
          ),
        ),
      );
    });

    test(
      'staff credentials are rejected and the token is revoked + cleared',
      () async {
        final adapter = ScriptedAdapter()
          ..json('POST', '/auth/login', 200, loginJson(riderId: null))
          ..json('POST', '/auth/logout', 204, {});
        final store = InMemoryTokenStore();
        final c = _container(adapter, store);
        await expectLater(
          c
              .read(sessionControllerProvider.notifier)
              .login(email: 'manager@example.com', password: 'Password123!'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              kRiderOnlyMessage,
            ),
          ),
        );
        expect(await store.read(), isNull);
        expect(adapter.where('POST', '/auth/logout'), hasLength(1));
        expect(
          c.read(sessionControllerProvider),
          isNot(isA<SessionAuthenticated>()),
        );
      },
    );

    test(
      'logout calls POST auth/logout, clears the store and signs out',
      () async {
        final adapter = ScriptedAdapter()
          ..json('POST', '/auth/login', 200, loginJson())
          ..json('POST', '/auth/logout', 204, {});
        final store = InMemoryTokenStore();
        final c = _container(adapter, store);
        final n = c.read(sessionControllerProvider.notifier);
        await n.login(email: 'rider1@example.com', password: 'Password123!');
        await n.logout();
        expect(adapter.where('POST', '/auth/logout'), hasLength(1));
        expect(await store.read(), isNull);
        expect(
          c.read(sessionControllerProvider),
          isA<SessionUnauthenticated>(),
        );
      },
    );

    test('logout still signs out locally when the call fails', () async {
      final adapter = ScriptedAdapter()
        ..json('POST', '/auth/login', 200, loginJson())
        ..networkDown('POST', '/auth/logout');
      final store = InMemoryTokenStore();
      final c = _container(adapter, store);
      final n = c.read(sessionControllerProvider.notifier);
      await n.login(email: 'rider1@example.com', password: 'Password123!');
      await n.logout();
      expect(await store.read(), isNull);
      expect(c.read(sessionControllerProvider), isA<SessionUnauthenticated>());
    });
  });

  group('401 on an authenticated call (expired token) returns to login', () {
    test('interceptor signs out once', () async {
      final adapter = ScriptedAdapter()
        ..json('POST', '/auth/login', 200, loginJson())
        ..json('GET', '/rides', 401, {'message': 'Unauthenticated.'});
      final store = InMemoryTokenStore();
      final c = _container(adapter, store);
      await c
          .read(sessionControllerProvider.notifier)
          .login(email: 'rider1@example.com', password: 'Password123!');
      final dio = c.read(dioProvider);
      await expectLater(
        dio.get<dynamic>('/rides'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final state = c.read(sessionControllerProvider);
      expect(state, isA<SessionUnauthenticated>());
      expect(
        (state as SessionUnauthenticated).notice,
        ApiErrorMapper.sessionExpiredMessage,
      );
      expect(await store.read(), isNull);
    });
  });

  group('registration', () {
    test('POST auth/register sends required fields incl. confirmation and device_name', () async {
      final adapter = ScriptedAdapter()
        ..json('POST', '/auth/register', 201, loginJson());
      final c = _container(adapter, InMemoryTokenStore());
      await c
          .read(sessionControllerProvider.notifier)
          .register(
            const RegisterRequest(
              firstName: 'Sara',
              lastName: 'Hansen',
              email: 'sara@example.com',
              password: 'Password123!',
              phone: '+47 941 23 891',
            ),
          );
      final body = adapter.requests.single.data as Map;
      expect(body['first_name'], 'Sara');
      expect(body['last_name'], 'Hansen');
      expect(body['password_confirmation'], 'Password123!');
      expect(body['device_name'], isNotEmpty);
      expect(body['phone'], '+47 941 23 891');
      expect(c.read(sessionControllerProvider), isA<SessionAuthenticated>());
    });

    test('omits empty phone', () async {
      final adapter = ScriptedAdapter()
        ..json('POST', '/auth/register', 201, loginJson());
      final c = _container(adapter, InMemoryTokenStore());
      await c
          .read(sessionControllerProvider.notifier)
          .register(
            const RegisterRequest(
              firstName: 'Sara',
              lastName: 'Hansen',
              email: 'sara@example.com',
              password: 'Password123!',
              phone: '  ',
            ),
          );
      expect(
        (adapter.requests.single.data as Map).containsKey('phone'),
        isFalse,
      );
    });

    test('422 duplicate email exposes the field error', () async {
      final adapter = ScriptedAdapter()
        ..json('POST', '/auth/register', 422, {
          'message': 'The email has already been taken.',
          'errors': {
            'email': ['The email has already been taken.'],
          },
        });
      final c = _container(adapter, InMemoryTokenStore());
      await expectLater(
        c
            .read(sessionControllerProvider.notifier)
            .register(
              const RegisterRequest(
                firstName: 'A',
                lastName: 'B',
                email: 'rider1@example.com',
                password: 'Password123!',
              ),
            ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.fieldError('email'),
            'email',
            'The email has already been taken.',
          ),
        ),
      );
    });
  });
}
