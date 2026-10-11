// Measured performance pass: drives the real app (fake backend, real map tiles) and records frame
// build / raster times per scenario.
//   flutter drive --profile -d <device> --driver=test_driver/perf_driver.dart \
//       --target=integration_test/perf_test.dart
// Results: build/perf/<scenario>.timeline_summary.json (see tool/perf_report.py for a table).
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rider_app/app/app.dart';
import 'package:rider_app/core/network/api_client.dart';
import 'package:rider_app/core/providers.dart';
import 'package:rider_app/core/storage/token_store.dart';
import 'package:rider_app/features/auth/application/session_controller.dart';
import 'package:rider_app/features/map/application/map_providers.dart';
import 'package:rider_app/features/map/domain/map_repositories.dart';
import 'package:rider_app/features/tracking/application/tracking_controller.dart';
import 'package:rider_app/mock/mock_driver_telemetry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/test_helpers.dart';

class _NoLocation implements LocationService {
  @override
  Future<LocationResult> current() async =>
      const LocationResult(status: LocationStatus.denied);
}

Future<List<Override>> _overrides(DateTime Function() rideStart) async {
  SharedPreferences.setMockInitialValues({'flag.onboarding_seen': true});
  final sp = await SharedPreferences.getInstance();
  final store = InMemoryTokenStore(
    StoredSession(
      token: 't',
      expiresAt: DateTime.now().add(const Duration(hours: 5)),
    ),
  );
  final history = [
    for (var i = 0; i < 14; i++)
      {
        ...rideJson(id: 100 + i, status: 'completed', withDriver: true),
        'fare': {
          'currency': 'EUR',
          'estimate_minor': 1744,
          'final_minor': 1744 + i * 10,
          'breakdown': breakdownJson(),
        },
      },
  ];
  final adapter = ScriptedAdapter()
    ..json('GET', '/auth/me', 200, {'data': userJson()})
    ..json('GET', '/rides', 200, {
      'data': history,
      'meta': {'current_page': 1, 'last_page': 1},
    })
    ..json('POST', '/fares/estimate', 200, {
      'data': {
        'breakdown': breakdownJson(),
        'pickup': null,
        'dropoff': null,
        'distance_source': 'client_supplied',
      },
    })
    ..json('POST', '/rides', 201, {
      'data': rideJson(status: 'requested', paymentMethod: 'card'),
    })
    ..on('GET', '/rides/42', (_) {
      final s = DateTime.now().difference(rideStart()).inSeconds;
      final status = s < 4
          ? 'requested'
          : s < 12
          ? 'accepted'
          : s < 40
          ? 'driver_en_route'
          : 'in_progress';
      return ScriptedAdapter.jsonBody(200, {
        'data': rideJson(
          status: status,
          withDriver: status != 'requested',
          paymentMethod: 'card',
        ),
      });
    });
  return [
    sharedPreferencesProvider.overrideWithValue(sp),
    tokenStoreProvider.overrideWithValue(store),
    locationServiceProvider.overrideWithValue(_NoLocation()),
    pollIntervalProvider.overrideWithValue(const Duration(seconds: 2)),
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
  ];
}

double _pct(List<double> sorted, double p) =>
    sorted.isEmpty ? 0 : sorted[((sorted.length - 1) * p).round()];

