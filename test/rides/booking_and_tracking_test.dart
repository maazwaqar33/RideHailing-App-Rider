import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rider_app/core/network/api_exception.dart';
import 'package:rider_app/features/booking/application/booking_controller.dart';
import 'package:rider_app/features/rides/application/ride_providers.dart';
import 'package:rider_app/features/rides/domain/ride_models.dart';
import 'package:rider_app/features/rides/domain/ride_repository.dart';
import 'package:rider_app/features/tracking/application/tracking_controller.dart';
import 'package:rider_app/features/tracking/domain/ride_status_machine.dart';
import 'package:rider_app/features/tracking/presentation/cancel_ride_sheet.dart';

import '../helpers/test_helpers.dart';

class MockRideRepo extends Mock implements RideRepository {}

class FakeCreateRequest extends Fake implements CreateRideRequest {}

CreateRideRequest _request({int distance = 4200}) => CreateRideRequest(
  pickup: const RideLocation(
    latitude: 59.911,
    longitude: 10.7528,
    address: 'Oslo S',
  ),
  dropoff: const RideLocation(
    latitude: 59.9106,
    longitude: 10.7298,
    address: 'Aker Brygge',
  ),
  distanceMeters: distance,
  durationSeconds: 600,
  paymentMethod: PaymentMethodType.cash,
);

