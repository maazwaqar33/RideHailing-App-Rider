import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/app/app.dart';
import 'package:rider_app/core/network/api_client.dart';
import 'package:rider_app/core/providers.dart';
import 'package:rider_app/core/storage/token_store.dart';
import 'package:rider_app/features/auth/application/session_controller.dart';
import 'package:rider_app/features/map/application/map_providers.dart';
import 'package:rider_app/features/map/domain/map_repositories.dart';
import 'package:rider_app/features/tracking/application/tracking_controller.dart';
import 'package:rider_app/mock/mock_driver_telemetry.dart';

import '../helpers/test_helpers.dart';

class _NoLocation implements LocationService {
  @override
  Future<LocationResult> current() async =>
      const LocationResult(status: LocationStatus.denied);
}

class _Env {
  _Env(this.overrides, this.adapter);

  final List<Override> overrides;
  final ScriptedAdapter adapter;
}

Future<_Env> _env({List<Map<String, dynamic>> activeRides = const []}) async {
  final store = InMemoryTokenStore(
    StoredSession(
      token: 't',
      expiresAt: DateTime.now().add(const Duration(hours: 5)),
    ),
  );
  final adapter = ScriptedAdapter()
    ..json('GET', '/auth/me', 200, {'data': userJson()})
    ..json('GET', '/rides', 200, {
      'data': activeRides,
      'meta': {'current_page': 1, 'last_page': 1},
    })
    ..json('POST', '/fares/estimate', 200, {
      'data': {
        'breakdown': breakdownJson(),
        'pickup': null,
        'dropoff': null,
        'distance_source': 'client_supplied',
      },
    });
  final base = await baseOverrides(
    tokenStore: store,
    prefs: {'flag.onboarding_seen': true},
  );
  return _Env([
    ...base,
    locationServiceProvider.overrideWithValue(_NoLocation()),
    pollIntervalProvider.overrideWithValue(const Duration(milliseconds: 200)),
    driverTelemetryProvider.overrideWithValue(
      const MockDriverTelemetry(legSeconds: 60),
    ),
    dioProvider.overrideWith(
      (ref) => createApiClient(
        tokenStore: store,
        baseUrl: 'http://test',
        adapter: adapter,
        onUnauthorized: () =>
            ref.read(sessionControllerProvider.notifier).handleUnauthorized(),
      ),
    ),
  ], adapter);
}

Future<void> _pump(WidgetTester tester, _Env env) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: env.overrides, child: const RiderApp()),
  );
  await tester.pumpAndSettle();
}

/// Advances time without waiting for animations/timers to settle (the ride screen has a 1 s ticker).
Future<void> _advance(WidgetTester tester, {int ms = 600}) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

/// Taps a widget after scrolling it into view (the Stitch pages scroll as a whole).
Future<void> _tap(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
}

