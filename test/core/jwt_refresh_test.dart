import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/core/network/api_client.dart';
import 'package:rider_app/core/storage/token_store.dart';

import '../helpers/test_helpers.dart';

/// Backend v1.1 JWT behaviour in the Dio client: single-flight rotation, proactive refresh with
/// less than 5 minutes left, refresh + ONE retry on 401, sign-out when that fails.
void main() {
  late ScriptedAdapter adapter;
  late InMemoryTokenStore store;
  late int signOuts;
  late int refreshCalls;
  late Dio dio;

  /// `/auth/refresh` rotates: only the current token is accepted, a new one is issued.
  var currentValid = 'tok_1';
  var counter = 1;

  Dio build({Duration left = const Duration(minutes: 30)}) {
    adapter = ScriptedAdapter();
    store = InMemoryTokenStore(
      StoredSession(token: 'tok_1', expiresAt: DateTime.now().add(left)),
    );
    signOuts = 0;
    refreshCalls = 0;
    currentValid = 'tok_1';
    counter = 1;
    adapter.on('POST', '/auth/refresh', (o) async {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final sent = (o.headers['Authorization'] as String).replaceFirst(
        'Bearer ',
        '',
      );
      if (sent != currentValid) {
        return ScriptedAdapter.jsonBody(401, {'message': 'Unauthenticated.'});
      }
      counter++;
      currentValid = 'tok_$counter';
      return ScriptedAdapter.jsonBody(200, {
        'token': currentValid,
        'token_type': 'Bearer',
        'expires_in': 3600,
        'expires_at': DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
      });
    });
    // A protected endpoint that only accepts the currently valid token.
    adapter.on('GET', '/rides', (o) {
      final sent = (o.headers['Authorization'] as String?)?.replaceFirst(
        'Bearer ',
        '',
      );
      if (sent != currentValid) {
        return ScriptedAdapter.jsonBody(401, {'message': 'Unauthenticated.'});
      }
      return ScriptedAdapter.jsonBody(200, {
        'data': [],
        'meta': {'current_page': 1, 'last_page': 1},
      });
    });
    return dio = createApiClient(
      tokenStore: store,
      baseUrl: 'http://test',
      adapter: adapter,
      onUnauthorized: () => signOuts++,
    );
  }

  List<RequestOptions> calls(String method, String path) => adapter.requests
      .where((r) => r.method == method && r.path == path)
      .toList();

  test(
    'token with more than 5 minutes left is used as is (no refresh)',
    () async {
      build();
      await dio.get<dynamic>('/rides');
      expect(refreshCalls, 0);
      expect(
        calls('GET', '/rides').single.headers['Authorization'],
        'Bearer tok_1',
      );
    },
  );

  test('fewer than 5 minutes left: refresh first, then send the request with the NEW token', () async {
    build(left: const Duration(minutes: 3));
    await dio.get<dynamic>('/rides');
    expect(refreshCalls, 1);
    expect(
      calls('GET', '/rides').single.headers['Authorization'],
      'Bearer tok_2',
    );
    final saved = await store.read();
    expect(saved!.token, 'tok_2');
    expect(
      saved.expiresAt!.isAfter(DateTime.now().add(const Duration(minutes: 30))),
      isTrue,
    );
    expect(signOuts, 0);
  });

  test('parallel requests near expiry share ONE refresh (rotation would kill a second one)', () async {
    build(left: const Duration(minutes: 1));
    final results = await Future.wait([
      for (var i = 0; i < 6; i++) dio.get<dynamic>('/rides'),
    ]);
    expect(results, hasLength(6));
    expect(refreshCalls, 1);
    for (final r in calls('GET', '/rides')) {
      expect(r.headers['Authorization'], 'Bearer tok_2');
    }
    expect(signOuts, 0);
  });

  test('401 on a normal request: one refresh, ONE retry with the new token, no sign-out', () async {
    build();
    currentValid = 'rotated_elsewhere'; // server revoked tok_1, but refresh with tok_1 also fails...
    // ...so make the server accept tok_1 for refresh only: simulate "token expired early".
    adapter.on('POST', '/auth/refresh', (o) {
      refreshCalls++;
      currentValid = 'tok_2';
      return ScriptedAdapter.jsonBody(200, {
        'token': 'tok_2',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'expires_at': DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
      });
    });
    final r = await dio.get<dynamic>('/rides');
    expect(r.statusCode, 200);
    expect(refreshCalls, 1);
    final gets = calls('GET', '/rides');
    expect(gets, hasLength(2), reason: 'original + exactly one retry');
    expect(gets.first.headers['Authorization'], 'Bearer tok_1');
    expect(gets.last.headers['Authorization'], 'Bearer tok_2');
    expect((await store.read())!.token, 'tok_2');
    expect(signOuts, 0);
  });

  test(
    'parallel 401s trigger a single refresh and every request is retried once',
    () async {
      build();
      currentValid = 'tok_2';
      adapter.on('POST', '/auth/refresh', (o) async {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return ScriptedAdapter.jsonBody(200, {
          'token': 'tok_2',
          'token_type': 'Bearer',
          'expires_in': 3600,
          'expires_at': DateTime.now()
              .add(const Duration(hours: 1))
              .toUtc()
              .toIso8601String(),
        });
      });
      final results = await Future.wait([
        for (var i = 0; i < 4; i++) dio.get<dynamic>('/rides'),
      ]);
      expect(results.every((r) => r.statusCode == 200), isTrue);
      expect(refreshCalls, 1);
      expect(calls('GET', '/rides'), hasLength(8));
      expect(signOuts, 0);
    },
  );

  test('refresh answered 401 (e.g. 14-day session limit): token cleared, signed out once, original 401 surfaces', () async {
    build();
    currentValid =
        'something_else'; // GET 401s, and refresh with tok_1 401s too
    await expectLater(
      dio.get<dynamic>('/rides'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    expect(refreshCalls, 1);
    expect(await store.read(), isNull);
    expect(signOuts, 1);
  });

  test(
    'second 401 after a successful refresh signs out (no refresh loop)',
    () async {
      build();
      adapter.on('POST', '/auth/refresh', (o) {
        refreshCalls++;
        return ScriptedAdapter.jsonBody(200, {
          'token': 'tok_new',
          'token_type': 'Bearer',
          'expires_in': 3600,
          'expires_at': DateTime.now()
              .add(const Duration(hours: 1))
              .toUtc()
              .toIso8601String(),
        });
      });
      adapter.json('GET', '/rides', 401, {'message': 'Unauthenticated.'});
      await expectLater(
        dio.get<dynamic>('/rides'),
        throwsA(isA<DioException>()),
      );
      expect(refreshCalls, 1, reason: 'exactly one refresh, never a loop');
      expect(calls('GET', '/rides'), hasLength(2));
      expect(await store.read(), isNull);
      expect(signOuts, 1);
    },
  );

  test('network failure during refresh never signs the user out', () async {
    build(left: const Duration(minutes: 2));
    adapter.networkDown('POST', '/auth/refresh');
    final r = await dio.get<dynamic>('/rides');
    expect(r.statusCode, 200, reason: 'the still-valid token is used');
    expect(signOuts, 0);
    expect((await store.read())!.token, 'tok_1');
  });

  test('wrong password (401 on login) is not a session problem: no refresh, no sign-out', () async {
    build();
    adapter.json('POST', '/auth/login', 401, {
      'message': 'Invalid credentials.',
    });
    await expectLater(
      dio.post<dynamic>(
        '/auth/login',
        options: Options(extra: {kSkipUnauthorizedHandling: true}),
      ),
      throwsA(isA<DioException>()),
    );
    expect(refreshCalls, 0);
    expect(signOuts, 0);
  });

  test('an already expired token is not refreshed (the server would reject it): request fails 401, sign-out', () async {
    build(left: const Duration(minutes: -2));
    currentValid = 'x';
    await expectLater(dio.get<dynamic>('/rides'), throwsA(isA<DioException>()));
    expect(signOuts, 1);
  });
}
