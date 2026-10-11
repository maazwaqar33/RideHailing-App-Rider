import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/core/network/api_client.dart';
import 'package:rider_app/core/network/api_exception.dart';
import 'package:rider_app/core/storage/token_store.dart';
import 'package:rider_app/features/fare/data/fare_repository_impl.dart';
import 'package:rider_app/features/fare/domain/fare_models.dart';
import 'package:rider_app/features/rides/domain/ride_models.dart';
import 'package:rider_app/mock/mock_fare_estimator.dart';
import 'package:rider_app/shared/widgets.dart';

import '../helpers/test_helpers.dart';

FareRepositoryImpl _real(ScriptedAdapter a) => FareRepositoryImpl(
  createApiClient(
    tokenStore: InMemoryTokenStore(),
    onUnauthorized: () {},
    baseUrl: 'http://test',
    adapter: a,
  ),
);

const _req = FareEstimateRequest(distanceMeters: 4200, durationSeconds: 600);

void main() {
  group('real estimate (POST fares/estimate)', () {
    test('parses the breakdown and marks source backend', () async {
      final a = ScriptedAdapter()
        ..json('POST', '/fares/estimate', 200, {
          'data': {
            'breakdown': breakdownJson(),
            'pickup': null,
            'dropoff': null,
            'distance_source': 'client_supplied',
          },
        });
      final e = await _real(a).estimate(_req);
      expect(e.source, FareSource.backend);
      expect(e.isMock, isFalse);
      expect(e.totalMinor, 1744);
      expect(e.distanceSource, 'client_supplied');
      expect((a.requests.single.data as Map)['distance_meters'], 4200);
    });
  });

  group('fallback policy', () {
    FallbackFareRepository build(ScriptedAdapter a, {bool enabled = true}) =>
        FallbackFareRepository(
          real: _real(a),
          mock: const MockFareEstimator(),
          fallbackEnabled: enabled,
        );

    test(
      'backend unreachable -> mock estimate, clearly flagged, with reason',
      () async {
        final a = ScriptedAdapter()..networkDown('POST', '/fares/estimate');
        final e = await build(a).estimate(_req);
        expect(e.isMock, isTrue);
        expect(e.source, FareSource.mockFallback);
        expect(e.fallbackReason, isNotEmpty);
      },
    );

    test('a 500 from the backend is NOT silently replaced by a mock', () async {
      final a = ScriptedAdapter()
        ..json('POST', '/fares/estimate', 500, {'message': 'boom'});
      expect(
        build(a).estimate(_req),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.server,
          ),
        ),
      );
    });

    test('a 422 from the backend propagates', () async {
      final a = ScriptedAdapter()
        ..json('POST', '/fares/estimate', 422, {
          'message': 'bad',
          'errors': {
            'distance_meters': ['x'],
          },
        });
      expect(build(a).estimate(_req), throwsA(isA<ApiException>()));
    });

    test('a 401 propagates (session handling, not a mock)', () async {
      final a = ScriptedAdapter()
        ..json('POST', '/fares/estimate', 401, {'message': 'Unauthenticated.'});
      expect(
        build(a).estimate(_req),
        throwsA(
          isA<ApiException>().having((e) => e.isUnauthorized, 'unauth', true),
        ),
      );
    });

    test('fallback disabled -> network error propagates', () async {
      final a = ScriptedAdapter()..networkDown('POST', '/fares/estimate');
      expect(
        build(a, enabled: false).estimate(_req),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('mock estimator mirrors the backend integer formula', () {
    test('seeded rule: 4.2 km / 10 min', () async {
      // base 350 + 120*4.2 (504) + 30*10 (300) = 1154; +100 fee = 1254; tax 12% = 150 (half-up); total 1404
      final e = await const MockFareEstimator().estimate(_req);
      expect(e.breakdown.distanceChargeMinor, 504);
      expect(e.breakdown.timeChargeMinor, 300);
      expect(e.breakdown.fareMinor, 1154);
      expect(e.breakdown.taxMinor, 150);
      expect(e.totalMinor, 1404);
      expect(e.isMock, isTrue);
    });

    test('minimum fare applies on short trips', () async {
      final e = await const MockFareEstimator().estimate(
        const FareEstimateRequest(distanceMeters: 300, durationSeconds: 60),
      );
      expect(e.breakdown.minimumFareAdjustmentMinor, greaterThan(0));
      expect(e.breakdown.fareMinor, MockFareEstimator.minimumMinor);
    });
  });

  group('fare breakdown rendering', () {
    testWidgets('renders each component and the total from API minor units', (
      tester,
    ) async {
      final b = FareBreakdown.fromJson(breakdownJson());
      await tester.pumpWidget(
        wrapApp(
          Scaffold(body: FareBreakdownCard(breakdown: b)),
          overrides: await baseOverrides(),
        ),
      );
      expect(find.text('Base fare'), findsOneWidget);
      expect(find.text('€3.50'), findsOneWidget);
      expect(find.text('€5.04'), findsOneWidget);
      expect(find.text('€3.00'), findsOneWidget);
      expect(find.text('Booking fee'), findsOneWidget);
      expect(find.text('€1.00'), findsOneWidget);
      expect(find.text('Tax'), findsOneWidget);
      expect(find.byKey(const Key('fare_total')), findsOneWidget);
      expect(find.text('€17.44'), findsOneWidget);
      expect(find.text('Minimum fare adjustment'), findsNothing);
    });

    testWidgets('shows minimum-fare adjustment only when non-zero', (
      tester,
    ) async {
      final json = breakdownJson()..['minimum_fare_adjustment_minor'] = 250;
      await tester.pumpWidget(
        wrapApp(
          Scaffold(
            body: FareBreakdownCard(breakdown: FareBreakdown.fromJson(json)),
          ),
          overrides: await baseOverrides(),
        ),
      );
      expect(find.text('Minimum fare adjustment'), findsOneWidget);
      expect(find.text('€2.50'), findsOneWidget);
    });
  });
}
