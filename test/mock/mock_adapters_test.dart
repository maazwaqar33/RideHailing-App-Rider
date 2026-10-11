import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_app/core/geo/geo.dart';
import 'package:rider_app/features/rides/domain/ride_models.dart';
import 'package:rider_app/features/trip/domain/trip_models.dart';
import 'package:rider_app/mock/local_trip_stores.dart';
import 'package:rider_app/mock/mock_driver_telemetry.dart';
import 'package:rider_app/mock/mock_nearby_cars.dart';
import 'package:rider_app/mock/mock_place_search.dart';
import 'package:rider_app/mock/mock_route_service.dart';
import 'package:rider_app/mock/oslo_places.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

Ride _ride(String status, {Map<String, dynamic>? timestamps}) => Ride.fromJson(
  rideJson(status: status, withDriver: true, timestamps: timestamps),
);

void main() {
  group('MockDriverTelemetry (simulation, never real telemetry)', () {
    const t = MockDriverTelemetry(legSeconds: 100);

    test('no position while searching or cancelled', () {
      expect(t.positionAt(_ride('requested'), DateTime.now()), isNull);
      expect(t.positionAt(_ride('offered'), DateTime.now()), isNull);
      expect(t.positionAt(_ride('cancelled'), DateTime.now()), isNull);
    });

    test('en route: starts ~1.2 km away and converges on the pickup', () {
      final start = DateTime.parse('2026-10-10T10:00:00+00:00');
      final ride = _ride(
        'driver_en_route',
        timestamps: {'driver_en_route_at': start.toIso8601String()},
      );
      final p0 = t.positionAt(ride, start)!;
      final p50 = t.positionAt(ride, start.add(const Duration(seconds: 50)))!;
      final p200 = t.positionAt(ride, start.add(const Duration(seconds: 200)))!;
      final d0 = haversineMeters(p0.position, ride.pickup.latLng);
      final d50 = haversineMeters(p50.position, ride.pickup.latLng);
      final d200 = haversineMeters(p200.position, ride.pickup.latLng);
      expect(d0, inInclusiveRange(1000, 1500));
      expect(d50, lessThan(d0));
      expect(d200, lessThan(d50));
      expect(
        d200,
        greaterThan(0),
        reason: 'never snaps exactly onto the pickup before the real arrived status',
      );
      expect(p0.isSimulated, isTrue);
      expect(p0.etaSeconds, isNotNull);
    });

    test('arrived: parked at pickup', () {
      final p = t.positionAt(_ride('arrived'), DateTime.now())!;
      expect(p.position, const LatLng(59.911, 10.7528));
      expect(p.etaSeconds, 0);
    });

    test('in progress: moves pickup -> dropoff; completed sits at dropoff', () {
      final started = DateTime.parse('2026-10-10T10:00:00+00:00');
      final ride = _ride(
        'in_progress',
        timestamps: {'started_at': started.toIso8601String()},
      );
      final mid = t.positionAt(ride, started.add(const Duration(seconds: 50)))!;
      final total = haversineMeters(ride.pickup.latLng, ride.dropoff.latLng);
      expect(
        haversineMeters(mid.position, ride.pickup.latLng),
        closeTo(total / 2, total * 0.02),
      );
      expect(
        t.positionAt(_ride('completed'), DateTime.now())!.position,
        const LatLng(59.9106, 10.7298),
      );
    });

    test('start point is deterministic per ride', () {
      expect(
        MockDriverTelemetry.startPointFor(_ride('accepted')),
        MockDriverTelemetry.startPointFor(_ride('accepted')),
      );
    });
  });

  group('MockPlaceSearchRepository', () {
    const repo = MockPlaceSearchRepository();

    test('search matches name and address, accent-insensitive', () async {
      expect(
        (await repo.search('aker')).map((p) => p.id),
        contains('aker-brygge'),
      );
      expect(
        (await repo.search('grunerlokka')).map((p) => p.id),
        contains('grunerlokka'),
      );
      expect(
        (await repo.search('GARDERMOEN')).map((p) => p.id),
        contains('osl-airport'),
      );
      expect(await repo.search('zzzzzz'), isEmpty);
    });

    test(
      'empty query returns suggestions',
      () async => expect(await repo.search(''), isNotEmpty),
    );

    test(
      'results are sorted by distance when a reference point is given',
      () async {
        final res = await repo.search('', near: const LatLng(59.9110, 10.7528));
        expect(res.first.id, 'oslo-s');
      },
    );

    test('nearestKnownPlace only within the radius', () async {
      expect(
        (await repo.nearestKnownPlace(const LatLng(59.9111, 10.7529)))!.id,
        'oslo-s',
      );
      expect(await repo.nearestKnownPlace(const LatLng(60.5, 11.5)), isNull);
    });

    test('every dataset place has valid Oslo-area coordinates', () {
      for (final p in kOsloPlaces) {
        expect(p.position.latitude, inInclusiveRange(59.8, 60.3), reason: p.id);
        expect(
          p.position.longitude,
          inInclusiveRange(10.5, 11.2),
          reason: p.id,
        );
        expect(p.apiAddress.length, lessThanOrEqualTo(255));
      }
    });
  });

  test('MockRouteService is a labelled estimate: haversine distance, 30 km/h duration', () async {
    final r = await const MockRouteService().route(
      const LatLng(59.9110, 10.7528),
      const LatLng(59.9106, 10.7298),
    );
    expect(r.isEstimate, isTrue);
    expect(r.distanceMeters, inInclusiveRange(1200, 1400));
    expect(r.durationSeconds, closeTo(r.distanceMeters / (30000 / 3600), 2));
    expect(r.points.first, const LatLng(59.9110, 10.7528));
    expect(r.points.last, const LatLng(59.9106, 10.7298));
  });

  test('MockNearbyCarsRepository is deterministic and local', () async {
    const repo = MockNearbyCarsRepository();
    final a = await repo.carsNear(kOsloCentre);
    final b = await repo.carsNear(kOsloCentre);
    expect(a, b);
    expect(a.length, 4);
    for (final car in a) {
      expect(haversineMeters(car.position, kOsloCentre), lessThan(9000));
      expect(car.id, startsWith('mock-car-'));
    }
  });

  group('local mock stores', () {
    Future<SharedPreferences> prefs() async {
      SharedPreferences.setMockInitialValues({});
      return SharedPreferences.getInstance();
    }

    test(
      'feedback round-trips and survives re-instantiation (device-only)',
      () async {
        final p = await prefs();
        await LocalFeedbackRepository(p).save(
          const RideFeedback(
            rideId: 5,
            rating: 4,
            comment: 'Smooth',
            tags: ['Quiet ride'],
            tipMinor: 500,
          ),
        );
        final loaded = await LocalFeedbackRepository(p).get(5);
        expect(loaded!.rating, 4);
        expect(loaded.comment, 'Smooth');
        expect(loaded.tags, ['Quiet ride']);
        expect(loaded.tipMinor, 500);
        expect(await LocalFeedbackRepository(p).get(6), isNull);
      },
    );

    test('problem reports accumulate per ride', () async {
      final p = await prefs();
      final repo = LocalProblemReportRepository(p);
      await repo.submit(
        ProblemReport(
          rideId: 5,
          category: 'Wrong fare',
          details: 'x',
          createdAt: DateTime(2026),
        ),
      );
      await repo.submit(
        ProblemReport(
          rideId: 5,
          category: 'Lost item',
          details: 'y',
          createdAt: DateTime(2026),
        ),
      );
      expect((await repo.forRide(5)).map((r) => r.category), [
        'Wrong fare',
        'Lost item',
      ]);
      expect(await repo.forRide(9), isEmpty);
    });

    test('mock payment records the chosen method, is always mock, and is idempotent', () async {
      final p = await prefs();
      final pay = MockPaymentService(p);
      final ride = Ride.fromJson(
        rideJson(
          status: 'completed',
          paymentMethod: 'card',
          finalMinor: 1744,
          withDriver: true,
        ),
      );
      final r1 = await pay.confirm(
        ride: ride,
        method: PaymentMethodType.card,
        tipMinor: 200,
      );
      expect(r1.isMock, isTrue);
      expect(r1.reference, startsWith('MOCK-'));
      expect(r1.method, PaymentMethodType.card);
      expect(r1.amountMinor, 1744);
      expect(r1.tipMinor, 200);
      final r2 = await pay.confirm(
        ride: ride,
        method: PaymentMethodType.cash,
        tipMinor: 0,
      );
      expect(
        r2.reference,
        r1.reference,
        reason: 'confirming twice must not create a second receipt',
      );
      expect((await pay.receiptFor(ride.id))!.method, PaymentMethodType.card);
    });

    test('corrupted stored JSON does not crash', () async {
      SharedPreferences.setMockInitialValues({'mock.feedback.v1': 'not json'});
      final p = await SharedPreferences.getInstance();
      expect(await LocalFeedbackRepository(p).get(1), isNull);
    });
  });
}