ProviderContainer _container(
  MockRideRepo repo, {
  Duration poll = const Duration(milliseconds: 10),
}) {
  final c = ProviderContainer(
    overrides: [
      rideRepositoryProvider.overrideWithValue(repo),
      pollIntervalProvider.overrideWithValue(poll),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCreateRequest());
  });

  group('booking: duplicate prevention and idempotency', () {
    test(
      'taps while a request is in flight are ignored (one POST only)',
      () async {
        final repo = MockRideRepo();
        final gate = Completer<Ride>();
        when(
          () =>
              repo.create(any(), idempotencyKey: any(named: 'idempotencyKey')),
        ).thenAnswer((_) => gate.future);
        final c = _container(repo);
        final n = c.read(bookingControllerProvider.notifier);

        final first = n.submit(_request());
        final second = n.submit(_request());
        final third = n.submit(_request());
        expect(c.read(bookingControllerProvider).isSubmitting, isTrue);

        gate.complete(sampleRide());
        expect(await first, isNotNull);
        expect(await second, isNull);
        expect(await third, isNull);
        verify(
          () =>
              repo.create(any(), idempotencyKey: any(named: 'idempotencyKey')),
        ).called(1);
        expect(c.read(bookingControllerProvider).status, BookingStatus.created);
      },
    );

    test('retrying the same request reuses the Idempotency-Key; a changed request gets a new one', () async {
      final repo = MockRideRepo();
      final keys = <String>[];
      var calls = 0;
      when(
        () => repo.create(any(), idempotencyKey: any(named: 'idempotencyKey')),
      ).thenAnswer((inv) async {
        keys.add(inv.namedArguments[#idempotencyKey] as String);
        calls++;
        if (calls == 1) {
          throw const ApiException(kind: ApiErrorKind.network, message: 'down');
        }
        return sampleRide();
      });
      final c = _container(repo);
      final n = c.read(bookingControllerProvider.notifier);

      expect(await n.submit(_request()), isNull);
      expect(c.read(bookingControllerProvider).status, BookingStatus.failed);
      expect(await n.submit(_request()), isNotNull);
      expect(
        keys[0],
        keys[1],
        reason: 'same body after a network failure must reuse the key',
      );
      expect(
        keys[0],
        matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')),
        reason: 'must satisfy the backend key pattern',
      );

      n.reset();
      await n.submit(_request(distance: 5000));
      expect(keys[2], isNot(keys[0]));
    });

    test('409 one-active-ride is surfaced as a conflict', () async {
      final repo = MockRideRepo();
      when(
        () => repo.create(any(), idempotencyKey: any(named: 'idempotencyKey')),
      ).thenThrow(
        const ApiException(
          kind: ApiErrorKind.conflict,
          statusCode: 409,
          message: 'You already have an active ride.',
        ),
      );
      final c = _container(repo);
      final ride = await c
          .read(bookingControllerProvider.notifier)
          .submit(_request());
      expect(ride, isNull);
      final s = c.read(bookingControllerProvider);
      expect(s.hasActiveRideConflict, isTrue);
      expect(s.error!.message, 'You already have an active ride.');
      expect(
        s.isSubmitting,
        isFalse,
        reason: 'button must be usable again after a failure',
      );
    });

    test(
      'the request body carries payment_method and no vehicle type / rider_id',
      () {
        final json = _request().toJson();
        expect(json['payment_method'], 'cash');
        expect(
          json.keys,
          containsAll([
            'pickup',
            'dropoff',
            'distance_meters',
            'duration_seconds',
          ]),
        );
        expect(json.containsKey('vehicle_type'), isFalse);
        expect(json.containsKey('rider_id'), isFalse);
      },
    );
  });

  group('status state machine', () {
    test('first fetch never emits events (opening an arrived ride must not re-alert)', () {
      expect(
        RideStatusMachine.eventsBetween(null, RideStatus.arrived, 1),
        isEmpty,
      );
    });

    test('forward transitions emit milestones', () {
      List<RideEventType> ev(RideStatus a, RideStatus b) =>
          RideStatusMachine.eventsBetween(a, b, 1).map((e) => e.type).toList();
      expect(ev(RideStatus.requested, RideStatus.offered), isEmpty);
      expect(ev(RideStatus.offered, RideStatus.accepted), [
        RideEventType.driverAssigned,
      ]);
      expect(ev(RideStatus.accepted, RideStatus.driverEnRoute), [
        RideEventType.driverEnRoute,
      ]);
      expect(ev(RideStatus.driverEnRoute, RideStatus.arrived), [
        RideEventType.driverArrived,
      ]);
      expect(ev(RideStatus.arrived, RideStatus.inProgress), [
        RideEventType.tripStarted,
      ]);
      expect(ev(RideStatus.inProgress, RideStatus.completed), [
        RideEventType.tripCompleted,
      ]);
    });

    test('a poll that skips states still reports every milestone in order', () {
      final ev = RideStatusMachine.eventsBetween(
        RideStatus.offered,
        RideStatus.arrived,
        1,
      ).map((e) => e.type).toList();
      expect(ev, [
        RideEventType.driverAssigned,
        RideEventType.driverEnRoute,
        RideEventType.driverArrived,
      ]);
    });

    test('cancellation emits a single event from any state', () {
      expect(
        RideStatusMachine.eventsBetween(
          RideStatus.accepted,
          RideStatus.cancelled,
          1,
        ).single.type,
        RideEventType.rideCancelled,
      );
    });

    test('no events when status unchanged or unknown', () {
      expect(
        RideStatusMachine.eventsBetween(
          RideStatus.arrived,
          RideStatus.arrived,
          1,
        ),
        isEmpty,
      );
      expect(
        RideStatusMachine.eventsBetween(
          RideStatus.arrived,
          RideStatus.unknown,
          1,
        ),
        isEmpty,
      );
    });

    test('stage mapping and cancel eligibility follow the backend rules', () {
      expect(
        RideStatusMachine.stageOf(RideStatus.requested),
        TrackingStage.searching,
      );
      expect(
        RideStatusMachine.stageOf(RideStatus.offered),
        TrackingStage.searching,
      );
      expect(
        RideStatusMachine.stageOf(RideStatus.driverEnRoute),
        TrackingStage.driverOnTheWay,
      );
      expect(
        RideStatusMachine.stageOf(RideStatus.arrived),
        TrackingStage.driverArrived,
      );
      expect(
        RideStatusMachine.stageOf(RideStatus.inProgress),
        TrackingStage.inTrip,
      );
      expect(RideStatus.arrived.canRiderCancel, isTrue);
      expect(
        RideStatus.inProgress.canRiderCancel,
        isFalse,
        reason: 'the API has no in_progress -> cancelled transition',
      );
      expect(RideStatus.completed.canRiderCancel, isFalse);
      expect(RideStatus.parse('weird'), RideStatus.unknown);
    });

    test('polling stops only at terminal states', () {
      expect(RideStatusMachine.shouldKeepPolling(RideStatus.requested), isTrue);
      expect(
        RideStatusMachine.shouldKeepPolling(RideStatus.inProgress),
        isTrue,
      );
      expect(
        RideStatusMachine.shouldKeepPolling(RideStatus.completed),
        isFalse,
      );
      expect(
        RideStatusMachine.shouldKeepPolling(RideStatus.cancelled),
        isFalse,
      );
    });
  });

  group('polling controller', () {
    test(
      'polls until completed, then stops; arrival event is emitted once',
      () async {
        final repo = MockRideRepo();
        final script = [
          'requested',
          'offered',
          'accepted',
          'driver_en_route',
          'arrived',
          'in_progress',
          'completed',
        ];
        var i = 0;
        when(() => repo.get(42)).thenAnswer(
          (_) async => Ride.fromJson(
            rideJson(
              status: script[i < script.length ? i++ : script.length - 1],
              withDriver: true,
            ),
          ),
        );
        final c = _container(repo);
        final seen = <RideEventType>[];
        final sub = c.listen(rideTrackingProvider(42), (prev, next) {
          if (next.events != prev?.events) {
            seen.addAll(next.events.map((e) => e.type));
          }
        });
        addTearDown(sub.close);

        await _until(() => c.read(rideTrackingProvider(42)).stopped);
        final s = c.read(rideTrackingProvider(42));
        expect(s.ride!.status, RideStatus.completed);
        expect(
          seen.where((t) => t == RideEventType.driverArrived),
          hasLength(1),
        );
        expect(
          seen,
          containsAllInOrder([
            RideEventType.driverAssigned,
            RideEventType.driverEnRoute,
            RideEventType.driverArrived,
            RideEventType.tripStarted,
            RideEventType.tripCompleted,
          ]),
        );

        final callsAtStop = i;
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(
          i,
          callsAtStop,
          reason: 'no further requests after a terminal status',
        );
      },
    );

    test('network errors keep the last ride, back off, then recover', () async {
      final repo = MockRideRepo();
      var n = 0;
      when(() => repo.get(42)).thenAnswer((_) async {
        n++;
        if (n == 2 || n == 3) {
          throw const ApiException(
            kind: ApiErrorKind.network,
            message: 'offline',
          );
        }
        return Ride.fromJson(
          rideJson(status: n < 5 ? 'accepted' : 'completed', withDriver: true),
        );
      });
      final c = _container(repo);
      final errors = <int>[];
      final sub = c.listen(rideTrackingProvider(42), (prev, next) {
        if (next.error != null) errors.add(next.failureCount);
      });
      addTearDown(sub.close);

      await _until(() => c.read(rideTrackingProvider(42)).stopped);
      expect(errors, containsAll([1, 2]));
      final s = c.read(rideTrackingProvider(42));
      expect(s.ride!.status, RideStatus.completed);
      expect(s.error, isNull);
      expect(s.failureCount, 0);
    });

    test(
      '401 stops polling (session handling takes over); 404 stops too',
      () async {
        final repo = MockRideRepo();
        when(() => repo.get(42)).thenThrow(
          const ApiException(
            kind: ApiErrorKind.unauthorized,
            statusCode: 401,
            message: 'expired',
          ),
        );
        final c = _container(repo);
        final sub = c.listen(rideTrackingProvider(42), (_, _) {});
        addTearDown(sub.close);
        await _until(() => c.read(rideTrackingProvider(42)).stopped);
        verify(() => repo.get(42)).called(1);
      },
    );

    test('never overlaps requests', () async {
      final repo = MockRideRepo();
      var inFlight = 0;
      var maxInFlight = 0;
      var calls = 0;
      when(() => repo.get(42)).thenAnswer((_) async {
        inFlight++;
        maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
        await Future<void>.delayed(const Duration(milliseconds: 25));
        inFlight--;
        calls++;
        return Ride.fromJson(
          rideJson(
            status: calls > 3 ? 'completed' : 'accepted',
            withDriver: true,
          ),
        );
      });
      final c = _container(repo, poll: const Duration(milliseconds: 1));
      final sub = c.listen(rideTrackingProvider(42), (_, _) {});
      addTearDown(sub.close);
      final ctl = c.read(rideTrackingProvider(42).notifier);
      unawaited(ctl.poll());
      unawaited(ctl.poll());
      await _until(() => c.read(rideTrackingProvider(42)).stopped);
      expect(maxInFlight, 1);
    });
  });

  group('cancellation', () {
    Future<void> pump(
      WidgetTester tester,
      MockRideRepo repo, {
      void Function(CancelOutcome?)? onResult,
    }) async {
      await tester.pumpWidget(
        wrapApp(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final r = await showCancelRideSheet(
                      context,
                      ride: sampleRide(status: 'accepted', withDriver: true),
                    );
                    onResult?.call(r);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          overrides: [
            ...await baseOverrides(),
            rideRepositoryProvider.overrideWithValue(repo),
          ],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('requires a reason, then calls POST cancel with it', (
      tester,
    ) async {
      final repo = MockRideRepo();
      when(() => repo.cancel(42, 'Waiting too long')).thenAnswer(
        (_) async => Ride.fromJson(
          rideJson(status: 'cancelled', cancelReason: 'Waiting too long'),
        ),
      );
      CancelOutcome? result;
      await pump(tester, repo, onResult: (r) => result = r);

      // Confirm is disabled until a reason is selected.
      final confirmFinder = find.byKey(const Key('confirm_cancel'));
      await tester.tap(confirmFinder, warnIfMissed: false);
      verifyNever(() => repo.cancel(any(), any()));

      await tester.tap(find.byKey(const Key('reason_Waiting too long')));
      await tester.pump();
      await tester.tap(confirmFinder);
      await tester.pumpAndSettle();

      verify(() => repo.cancel(42, 'Waiting too long')).called(1);
      expect(result!.ride!.status, RideStatus.cancelled);
    });

    testWidgets('"Other" needs at least 3 characters of free text', (
      tester,
    ) async {
      final repo = MockRideRepo();
      when(
        () => repo.cancel(42, 'Car broke down'),
      ).thenAnswer((_) async => Ride.fromJson(rideJson(status: 'cancelled')));
      await pump(tester, repo);
      await tester.tap(find.byKey(const Key('reason_Other')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('reason_other_field')), 'ab');
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('confirm_cancel')),
        warnIfMissed: false,
      );
      verifyNever(() => repo.cancel(any(), any()));
      await tester.enterText(
        find.byKey(const Key('reason_other_field')),
        'Car broke down',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirm_cancel')));
      await tester.pumpAndSettle();
      verify(() => repo.cancel(42, 'Car broke down')).called(1);
    });

    testWidgets('double tap on confirm sends a single cancel request', (
      tester,
    ) async {
      final repo = MockRideRepo();
      final gate = Completer<Ride>();
      when(() => repo.cancel(42, 'Plans changed'))
          .thenAnswer((_) => gate.future);
      await pump(tester, repo);
      await tester.tap(find.byKey(const Key('reason_Plans changed')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirm_cancel')));
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('confirm_cancel')),
        warnIfMissed: false,
      );
      await tester.pump();
      gate.complete(Ride.fromJson(rideJson(status: 'cancelled')));
      await tester.pumpAndSettle();
      verify(() => repo.cancel(42, 'Plans changed')).called(1);
    });

    testWidgets(
      'a 409 (ride already moved on) closes the sheet with the conflict',
      (tester) async {
        final repo = MockRideRepo();
        when(() => repo.cancel(42, 'Plans changed')).thenThrow(
          const ApiException(
            kind: ApiErrorKind.conflict,
            statusCode: 409,
            message: 'A ride cannot move from in_progress to cancelled.',
          ),
        );
        CancelOutcome? result;
        await pump(tester, repo, onResult: (r) => result = r);
        await tester.tap(find.byKey(const Key('reason_Plans changed')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('confirm_cancel')));
        await tester.pumpAndSettle();
        expect(result!.error!.isConflict, isTrue);
        expect(result!.ride, isNull);
      },
    );

    testWidgets('other failures show an inline error and keep the sheet open', (
      tester,
    ) async {
      final repo = MockRideRepo();
      when(() => repo.cancel(42, 'Plans changed')).thenThrow(
        const ApiException(kind: ApiErrorKind.network, message: 'offline'),
      );
      await pump(tester, repo);
      await tester.tap(find.byKey(const Key('reason_Plans changed')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirm_cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cancel_error')), findsOneWidget);
      expect(find.byKey(const Key('confirm_cancel')), findsOneWidget);
    });
  });
}

Future<void> _until(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) fail('condition not met within $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