/// Records FrameTiming (build + raster, ms) while [action] runs, reports a summary under [key].
/// Works in profile mode without a VM-service connection.
Future<void> _trace(
  IntegrationTestWidgetsFlutterBinding binding,
  Future<void> Function() action,
  String key,
) async {
  final timings = <FrameTiming>[];
  void cb(List<FrameTiming> t) => timings.addAll(t);
  WidgetsBinding.instance.addTimingsCallback(cb);
  await action();
  await Future<void>.delayed(const Duration(milliseconds: 500));
  WidgetsBinding.instance.removeTimingsCallback(cb);
  double ms(Duration d) => d.inMicroseconds / 1000.0;
  final build = [for (final t in timings) ms(t.buildDuration)]..sort();
  final raster = [for (final t in timings) ms(t.rasterDuration)]..sort();
  final total = [for (final t in timings) ms(t.totalSpan)]..sort();
  double avg(List<double> l) =>
      l.isEmpty ? 0 : l.reduce((a, b) => a + b) / l.length;
  const budget = 16.7;
  binding.reportData ??= <String, dynamic>{};
  binding.reportData![key] = {
    'frame_count': timings.length,
    'average_frame_build_time_millis': avg(build),
    '90th_percentile_frame_build_time_millis': _pct(build, 0.9),
    '99th_percentile_frame_build_time_millis': _pct(build, 0.99),
    'worst_frame_build_time_millis': build.isEmpty ? 0 : build.last,
    'missed_frame_build_budget_count': build.where((v) => v > budget).length,
    'average_frame_rasterizer_time_millis': avg(raster),
    '90th_percentile_frame_rasterizer_time_millis': _pct(raster, 0.9),
    '99th_percentile_frame_rasterizer_time_millis': _pct(raster, 0.99),
    'worst_frame_rasterizer_time_millis': raster.isEmpty ? 0 : raster.last,
    'missed_frame_rasterizer_budget_count':
        raster.where((v) => v > budget).length,
    'average_frame_total_millis': avg(total),
    '99th_percentile_frame_total_millis': _pct(total, 0.99),
    'janky_frames_total_over_budget': total.where((v) => v > budget).length,
  };
}

Future<void> _wait(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _drag(WidgetTester t, Finder f, Offset d, {int ms = 600}) async {
  await t.timedDrag(f, d, Duration(milliseconds: ms));
  await _wait(t, 200);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  late DateTime rideStart;

  Future<void> boot(WidgetTester t) async {
    rideStart = DateTime.now();
    final o = await _overrides(() => rideStart);
    await t.pumpWidget(ProviderScope(overrides: o, child: const RiderApp()));
    await _wait(t, 3000); // splash + home + first tiles
  }

  testWidgets('perf: home, booking flow, tracking', (t) async {
    await boot(t);

    // 1. Home: pan the map, idle with the mock cars moving, then scroll the sheet.
    await _trace(binding, () async {
      final map = find.byType(FlutterMap).first;
      for (var i = 0; i < 3; i++) {
        await _drag(t, map, const Offset(-160, 90));
        await _drag(t, map, const Offset(160, -90));
      }
      await _wait(t, 1500);
      final where = find.byKey(const Key('where_to'));
      await _drag(t, where, const Offset(0, -300));
      await _drag(t, where, const Offset(0, 300));
    },  '1_home');

    // 2. Search -> ride selection.
    await t.tap(find.byKey(const Key('where_to')));
    await _wait(t, 1200);
    await t.enterText(find.byType(TextField).last, 'aker');
    await _wait(t, 800);
    await _trace(binding, () async {
      await t.tap(find.byKey(const Key('result_aker-brygge')));
      await _wait(t, 600);
      await t.tap(find.byKey(const Key('search_next')));
      await _wait(t, 2500);
      final list = find.byType(Scrollable).first;
      await _drag(t, list, const Offset(0, -400));
      await _drag(t, list, const Offset(0, 400));
      await _wait(t, 1500);
    },  '2_ride_selection');

    // 3. Confirm & pay -> request -> tracking (searching, driver found, en route).
    await t.ensureVisible(find.byKey(const Key('continue_to_payment')));
    await t.tap(find.byKey(const Key('continue_to_payment')));
    await _wait(t, 1200);
    await t.ensureVisible(find.byKey(const Key('request_ride')));
    await t.tap(find.byKey(const Key('request_ride')));
    rideStart = DateTime.now();
    await _trace(binding, () async {
      await _wait(t, 20000);
      final s = find.byType(Scrollable);
      if (s.evaluate().isNotEmpty) {
        await _drag(t, s.first, const Offset(0, -300));
        await _drag(t, s.first, const Offset(0, 300));
      }
    },  '3_tracking');
  });

  testWidgets('perf: trips and wallet', (t) async {
    await boot(t);
    await t.tap(find.text('Trips').last);
    await _wait(t, 1500);
    await _trace(binding, () async {
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 3; i++) {
        await _drag(t, list, const Offset(0, -500));
        await _drag(t, list, const Offset(0, 500));
      }
    },  '4_trips');
    await t.tap(find.text('Wallet').last);
    await _wait(t, 1200);
    await _trace(binding, () async {
      final list = find.byType(Scrollable).first;
      await _drag(t, list, const Offset(0, -400));
      await _drag(t, list, const Offset(0, 400));
    },  '5_wallet');
  });
}
