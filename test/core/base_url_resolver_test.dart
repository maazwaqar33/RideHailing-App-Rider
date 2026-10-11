import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/core/config/env.dart';
import 'package:rider_app/core/network/api_client.dart';
import 'package:rider_app/core/network/base_url_resolver.dart';
import 'package:rider_app/core/storage/token_store.dart';

const _phone = 'http://127.0.0.1:8001';
const _emulator = 'http://10.0.2.2:8001';

void main() {
  group('Env.candidatesFor', () {
    test('Android without override probes the phone origin first, then the emulator', () {
      expect(Env.candidatesFor('', TargetPlatform.android, false), [
        _phone,
        _emulator,
      ]);
    });

    test(
      'an explicit override wins and is the only candidate (no probing)',
      () {
        expect(
          Env.candidatesFor(
            'http://192.168.1.20:8001/',
            TargetPlatform.android,
            false,
          ),
          ['http://192.168.1.20:8001'],
        );
      },
    );

    test('desktop and web default to 127.0.0.1:8001', () {
      expect(Env.candidatesFor('', TargetPlatform.windows, false), [_phone]);
      expect(Env.candidatesFor('', TargetPlatform.android, true), [_phone]);
    });
  });

  group('BaseUrlResolver', () {
    test(
      'first reachable candidate wins and is cached for the session',
      () async {
        final probed = <String>[];
        final r = BaseUrlResolver(
          candidates: [_phone, _emulator],
          probe: (u) async {
            probed.add(u);
            return true;
          },
        );
        expect(await r.resolve(), _phone);
        expect(await r.resolve(), _phone);
        expect(probed, [_phone]); // cached: one probe only
      },
    );

    test(
      'falls back to the second candidate when the first is unreachable',
      () async {
        final probed = <String>[];
        final r = BaseUrlResolver(
          candidates: [_phone, _emulator],
          probe: (u) async {
            probed.add(u);
            return u == _emulator;
          },
        );
        expect(await r.resolve(), _emulator);
        expect(probed, [_phone, _emulator]);
        expect(await r.resolve(), _emulator);
        expect(probed.length, 2);
      },
    );

    test('a single (override) candidate is never probed', () async {
      var probes = 0;
      final r = BaseUrlResolver(
        candidates: ['http://192.168.1.20:8001'],
        probe: (_) async {
          probes++;
          return false;
        },
      );
      expect(r.probes, isFalse);
      expect(await r.resolve(), 'http://192.168.1.20:8001');
      expect(probes, 0);
    });

    test('when nothing answers the first candidate is returned, uncached, with a short cooldown', () async {
      var t = DateTime(2026, 1, 1);
      var probes = 0;
      final r = BaseUrlResolver(
        candidates: [_phone, _emulator],
        probe: (_) async {
          probes++;
          return false;
        },
        clock: () => t,
      );
      expect(await r.resolve(), _phone);
      expect(probes, 2);
      expect(await r.resolve(), _phone); // inside the cooldown: no new probes
      expect(probes, 2);
      t = t.add(const Duration(seconds: 4));
      expect(await r.resolve(), _phone);
      expect(probes, 4);
      expect(r.current, isNull);
    });

    test('invalidate() re-probes', () async {
      final reachable = <String>{_phone};
      final r = BaseUrlResolver(
        candidates: [_phone, _emulator],
        probe: (u) async => reachable.contains(u),
      );
      expect(await r.resolve(), _phone);
      reachable
        ..clear()
        ..add(_emulator);
      r.invalidate();
      expect(await r.resolve(), _emulator);
    });
  });

  group('Dio client with a resolver', () {
    test('requests use the resolved origin; after a connection error the client re-probes once and retries on the other origin', () async {
      final reachable = <String>{_phone};
      final hosts = <String>[];
      final adapter = _OriginAdapter((o) {
        hosts.add(o.baseUrl);
        return o.baseUrl.startsWith(_phone) && !reachable.contains(_phone)
            ? throw DioException.connectionError(
                requestOptions: o,
                reason: 'adb reverse dropped',
              )
            : _ok();
      });
      final resolver = BaseUrlResolver(
        candidates: [_phone, _emulator],
        probe: (u) async => reachable.contains(u),
      );
      final dio = createApiClient(
        tokenStore: InMemoryTokenStore(),
        onUnauthorized: () {},
        resolver: resolver,
        adapter: adapter,
      );

      await dio.get<dynamic>('/ping');
      expect(hosts.last, startsWith(_phone));

      // The phone origin stops answering; the emulator one does.
      reachable
        ..clear()
        ..add(_emulator);
      final r = await dio.get<dynamic>('/ping');
      expect(r.statusCode, 200);
      expect(hosts.last, startsWith(_emulator));
      expect(resolver.current, _emulator);
    });

    test('a connection error with no better origin is surfaced after one re-probe (no loop)', () async {
      var calls = 0;
      final adapter = _OriginAdapter((o) {
        calls++;
        throw DioException.connectionError(requestOptions: o, reason: 'down');
      });
      final resolver = BaseUrlResolver(
        candidates: [_phone, _emulator],
        probe: (u) async => u == _phone,
      );
      final dio = createApiClient(
        tokenStore: InMemoryTokenStore(),
        onUnauthorized: () {},
        resolver: resolver,
        adapter: adapter,
      );
      await expectLater(
        dio.get<dynamic>('/ping'),
        throwsA(isA<DioException>()),
      );
      expect(calls, 1); // same origin after the re-probe: not retried
    });

    test('an explicit baseUrl never probes', () async {
      final adapter = _OriginAdapter((o) => _ok());
      final dio = createApiClient(
        tokenStore: InMemoryTokenStore(),
        onUnauthorized: () {},
        baseUrl: 'http://example.test',
        adapter: adapter,
      );
      await dio.get<dynamic>('/ping');
      expect(adapter.last!.baseUrl, 'http://example.test/api/v1');
    });
  });
}

ResponseBody _ok() => ResponseBody.fromString(
  jsonEncode({'ok': true}),
  200,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

class _OriginAdapter implements HttpClientAdapter {
  _OriginAdapter(this._handler);

  final ResponseBody Function(RequestOptions) _handler;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
