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
import 'package:rider_app/features/trip/application/trip_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

class _NoLocation implements LocationService {
  @override
  Future<LocationResult> current() async =>
      const LocationResult(status: LocationStatus.denied);
}

Map<String, dynamic> _completed({int id = 42, String method = 'cash'}) =>
    rideJson(
      id: id,
      status: 'completed',
      withDriver: true,
      paymentMethod: method,
      finalMinor: 1744,
    );

Future<(List<Override>, ScriptedAdapter)> _env({
  List<Map<String, dynamic>> rides = const [],
}) async {
  final store = InMemoryTokenStore(
    StoredSession(
      token: 't',
      expiresAt: DateTime.now().add(const Duration(hours: 5)),
    ),
  );
  final adapter = ScriptedAdapter()
    ..json('GET', '/auth/me', 200, {'data': userJson()})
    ..json('GET', '/rides', 200, {
      'data': rides,
      'meta': {'current_page': 1, 'last_page': 1},
    });
  final base = await baseOverrides(
    tokenStore: store,
    prefs: {'flag.onboarding_seen': true},
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
  );
}

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  tester.view.physicalSize = const Size(430, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const RiderApp()),
  );
  await tester.pumpAndSettle();
}

Future<void> _openTrips(WidgetTester tester) async {
  await tester.tap(find.text('Trips'));
  await tester.pumpAndSettle();
}

