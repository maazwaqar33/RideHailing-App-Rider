import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_app/core/config/env.dart';
import 'package:rider_app/core/formatting/formatters.dart';
import 'package:rider_app/core/geo/geo.dart';

void main() {
  group('Money', () {
    test('formats minor units with currency symbol', () {
      expect(Money.format(1744, 'EUR'), '€17.44');
      expect(Money.format(5, 'EUR'), '€0.05');
      expect(Money.format(123456, 'NOK'), '1,234.56 kr');
      expect(Money.format(100, 'CHF'), '1.00 CHF');
    });
    test('signed', () => expect(Money.formatSigned(-50, 'EUR'), '-€0.50'));
  });

  group('Fmt', () {
    test('distance', () {
      expect(Fmt.distance(450), '450 m');
      expect(Fmt.distance(1500), '1.5 km');
      expect(Fmt.distance(47000), '47 km');
    });
    test('duration', () {
      expect(Fmt.duration(59), '1 min');
      expect(Fmt.duration(600), '10 min');
      expect(Fmt.duration(3600), '1 h');
      expect(Fmt.duration(5400), '1 h 30 min');
    });
  });

  group('haversine', () {
    test('Oslo S to Aker Brygge is about 1.5 km', () {
      final d = haversineMeters(
        const LatLng(59.9110, 10.7528),
        const LatLng(59.9106, 10.7298),
      );
      expect(d, inInclusiveRange(1200, 1400));
    });
    test(
      'Oslo S to Gardermoen is about 37 km straight-line (47 km by road)',
      () {
        final d = haversineMeters(kOsloCentre, const LatLng(60.1939, 11.1004));
        expect(d / 1000, inInclusiveRange(35, 40));
      },
    );
    test(
      'zero distance',
      () => expect(haversineMeters(kOsloCentre, kOsloCentre), 0),
    );
    test('duration estimate has a floor of 60 s', () {
      expect(estimateDurationSeconds(10), 60);
      expect(estimateDurationSeconds(15000), 1800); // 15 km at 30 km/h
    });
    test('polyline endpoints', () {
      final line = interpolatePolyline(
        const LatLng(0, 0),
        const LatLng(1, 1),
        segments: 4,
      );
      expect(line.length, 5);
      expect(line.first, const LatLng(0, 0));
      expect(line.last, const LatLng(1, 1));
    });
  });

  group('Env.resolveApiBaseUrl', () {
    test(
      'android emulator default',
      () => expect(
        Env.resolveApiBaseUrl('', TargetPlatform.android, false),
        'http://10.0.2.2:8001',
      ),
    );
    test(
      'desktop default',
      () => expect(
        Env.resolveApiBaseUrl('', TargetPlatform.windows, false),
        'http://127.0.0.1:8001',
      ),
    );
    test(
      'web default',
      () => expect(
        Env.resolveApiBaseUrl('', TargetPlatform.android, true),
        'http://127.0.0.1:8001',
      ),
    );
    test('override wins and trailing slash is trimmed', () {
      expect(
        Env.resolveApiBaseUrl(
          'https://api.example.com/',
          TargetPlatform.android,
          false,
        ),
        'https://api.example.com',
      );
    });
  });
}
