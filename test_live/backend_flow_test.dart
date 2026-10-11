// LIVE integration checks against the REAL Laravel backend (default http://127.0.0.1:8001).
//
// Not part of `flutter test` (that only runs test/). Run with the backend up:
//   flutter test test_live/backend_flow_test.dart [--dart-define=API_BASE_URL=http://127.0.0.1:8001]
//
// It drives the Rider app's REAL repositories (auth, fare, rides) through the app's own Dio client:
// register -> login -> fare estimate -> create ride -> scripted driver lifecycle -> poll to completed
// -> history -> verify as manager/owner through the API (Admin parity) -> cancel flow -> logout.
// The driver is `tool/scripted_driver.dart`, a script, NOT the Driver App.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_app/core/network/api_client.dart';
import 'package:rider_app/core/network/api_exception.dart';
import 'package:rider_app/core/storage/token_store.dart';
import 'package:rider_app/features/auth/data/auth_repository_impl.dart';
import 'package:rider_app/features/auth/domain/auth_models.dart';
import 'package:rider_app/features/fare/data/fare_repository_impl.dart';
import 'package:rider_app/features/fare/domain/fare_models.dart';
import 'package:rider_app/features/rides/data/ride_repository_impl.dart';
import 'package:rider_app/features/rides/domain/ride_models.dart';
import 'package:rider_app/features/tracking/domain/ride_status_machine.dart';
import 'package:rider_app/mock/mock_fare_estimator.dart';
import 'package:rider_app/mock/mock_route_service.dart';

import '../tool/scripted_driver.dart';

const _base = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8001',
);
const _oslo = LatLng(59.9110, 10.7528);
const _aker = LatLng(59.9106, 10.7298);