void main() {
  group('trip history (GET rides, own rides)', () {
    testWidgets(
      'lists completed and cancelled rides with fare, status and driver',
      (tester) async {
        final (o, _) = await _env(
          rides: [
            _completed(id: 3),
            rideJson(id: 2, status: 'cancelled'),
          ],
        );
        await _pump(tester, o);
        await _openTrips(tester);
        expect(find.byKey(const Key('ride_card_3')), findsOneWidget);
        expect(find.byKey(const Key('ride_card_2')), findsOneWidget);
        expect(find.text('Completed'), findsOneWidget);
        expect(find.text('Cancelled'), findsOneWidget);
        expect(find.text('€17.44'), findsWidgets);
        expect(find.textContaining('Erik'), findsOneWidget);
        expect(find.textContaining('EL 12345'), findsOneWidget);
      },
    );

    testWidgets('empty state', (tester) async {
      final (o, _) = await _env();
      await _pump(tester, o);
      await _openTrips(tester);
      expect(find.byKey(const Key('trips_empty')), findsOneWidget);
    });

    testWidgets('error state with retry', (tester) async {
      final (o, a) = await _env();
      a.networkDown('GET', '/rides');
      await _pump(tester, o);
      await _openTrips(tester);
      expect(find.text('Try again'), findsOneWidget);
      a.json('GET', '/rides', 200, {
        'data': [_completed(id: 3)],
        'meta': {'current_page': 1, 'last_page': 1},
      });
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ride_card_3')), findsOneWidget);
    });

    testWidgets('no Scheduled tab (not built, so not shown)', (tester) async {
      final (o, _) = await _env();
      await _pump(tester, o);
      await _openTrips(tester);
      expect(find.text('Scheduled'), findsNothing);
      expect(find.byKey(const Key('trips_scheduled')), findsNothing);
    });

    testWidgets(
      'receipt shows real breakdown, timeline from GET timeline, and demo payment status',
      (tester) async {
        final (o, a) = await _env(rides: [_completed(id: 3)]);
        a.json('GET', '/rides/3', 200, {
          'data': _completed(id: 3, method: 'card'),
        });
        a.json('GET', '/rides/3/timeline', 200, {
          'data': [
            {
              'id': 1,
              'from_status': null,
              'to_status': 'requested',
              'actor_role': 'rider',
              'reason': null,
              'created_at': '2026-10-10T10:00:00+00:00',
            },
            {
              'id': 2,
              'from_status': 'requested',
              'to_status': 'offered',
              'actor_role': 'manager',
              'reason': null,
              'created_at': '2026-10-10T10:01:00+00:00',
            },
            {
              'id': 3,
              'from_status': 'offered',
              'to_status': 'accepted',
              'actor_role': 'driver',
              'reason': null,
              'created_at': '2026-10-10T10:02:00+00:00',
            },
            {
              'id': 7,
              'from_status': 'in_progress',
              'to_status': 'completed',
              'actor_role': 'driver',
              'reason': null,
              'created_at': '2026-10-10T10:20:00+00:00',
            },
          ],
        });
        await _pump(tester, o);
        await _openTrips(tester);
        await tester.tap(find.byKey(const Key('ride_card_3')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('receipt_total')), findsOneWidget);
        expect(find.text('€17.44'), findsWidgets);
        expect(find.byKey(const Key('fare_breakdown')), findsOneWidget);
        expect(find.byKey(const Key('receipt_payment_status')), findsOneWidget);
        expect(find.textContaining('not_charged'), findsOneWidget);
        expect(find.text('Card (demo)'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('timeline_list')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Requested'), findsOneWidget);
        expect(find.text('Driver assigned'), findsOneWidget);
        expect(find.text('Completed'), findsWidgets);
      },
    );

    testWidgets('cancelled receipt shows the cancellation reason', (
      tester,
    ) async {
      final (o, a) = await _env(
        rides: [
          rideJson(id: 2, status: 'cancelled', cancelReason: 'Plans changed'),
        ],
      );
      a.json('GET', '/rides/2', 200, {
        'data': rideJson(
          id: 2,
          status: 'cancelled',
          cancelReason: 'Plans changed',
        ),
      });
      a.json('GET', '/rides/2/timeline', 200, {'data': []});
      await _pump(tester, o);
      await _openTrips(tester);
      await tester.tap(find.byKey(const Key('ride_card_2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('receipt_cancelled')), findsOneWidget);
      expect(find.textContaining('Plans changed'), findsWidgets);
    });
  });

  group('trip completion (real fare, MOCK payment, local rating)', () {
    Future<(List<Override>, ScriptedAdapter)> openComplete(
      WidgetTester tester, {
      String method = 'cash',
    }) async {
      final (o, a) = await _env(rides: [_completed(method: method)]);
      a.json('GET', '/rides/42', 200, {'data': _completed(method: method)});
      await _pump(tester, o);
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/ride-complete/42');
      await tester.pumpAndSettle();
      return (o, a);
    }

    testWidgets(
      'shows the real fare breakdown total and labels payment as demo / not charged',
      (tester) async {
        await openComplete(tester);
        expect(find.byKey(const Key('complete_title')), findsOneWidget);
        expect(find.byKey(const Key('fare_breakdown')), findsOneWidget);
        expect(find.text('€17.44'), findsWidgets);
        expect(find.textContaining('Demo payment'), findsWidgets);
        expect(find.textContaining('Nothing was charged'), findsOneWidget);
        expect(find.textContaining('"not_charged"'), findsOneWidget);
        expect(find.text('Confirm cash payment (demo)'), findsOneWidget);
        expect(find.byKey(const Key('driver_name')), findsOneWidget);
      },
    );

    testWidgets('card ride says card, still demo', (tester) async {
      await openComplete(tester, method: 'card');
      expect(find.text('Confirm card payment (demo)'), findsOneWidget);
      expect(find.textContaining('Demo payment'), findsWidgets);
    });

    testWidgets(
      'confirming payment records a MOCK receipt locally and never writes to the backend',
      (tester) async {
        final (_, a) = await openComplete(tester);
        final before = a.requests.length;
        await tester.ensureVisible(find.byKey(const Key('confirm_payment')));
        await tester.tap(find.byKey(const Key('confirm_payment')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('payment_confirmed')), findsOneWidget);
        expect(find.textContaining('MOCK-42-'), findsOneWidget);
        expect(find.textContaining('no money moved'), findsOneWidget);
        expect(
          a.requests.skip(before).where((r) => r.method != 'GET'),
          isEmpty,
        );
      },
    );

    testWidgets(
      'rating + comment + tip are saved locally and clearly labelled as device-only',
      (tester) async {
        final (_, a) = await openComplete(tester);
        expect(find.byKey(const Key('rating_device_only')), findsOneWidget);
        expect(find.text('TAP A STAR TO RATE'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('rating_stars')));
        await tester.tap(find.byKey(const ValueKey('star_5')));
        await tester.pump();
        expect(find.text('EXCEPTIONAL EXPERIENCE'), findsOneWidget);
        await tester.tap(find.byKey(const Key('tag_Quiet ride')));
        await tester.enterText(
          find.byKey(const Key('rating_comment')),
          'Smooth ride',
        );
        await tester.ensureVisible(find.byKey(const Key('tip_500')));
        await tester.tap(find.byKey(const Key('tip_500')));
        await tester.pump();
        await tester.ensureVisible(find.byKey(const Key('complete_done')));
        expect(find.text('Done & Submit Review'), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byKey(const Key('complete_done'))),
        );
        await tester.tap(find.byKey(const Key('complete_done')));
        await tester.pumpAndSettle();

        final saved = await container.read(feedbackRepositoryProvider).get(42);
        expect(saved!.rating, 5);
        expect(saved.comment, 'Smooth ride');
        expect(saved.tags, ['Quiet ride']);
        expect(saved.tipMinor, 500);
        final receipt = await container
            .read(paymentServiceProvider)
            .receiptFor(42);
        expect(receipt!.tipMinor, 500);
        expect(receipt.isMock, isTrue);
        expect(
          a.requests.where((r) => r.method != 'GET'),
          isEmpty,
          reason: 'rating/tip never hit the API',
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('mock.feedback.v1'), contains('Smooth ride'));
        expect(
          find.byKey(const Key('bottom_nav')),
          findsOneWidget,
          reason: 'returns home',
        );
      },
    );

    testWidgets('report a problem is a mock saved on the device', (
      tester,
    ) async {
      final (_, a) = await openComplete(tester);
      await tester.ensureVisible(find.byKey(const Key('report_problem')));
      await tester.tap(find.byKey(const Key('report_problem')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report_mock_banner')), findsOneWidget);
      expect(
        find.textContaining('not sent to Nordic Mobility support'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('cat_Wrong fare')));
      await tester.enterText(
        find.byKey(const Key('report_details')),
        'Fare looked too high',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('report_submit')));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('mock.reports.v1'), contains('Wrong fare'));
      expect(a.requests.where((r) => r.method != 'GET'), isEmpty);
    });
  });

  group(
    'rating screen (Stitch rate_and_tip_driver), wallet and history extras',
    () {
      testWidgets('rate & tip saves locally, never writes to the API', (
        tester,
      ) async {
        final (o, a) = await _env(rides: [_completed()]);
        a.json('GET', '/rides/42', 200, {'data': _completed()});
        await _pump(tester, o);
        GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/rate/42');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('rate_route')), findsOneWidget);
        // Submit is disabled until a star is chosen.
        expect(find.text('Tap a star to rate your driver'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('star_4')));
        await tester.pump();
        expect(find.text('GREAT RIDE'), findsOneWidget);
        await tester.tap(find.byKey(const Key('tag_Smooth driving')));
        await tester.enterText(
          find.byKey(const Key('rating_comment')),
          'Lovely',
        );
        await tester.ensureVisible(find.byKey(const Key('tip_500')));
        await tester.tap(find.byKey(const Key('tip_500')));
        await tester.pump();
        final container = ProviderScope.containerOf(
          tester.element(find.byKey(const Key('rate_route'))),
        );
        await tester.ensureVisible(find.byKey(const Key('submit_review')));
        await tester.tap(find.byKey(const Key('submit_review')));
        await tester.pumpAndSettle();
        final saved = await container.read(feedbackRepositoryProvider).get(42);
        expect(saved!.rating, 4);
        expect(saved.tags, ['Smooth driving']);
        expect(saved.tipMinor, 500);
        expect(a.requests.where((r) => r.method != 'GET'), isEmpty);
      });

      testWidgets('history card expands a receipt drawer with re-book', (
        tester,
      ) async {
        final (o, _) = await _env(rides: [_completed(id: 3)]);
        await _pump(tester, o);
        await _openTrips(tester);
        expect(find.byKey(const Key('receipt_drawer_3')), findsNothing);
        await tester.tap(find.byKey(const Key('receipt_toggle_3')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('receipt_drawer_3')), findsOneWidget);
        expect(find.text('Re-book Ride'), findsOneWidget);
        expect(find.text('Full receipt'), findsOneWidget);
      });

      testWidgets(
        'wallet: default payment method is the real PATCH; no Vipps / top-up / add-card / prefs',
        (tester) async {
          final (o, a) = await _env();
          a
            ..json('GET', '/me/rider', 200, {
              'data': {
                'id': 1,
                'first_name': 'Kari',
                'last_name': 'Hansen',
                'default_payment_method': 'cash',
              },
            })
            ..json('PATCH', '/me/rider', 200, {
              'data': {
                'id': 1,
                'first_name': 'Kari',
                'last_name': 'Hansen',
                'default_payment_method': 'card',
              },
            });
          await _pump(tester, o);
          await tester.tap(find.text('Wallet'));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('wallet_default_cash')), findsOneWidget);
          await tester.ensureVisible(find.byKey(const Key('wallet_card')));
          await tester.tap(find.byKey(const Key('wallet_card')));
          await tester.pumpAndSettle();
          final patch = a.where('PATCH', '/me/rider').single.data as Map;
          expect(patch['default_payment_method'], 'card');
          for (final k in [
            'wallet_vipps',
            'wallet_topup',
            'wallet_add_method',
            'pref_dark',
            'pref_language',
            'account_export',
            'account_delete',
          ]) {
            expect(find.byKey(Key(k)), findsNothing);
          }
          expect(find.text('Available Balance'), findsNothing);
          expect(find.byKey(const Key('wallet_trips')), findsOneWidget);
        },
      );
    },
  );
}