Future<void> _bookRide(
  WidgetTester tester,
  _Env env, {
  String destination = 'aker',
}) async {
  await tester.tap(find.byKey(const Key('where_to')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('dropoff_field')).last.evaluate().isEmpty
        ? find.byType(TextField).last
        : find.descendant(
            of: find.byKey(const Key('dropoff_field')),
            matching: find.byType(TextField),
          ),
    destination,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('result_aker-brygge')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('search_next')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'search -> choose ride -> real fare estimate shown for every vehicle card',
    (tester) async {
      final env = await _env();
      await _pump(tester, env);

      await _bookRide(tester, env);

      // Real POST fares/estimate with client-computed distance/duration (haversine) and coordinates.
      final req =
          env.adapter.where('POST', '/fares/estimate').single.data as Map;
      expect(req['distance_meters'], inInclusiveRange(1200, 1400));
      expect(req['duration_seconds'], greaterThan(60));
      expect((req['pickup'] as Map)['latitude'], isNotNull);
      expect(find.byKey(const Key('route_pill')), findsOneWidget);
      expect(find.textContaining('(est.)'), findsWidgets);
      expect(find.byKey(const Key('price_sedan')), findsOneWidget);
      expect(find.text('€17.44'), findsWidgets);
      expect(
        find.byKey(const Key('vehicle_note'), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mock_estimate_banner')), findsNothing);
      await _dispose(tester);
    },
  );

  testWidgets(
    'backend unreachable: estimate falls back to a clearly flagged MOCK and booking is disabled',
    (tester) async {
      final env = await _env();
      env.adapter.networkDown('POST', '/fares/estimate');
      await _pump(tester, env);
      await _bookRide(tester, env);

      expect(find.byKey(const Key('mock_estimate_banner')), findsOneWidget);
      expect(find.textContaining('MOCK estimate'), findsOneWidget);
      expect(find.text('Mock estimate'), findsWidgets);
      final cta = tester.widget<InkWell>(
        find.byKey(const Key('continue_to_payment')),
      );
      expect(
        cta.onTap,
        isNull,
        reason: 'cannot continue to booking on a mock estimate',
      );
      await _dispose(tester);
    },
  );

  testWidgets(
    'a server error (500) shows an error with retry, not a fake price',
    (tester) async {
      final env = await _env();
      env.adapter.json('POST', '/fares/estimate', 500, {'message': 'boom'});
      await _pump(tester, env);
      await _bookRide(tester, env);
      expect(find.byKey(const Key('fare_error')), findsOneWidget);
      expect(find.byKey(const Key('price_sedan')), findsNothing);
      expect(find.byKey(const Key('mock_estimate_banner')), findsNothing);
      await _dispose(tester);
    },
  );

  testWidgets(
    'confirm & pay: demo-payment labelling, cash/card choice is sent, no Vipps / add-card rows',
    (tester) async {
      final env = await _env();
      env.adapter.json('POST', '/rides', 201, {
        'data': rideJson(status: 'requested', paymentMethod: 'card'),
      });
      env.adapter.json('GET', '/rides/42', 200, {
        'data': rideJson(status: 'requested', paymentMethod: 'card'),
      });
      await _pump(tester, env);
      await _bookRide(tester, env);
      await _tap(tester, 'continue_to_payment');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('demo_payment_banner')), findsOneWidget);
      expect(find.textContaining('nothing is charged'), findsWidgets);
      expect(find.text('Vipps'), findsNothing);
      expect(find.byKey(const Key('pay_vipps')), findsNothing);
      expect(find.byKey(const Key('add_payment_method')), findsNothing);
      expect(find.textContaining('Unavailable'), findsNothing);
      await _tap(tester, 'pay_card');
      await tester.pump();
      await _tap(tester, 'request_ride');
      await _advance(tester, ms: 600);

      final body = env.adapter.where('POST', '/rides').single.data as Map;
      expect(body['payment_method'], 'card');
      expect((body['pickup'] as Map)['address'], contains('Oslo S'));
      expect((body['dropoff'] as Map)['address'], contains('Aker Brygge'));
      expect(body['distance_meters'], isA<int>());
      expect(body['duration_seconds'], isA<int>());
      expect(
        env.adapter.where('POST', '/rides').single.headers['Idempotency-Key'],
        matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')),
      );
      expect(body.containsKey('vehicle_type'), isFalse);
      await _dispose(tester);
    },
  );

  testWidgets('double-tapping Request ride sends exactly one POST /rides', (
    tester,
  ) async {
    final env = await _env();
    env.adapter.on('POST', '/rides', (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return ScriptedAdapter.jsonBody(201, {
        'data': rideJson(status: 'requested'),
      });
    });
    env.adapter.json('GET', '/rides/42', 200, {
      'data': rideJson(status: 'requested'),
    });
    await _pump(tester, env);
    await _bookRide(tester, env);
    await _tap(tester, 'continue_to_payment');
    await tester.pumpAndSettle();
    await _tap(tester, 'request_ride');
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('request_ride')),
      warnIfMissed: false,
    );
    await tester.tap(
      find.byKey(const Key('request_ride')),
      warnIfMissed: false,
    );
    await _advance(tester, ms: 1000);
    expect(env.adapter.where('POST', '/rides'), hasLength(1));
    await _dispose(tester);
  });

  testWidgets(
    '409 one-active-ride shows the conflict banner with a way to the active ride',
    (tester) async {
      final env = await _env();
      env.adapter.json('POST', '/rides', 409, {
        'message': 'You already have an active ride.',
      });
      await _pump(tester, env);
      await _bookRide(tester, env);
      await _tap(tester, 'continue_to_payment');
      await tester.pumpAndSettle();
      await _tap(tester, 'request_ride');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('active_ride_conflict')), findsOneWidget);
      expect(find.text('View active ride'), findsOneWidget);
      // The button is usable again (not stuck in a loading state).
      await tester.ensureVisible(find.byKey(const Key('request_ride')));
      await tester.pump();
      final cta = tester.widget<InkWell>(find.byKey(const Key('request_ride')));
      expect(cta.onTap, isNotNull);
      await _dispose(tester);
    },
  );

  testWidgets(
    'searching screen -> polling shows driver details once accepted (from the ride resource only)',
    (tester) async {
      final env = await _env();
      env.adapter.json('POST', '/rides', 201, {
        'data': rideJson(status: 'requested'),
      });
      var polls = 0;
      env.adapter.on('GET', '/rides/42', (_) {
        polls++;
        final status = polls < 3 ? 'offered' : 'accepted';
        return ScriptedAdapter.jsonBody(200, {
          'data': rideJson(
            status: status,
            withDriver: status == 'accepted',
            timestamps: {'accepted_at': DateTime.now().toIso8601String()},
          ),
        });
      });
      await _pump(tester, env);
      await _bookRide(tester, env);
      await _tap(tester, 'continue_to_payment');
      await tester.pumpAndSettle();
      await _tap(tester, 'request_ride');
      await _advance(tester, ms: 300);

      expect(find.byKey(const Key('searching_card')), findsOneWidget);
      expect(find.byKey(const Key('cancel_request')), findsOneWidget);
      expect(find.byKey(const Key('driver_name')), findsNothing);

      await _advance(tester, ms: 1500);
      expect(find.byKey(const Key('driver_name')), findsOneWidget);
      expect(find.text('Erik'), findsWidgets);
      expect(find.byKey(const Key('vehicle_plate')), findsOneWidget);
      expect(find.text('EL 12345'), findsOneWidget);
      expect(find.text('Toyota Camry'), findsOneWidget);
      expect(find.textContaining('Silver'), findsOneWidget);
      expect(find.byKey(const Key('status_headline')), findsOneWidget);
      // The API has no driver rating: the 4.9 line is the Stitch DEMO placeholder
      // (DemoDriverProfile) and the photo is a demo image; names, plate and car are real.
      expect(find.textContaining('4.9'), findsOneWidget);
      expect(find.text('Fluent in Norsk, Engelsk'), findsOneWidget);
      // The simulated map position is labelled.
      expect(find.text('MOCK POSITION'), findsOneWidget);
      expect(
        find.byKey(const Key('cancel_ride'), skipOffstage: false),
        findsOneWidget,
      );
      await _dispose(tester);
    },
  );

  testWidgets(
    'arrival triggers an in-app alert banner exactly when polling sees "arrived"',
    (tester) async {
      final env = await _env(
        activeRides: [rideJson(status: 'driver_en_route', withDriver: true)],
      );
      var status = 'driver_en_route';
      env.adapter.on(
        'GET',
        '/rides/42',
        (_) => ScriptedAdapter.jsonBody(200, {
          'data': rideJson(status: status, withDriver: true),
        }),
      );
      await _pump(tester, env);
      // Resume the active ride from the home card.
      expect(find.byKey(const Key('active_ride_card')), findsOneWidget);
      await tester.tap(find.byKey(const Key('active_ride_card')));
      await _advance(tester, ms: 500);
      expect(find.byKey(const Key('arrival_banner')), findsNothing);
      expect(find.text('Driver on the way'), findsWidgets);

      status = 'arrived';
      await _advance(tester, ms: 800);
      expect(find.byKey(const Key('arrival_banner')), findsOneWidget);
      expect(find.text('Your driver has arrived'), findsOneWidget);
      expect(find.byKey(const Key('eta_pill')), findsOneWidget);
      await _dispose(tester);
    },
  );

  testWidgets(
    'opening a ride that is ALREADY arrived does not fire a stale arrival alert',
    (tester) async {
      final env = await _env(
        activeRides: [rideJson(status: 'arrived', withDriver: true)],
      );
      env.adapter.json('GET', '/rides/42', 200, {
        'data': rideJson(status: 'arrived', withDriver: true),
      });
      await _pump(tester, env);
      await tester.tap(find.byKey(const Key('active_ride_card')));
      await _advance(tester, ms: 800);
      expect(find.byKey(const Key('arrival_banner')), findsNothing);
      expect(find.byKey(const Key('status_title')), findsOneWidget);
      await _dispose(tester);
    },
  );

  for (final status in [
    'accepted',
    'driver_en_route',
    'in_progress',
    'arrived',
  ]) {
    testWidgets(
      'tracking ($status): only built controls (no chat / share / SOS / edit pickup / map toggles)',
      (tester) async {
        final env = await _env(
          activeRides: [rideJson(status: status, withDriver: true)],
        );
        env.adapter.json('GET', '/rides/42', 200, {
          'data': rideJson(status: status, withDriver: true),
        });
        await _pump(tester, env);
        await tester.tap(find.byKey(const Key('active_ride_card')));
        await _advance(tester, ms: 800);
        for (final k in [
          'action_chat',
          'action_share',
          'action_safety',
          'edit_pickup',
        ]) {
          expect(find.byKey(Key(k)), findsNothing, reason: k);
        }
        for (final t in ['Chat', 'Share Trip', 'SOS Assistance', 'Edit']) {
          expect(find.text(t), findsNothing, reason: t);
        }
        expect(find.textContaining('not available'), findsNothing);
        await _dispose(tester);
      },
    );
  }

  testWidgets(
    'driver found: "Call driver" exists only with a real phone number',
    (tester) async {
      final env = await _env(
        activeRides: [rideJson(status: 'accepted', withDriver: true)],
      );
      env.adapter.json('GET', '/rides/42', 200, {
        'data': rideJson(status: 'accepted', withDriver: true),
      });
      await _pump(tester, env);
      await tester.tap(find.byKey(const Key('active_ride_card')));
      await _advance(tester, ms: 800);
      expect(find.byKey(const Key('action_call')), findsOneWidget);
      expect(find.text('Call driver'), findsOneWidget);
      await _dispose(tester);

      final env2 = await _env(
        activeRides: [rideJson(status: 'accepted', withDriver: true)],
      );
      final full = rideJson(status: 'accepted', withDriver: true);
      final Map<String, dynamic> noPhone = {
        ...full,
        'driver': {...(full['driver'] as Map<String, dynamic>), 'phone': null},
      };
      env2.adapter.json('GET', '/rides/42', 200, {'data': noPhone});
      await _pump(tester, env2);
      await tester.tap(find.byKey(const Key('active_ride_card')));
      await _advance(tester, ms: 800);
      expect(find.byKey(const Key('action_call')), findsNothing);
      await _dispose(tester);
    },
  );

  testWidgets(
    'cancel from the searching screen calls POST cancel and shows the cancelled state',
    (tester) async {
      final env = await _env(activeRides: [rideJson(status: 'requested')]);
      env.adapter.json('GET', '/rides/42', 200, {
        'data': rideJson(status: 'requested'),
      });
      env.adapter.json('POST', '/rides/42/cancel', 200, {
        'data': rideJson(status: 'cancelled', cancelReason: 'Waiting too long'),
      });
      await _pump(tester, env);
      await tester.tap(find.byKey(const Key('active_ride_card')));
      await _advance(tester, ms: 500);
      await _tap(tester, 'cancel_request');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('reason_Waiting too long')));
      await tester.pump();
      await _tap(tester, 'confirm_cancel');
      await _advance(tester, ms: 600);
      expect(
        (env.adapter.where('POST', '/rides/42/cancel').single.data
            as Map)['reason'],
        'Waiting too long',
      );
      expect(find.byKey(const Key('cancelled_title')), findsOneWidget);
      expect(find.textContaining('Waiting too long'), findsWidgets);
      await _dispose(tester);
    },
  );

  testWidgets(
    'rider2-style open request is resumable from the home screen after restart',
    (tester) async {
      final env = await _env(activeRides: [rideJson(status: 'requested')]);
      await _pump(tester, env);
      expect(find.byKey(const Key('active_ride_card')), findsOneWidget);
      expect(find.textContaining('Ride in progress'), findsOneWidget);
      await _dispose(tester);
    },
  );

  testWidgets(
    'when polling sees "completed" the rider is taken to the trip-complete screen with the real fare',
    (tester) async {
      final env = await _env(
        activeRides: [rideJson(status: 'in_progress', withDriver: true)],
      );
      var status = 'in_progress';
      env.adapter.on(
        'GET',
        '/rides/42',
        (_) => ScriptedAdapter.jsonBody(200, {
          'data': rideJson(
            status: status,
            withDriver: true,
            finalMinor: status == 'completed' ? 1744 : null,
          ),
        }),
      );
      await _pump(tester, env);
      await tester.tap(find.byKey(const Key('active_ride_card')));
      await _advance(tester, ms: 500);
      expect(find.text('Trip in progress'), findsWidgets);
      status = 'completed';
      await _advance(tester, ms: 2000);
      expect(find.byKey(const Key('complete_title')), findsOneWidget);
      expect(find.text('Trip Completed'), findsWidgets);
      await _dispose(tester);
    },
  );

  testWidgets(
    'ride selection: vehicle cards share one real fare; Change opens the payment picker; layers opens Available Fleets',
    (tester) async {
      final env = await _env();
      await _pump(tester, env);
      await _bookRide(tester, env);
      // Three cards, one real price each, ETAs from the mock nearby cars.
      for (final k in ['sedan', 'estate', 'van']) {
        expect(find.byKey(Key('vehicle_$k')), findsOneWidget);
        expect(find.byKey(Key('price_$k')), findsOneWidget);
      }
      expect(find.text('Select your ride'), findsOneWidget);
      // Default payment is cash; the picker switches to card (demo).
      expect(find.text('Cash to driver'), findsOneWidget);
      await _tap(tester, 'change_payment');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pay_option_card')));
      await tester.pumpAndSettle();
      expect(find.text('Card'), findsOneWidget);
      // Choosing the van updates the CTA.
      await _tap(tester, 'vehicle_van');
      await tester.pump();
      expect(find.textContaining('Request XL Van'), findsOneWidget);
      // The layers button opens the alternate "Available Fleets" layout with the same plan.
      await tester.ensureVisible(find.byKey(const Key('layers_button')));
      await tester.tap(find.byKey(const Key('layers_button')));
      await tester.pumpAndSettle();
      expect(find.text('Available Fleets'), findsOneWidget);
      expect(find.textContaining('Request XL Van'), findsOneWidget);
      await _dispose(tester);
    },
  );
}