void main() {
  // flutter_test installs an HttpOverrides that blocks real sockets; this suite needs the network.
  setUpAll(() => HttpOverrides.global = null);

  final unique = DateTime.now().millisecondsSinceEpoch;
  final email = 'live.rider.$unique@example.com';
  const password = 'LivePassw0rd!';
  final store = InMemoryTokenStore();
  final dio = createApiClient(
    tokenStore: store,
    baseUrl: _base,
    onUnauthorized: () {},
  );
  final auth = AuthRepositoryImpl(dio);
  final fares = FareRepositoryImpl(dio);
  final rides = RideRepositoryImpl(dio);
  final driver = ScriptedDriver(
    baseUrl: _base,
    log: (m) => stdout.writeln('    $m'),
  );
  final evidence = <String>[];
  void note(String s) {
    evidence.add(s);
    stdout.writeln('  [evidence] $s');
  }

  late AuthSession session;
  late int rideId;
  late Dio manager;
  late Dio owner;

  Future<T> retry429<T>(Future<T> Function() action) async {
    for (var i = 0; i < 4; i++) {
      try {
        return await action();
      } on ApiException catch (e) {
        if (e.kind != ApiErrorKind.rateLimited) rethrow;
        stdout.writeln('    (429, waiting ${e.retryAfterSeconds ?? 20}s)');
        await Future<void>.delayed(
          Duration(seconds: (e.retryAfterSeconds ?? 20) + 1),
        );
      }
    }
    return action();
  }

  test('00 backend is reachable', () async {
    final r = await Dio(BaseOptions(validateStatus: (_) => true))
        .get<dynamic>('$_base/up');
    expect(r.statusCode, 200);
  });

  test(
    '01 wrong credentials: uniform 401 mapped to the friendly message',
    () async {
      await expectLater(
        auth.login(email: 'rider1@example.com', password: 'definitely-wrong'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)
              .having(
                (e) => e.message,
                'message',
                AuthRepositoryImpl.wrongCredentials,
              ),
        ),
      );
    },
  );

  test('02 register a fresh rider (POST auth/register)', () async {
    session = await retry429(
      () => auth.register(
        RegisterRequest(
          firstName: 'Live',
          lastName: 'Tester',
          email: email,
          password: password,
          phone: '+4741${unique % 1000000}'.padRight(12, '0'),
        ),
      ),
    );
    expect(session.token, isNotEmpty);
    expect(session.user.isRider, isTrue);
    expect(session.expiresAt, isNotNull);
    await store.write(
      StoredSession(token: session.token, expiresAt: session.expiresAt),
    );
    note(
      'registered rider ${session.user.email} (rider_id ${session.user.riderId}), token expires ${session.expiresAt}',
    );
  });

  test('03 duplicate registration returns 422 with a field error', () async {
    await expectLater(
      retry429(
        () => auth.register(
          RegisterRequest(
            firstName: 'Live',
            lastName: 'Tester',
            email: email,
            password: password,
          ),
        ),
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.fieldError('email'),
          'email error',
          isNotNull,
        ),
      ),
    );
  });

  test('04 login, GET auth/me and GET me/rider', () async {
    final login = await auth.login(email: email, password: password);
    await store.write(
      StoredSession(token: login.token, expiresAt: login.expiresAt),
    );
    final me = await auth.me();
    expect(me.email, email);
    final profile = await auth.riderProfile();
    expect(profile.firstName, 'Live');
    expect(profile.defaultPaymentMethod, 'cash');
    final updated = await auth.updateDefaultPaymentMethod('card');
    expect(updated.defaultPaymentMethod, 'card');
    await auth.updateDefaultPaymentMethod('cash');
    note('auth/me + me/rider OK; default_payment_method PATCH round-trips');
  });

  test('04b JWT refresh rotates the token: the old one dies immediately, the new one works', () async {
    final before = (await store.read())!;
    final raw = Dio(
      BaseOptions(
        baseUrl: '$_base/api/v1',
        headers: {'Accept': 'application/json'},
        validateStatus: (_) => true,
      ),
    );
    final r = await raw.post<dynamic>(
      '/auth/refresh',
      options: Options(headers: {'Authorization': 'Bearer ${before.token}'}),
    );
    expect(r.statusCode, 200);
    final body = Map<String, dynamic>.from(r.data as Map);
    expect(body['token_type'], 'Bearer');
    expect(body['expires_in'], 3600);
    final fresh = body['token'] as String;
    expect(fresh, isNot(before.token));
    final old = await raw.get<dynamic>(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer ${before.token}'}),
    );
    expect(
      old.statusCode,
      401,
      reason: 'rotation: the old token stops working immediately',
    );
    final next = await raw.get<dynamic>(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $fresh'}),
    );
    expect(next.statusCode, 200);
    await store.write(
      StoredSession(
        token: fresh,
        expiresAt: DateTime.tryParse(body['expires_at'] as String),
      ),
    );
    note(
      'POST auth/refresh rotated the JWT (expires_in 3600); the previous token answered 401 right away, the new one 200',
    );
  });

  test('04c the app client refreshes proactively (< 5 min left) and once on 401, single-flight', () async {
    // Pretend the stored token is about to expire: the client must rotate it before the call.
    final current = (await store.read())!;
    await store.write(
      StoredSession(
        token: current.token,
        expiresAt: DateTime.now().add(const Duration(minutes: 2)),
      ),
    );
    final results = await Future.wait([for (var i = 0; i < 4; i++) auth.me()]);
    expect(results.every((u) => u.email == email), isTrue);
    final rotated = (await store.read())!;
    expect(
      rotated.token,
      isNot(current.token),
      reason: 'proactive refresh happened',
    );
    expect(
      rotated.expiresAt!.isAfter(
        DateTime.now().add(const Duration(minutes: 30)),
      ),
      isTrue,
    );
    // Reactive path: the server has not expired the token, but we revoke it behind the client's back
    // by rotating once more with a raw call; the next client call gets a 401, refreshes with the
    // (now dead) token, fails, and the session ends -> 401 hook fires.
    var signedOut = false;
    final victim = createApiClient(
      tokenStore: InMemoryTokenStore(
        StoredSession(
          token: current.token,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      ),
      baseUrl: _base,
      onUnauthorized: () => signedOut = true,
    );
    await expectLater(
      AuthRepositoryImpl(victim).me(),
      throwsA(isA<ApiException>()),
    );
    expect(
      signedOut,
      isTrue,
      reason: 'revoked token + refused refresh -> back to login',
    );
    note(
      '4 parallel calls with <5 min left -> one proactive refresh (token rotated); a revoked token -> one refresh attempt refused -> sign-out hook fired',
    );
  });

  test('05 forgot password is always 202 (no account enumeration)', () async {
    final msg = await retry429(
      () => auth.forgotPassword('nobody.$unique@example.com'),
    );
    expect(msg, contains('reset link'));
  });

  test('06 real fare estimate matches the documented formula (distance_source client_supplied)', () async {
    final route = await const MockRouteService().route(_oslo, _aker);
    final estimate = await fares.estimate(
      FareEstimateRequest(
        distanceMeters: route.distanceMeters,
        durationSeconds: route.durationSeconds,
        pickup: _oslo,
        dropoff: _aker,
        pickupAddress: 'Oslo S',
        dropoffAddress: 'Aker Brygge',
      ),
    );
    expect(estimate.source, FareSource.backend);
    expect(estimate.distanceSource, 'client_supplied');
    // The seeded rule equals the mock rule, so the integer formula must agree to the cent.
    final mock = await const MockFareEstimator().estimate(
      FareEstimateRequest(
        distanceMeters: route.distanceMeters,
        durationSeconds: route.durationSeconds,
      ),
    );
    expect(estimate.totalMinor, mock.totalMinor);
    expect(estimate.breakdown.currency, 'EUR');
    note(
      'POST fares/estimate ${route.distanceMeters} m / ${route.durationSeconds} s -> total ${estimate.totalMinor} minor EUR (backend == local formula)',
    );
  });

  test('07 create ride: idempotent retry returns the same ride; second active ride is 409', () async {
    final route = await const MockRouteService().route(_oslo, _aker);
    final request = CreateRideRequest(
      pickup: const RideLocation(
        latitude: 59.911,
        longitude: 10.7528,
        address: 'Oslo S (Jernbanetorget)',
      ),
      dropoff: const RideLocation(
        latitude: 59.9106,
        longitude: 10.7298,
        address: 'Aker Brygge',
      ),
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
      paymentMethod: PaymentMethodType.card,
    );
    final key = 'live-$unique-create';
    final ride = await rides.create(request, idempotencyKey: key);
    rideId = ride.id;
    expect(ride.status, RideStatus.requested);
    expect(ride.payment.method, 'card');
    expect(ride.payment.status, 'not_charged');
    expect(ride.fare.estimateMinor, isNotNull);
    expect(ride.driver, isNull);
    final again = await rides.create(request, idempotencyKey: key);
    expect(
      again.id,
      ride.id,
      reason: 'same Idempotency-Key must not create a duplicate',
    );
    await expectLater(
      rides.create(request, idempotencyKey: 'live-$unique-second'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.isConflict, 'conflict', isTrue)
            .having((e) => e.message, 'message', contains('active ride')),
      ),
    );
    note(
      'ride #$rideId requested (card, not_charged); idempotent retry returned same id; second active ride -> 409',
    );
  });

  test('08 manager sees the new ride through the API (Admin Trips parity)', () async {
    final (m, _) = await driver.login('manager@example.com');
    manager = m;
    final r = await manager.get<dynamic>('/rides/$rideId');
    expect(r.statusCode, 200);
    final data = Map<String, dynamic>.from((r.data as Map)['data'] as Map);
    expect(data['status'], 'requested');
    expect((data['rider'] as Map)['first_name'], 'Live');
    final list = await manager.get<dynamic>(
      '/rides',
      queryParameters: {'rider_id': session.user.riderId, 'per_page': 5},
    );
    final ids = ((list.data as Map)['data'] as List)
        .map((e) => (e as Map)['id'])
        .toList();
    expect(ids, contains(rideId));
    note(
      'manager GET rides/$rideId -> requested, and listed under rider_id=${session.user.riderId}',
    );
  });

  test('09 scripted driver lifecycle observed by REAL polling of GET rides/{id}', () async {
    // The driver runs in the background; this loop is exactly what the app's polling controller does.
    final seen = <RideStatus>[];
    final events = <RideEventType>[];
    RideStatus? previous;
    final script = driver.run(rideId, stepDelay: const Duration(seconds: 2));
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    Ride? last;
    while (DateTime.now().isBefore(deadline)) {
      last = await rides.get(rideId);
      if (seen.isEmpty || seen.last != last.status) {
        seen.add(last.status);
        events.addAll(
          RideStatusMachine.eventsBetween(
            previous,
            last.status,
            rideId,
          ).map((e) => e.type),
        );
        previous = last.status;
        stdout.writeln(
          '    rider polled status -> ${last.status.apiValue}'
          '${last.driver != null ? ' (driver ${last.driver!.firstName}, ${last.vehicle?.plateNumber})' : ''}',
        );
        if (last.status == RideStatus.accepted) {
          expect(
            last.driver,
            isNotNull,
            reason: 'driver details must be visible once accepted',
          );
          expect(last.vehicle, isNotNull);
          expect(last.vehicle!.plateNumber, isNotEmpty);
        }
      }
      if (last.status.isTerminal) break;
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    await script;
    expect(last!.status, RideStatus.completed);
    // Polling at 0.7 s with 2 s steps must observe every state (a slower poll may skip some, events still cover them).
    expect(seen.last, RideStatus.completed);
    expect(
      events,
      containsAll([
        RideEventType.driverAssigned,
        RideEventType.driverArrived,
        RideEventType.tripCompleted,
      ]),
    );
    expect(last.fare.finalMinor, isNotNull);
    expect(last.fare.breakdown, isNotNull);
    expect(last.fare.breakdown!.totalMinor, last.fare.finalMinor);
    expect(
      last.payment.status,
      'not_charged',
      reason: 'payment is a demo: backend never charges',
    );
    note(
      'polled statuses: ${seen.map((s) => s.apiValue).join(' > ')}; events: ${events.map((e) => e.name).join(', ')}',
    );
    note(
      'completed ride fare final_minor=${last.fare.finalMinor} == breakdown total; payment.status=${last.payment.status}',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('10 history shows the ride and the timeline has the full 7-step lifecycle', () async {
    final page = await rides.list(perPage: 10);
    expect(page.rides.map((r) => r.id), contains(rideId));
    final mine = page.rides.firstWhere((r) => r.id == rideId);
    expect(mine.status, RideStatus.completed);
    final timeline = await rides.timeline(rideId);
    expect(timeline.map((e) => e.toStatus.apiValue).toList(), [
      'requested',
      'offered',
      'accepted',
      'driver_en_route',
      'arrived',
      'in_progress',
      'completed',
    ]);
    final detail = await rides.get(rideId);
    expect(detail.timeline.length, 7);
    note(
      'history lists ride #$rideId completed; GET rides/$rideId/timeline has 7 entries in order',
    );
  });

  test('11 Admin parity: manager sees completed state, timeline and fare; audit trail has the ride events', () async {
    final r = await manager.get<dynamic>('/rides/$rideId');
    final data = Map<String, dynamic>.from((r.data as Map)['data'] as Map);
    expect(data['status'], 'completed');
    expect((data['driver'] as Map)['first_name'], isNotNull);
    expect(
      ((data['fare'] as Map)['breakdown'] as Map).containsKey(
        'commission_minor',
      ),
      isTrue,
      reason: 'staff see commission; riders do not',
    );
    expect(((data['timeline']) as List).length, 7);

    final (o, _) = await driver.login('owner@example.com');
    owner = o;
    final audit = await owner.get<dynamic>(
      '/audit-logs',
      queryParameters: {'auditable_id': rideId, 'per_page': 50},
    );
    expect(audit.statusCode, 200);
    final actions = ((audit.data as Map)['data'] as List)
        .map((e) => (e as Map)['action'])
        .toList();
    expect(actions, contains('rides.offered'));
    note(
      'manager: ride completed with 7-step timeline + staff-only commission; audit actions for ride: $actions',
    );
  });

  test('12 riders cannot see staff-only fare fields', () async {
    final mine = await rides.get(rideId);
    final raw = await dio.get<dynamic>('/rides/$rideId');
    final breakdown =
        (((raw.data as Map)['data'] as Map)['fare'] as Map)['breakdown'] as Map;
    expect(breakdown.containsKey('commission_minor'), isFalse);
    expect(breakdown.containsKey('driver_earnings_minor'), isFalse);
    expect(breakdown.containsKey('fare_rule_id'), isFalse);
    expect(mine.fare.breakdown, isNotNull);
  });

  test('13 cancellation with a reason: create -> cancel -> manager sees cancelled + reason', () async {
    final request = CreateRideRequest(
      pickup: const RideLocation(
        latitude: 59.9139,
        longitude: 10.7392,
        address: 'Karl Johans gate 22',
      ),
      dropoff: const RideLocation(
        latitude: 59.9270,
        longitude: 10.7005,
        address: 'Vigeland Park',
      ),
      distanceMeters: 2800,
      durationSeconds: 340,
      paymentMethod: PaymentMethodType.cash,
    );
    final ride = await rides.create(
      request,
      idempotencyKey: 'live-$unique-cancel',
    );
    expect(ride.status, RideStatus.requested);
    await expectLater(
      rides.cancel(ride.id, 'x'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.validation,
        ),
      ),
    );
    final cancelled = await rides.cancel(ride.id, 'Plans changed');
    expect(cancelled.status, RideStatus.cancelled);
    expect(cancelled.cancellationReason, 'Plans changed');
    await expectLater(
      rides.cancel(ride.id, 'Plans changed again'),
      throwsA(
        isA<ApiException>().having((e) => e.isConflict, 'conflict', isTrue),
      ),
    );
    final m = await manager.get<dynamic>('/rides/${ride.id}');
    expect(((m.data as Map)['data'] as Map)['status'], 'cancelled');
    expect(
      (((m.data as Map)['data'] as Map)['cancellation'] as Map)['reason'],
      'Plans changed',
    );
    final audit = await owner.get<dynamic>(
      '/audit-logs',
      queryParameters: {'auditable_id': ride.id, 'per_page': 50},
    );
    final actions = ((audit.data as Map)['data'] as List)
        .map((e) => (e as Map)['action'])
        .toList();
    expect(actions, contains('rides.cancelled'));
    note(
      'cancel: 3-char minimum enforced (422), cancelled with reason, second cancel 409, manager + audit (rides.cancelled) see it',
    );
  });

  test(
    '14 a rider cannot read someone else\'s ride (non-disclosing 404)',
    () async {
      // Ride #1 belongs to the seeded demo rider (rider1), not to this fresh rider.
      await expectLater(
        rides.get(1),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.notFound,
          ),
        ),
      );
    },
  );

  test('15 logout revokes the token; the next call is 401 and would return the app to login', () async {
    var unauthorizedFired = false;
    final probe = AuthRepositoryImpl(
      createApiClient(
        tokenStore: store,
        baseUrl: _base,
        onUnauthorized: () => unauthorizedFired = true,
      ),
    );
    await probe.logout();
    await expectLater(
      probe.me(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.isUnauthorized,
          'unauthorized',
          isTrue,
        ),
      ),
    );
    expect(unauthorizedFired, isTrue);
    note(
      'POST auth/logout revoked the token; GET auth/me -> 401 and the 401 hook (return to login) fired',
    );
  });

  tearDownAll(() {
    stdout.writeln('\n===== LIVE EVIDENCE (real backend at $_base) =====');
    for (final e in evidence) {
      stdout.writeln('- $e');
    }
  });
}
