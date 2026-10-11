import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';
import 'package:rider_app/shared/app_map.dart';
import 'package:rider_app/shared/stitch.dart';
import 'package:rider_app/core/providers.dart';
import 'package:rider_app/core/storage/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_app/core/network/api_exception.dart';
import 'package:rider_app/features/auth/application/session_controller.dart';
import 'package:rider_app/features/auth/domain/auth_models.dart';
import 'package:rider_app/features/map/application/map_providers.dart';
import 'package:rider_app/features/fare/domain/fare_models.dart';
import 'package:rider_app/features/fare/domain/fare_repository.dart';
import 'package:rider_app/features/map/domain/map_models.dart';
import 'package:rider_app/features/map/domain/map_repositories.dart';
import 'package:rider_app/features/rides/application/ride_providers.dart';
import 'package:rider_app/features/rides/domain/ride_models.dart';
import 'package:rider_app/features/rides/domain/ride_repository.dart';

/// Signed-in session for QA renders (no network).
class FakeSession extends SessionController {
  FakeSession(this.user);

  final AuthUser user;

  @override
  SessionState build() => SessionAuthenticated(user);
}

/// Session stuck in "could not restore" (splash error card with Try again / Sign in again).
class FakeFailedSession extends SessionController {
  @override
  SessionState build() =>
      const SessionRestoreFailed(ApiErrorMapper.timeoutMessage);
}

const kQaUser = AuthUser(
  id: 7,
  name: 'Sara Hansen',
  email: 'sara.hansen@example.no',
  phone: '+47 941 23 891',
  riderId: 1,
);

class QaLocation implements LocationService {
  @override
  Future<LocationResult> current() async => const LocationResult(
    status: LocationStatus.granted,
    position: LatLng(59.9111, 10.7528),
  );
}

class QaCars implements NearbyCarsRepository {
  @override
  Future<List<NearbyCar>> carsNear(LatLng position) async => [
    NearbyCar(
      id: 'a',
      position: LatLng(position.latitude + 0.012, position.longitude - 0.004),
      etaMinutes: 2,
    ),
    NearbyCar(
      id: 'b',
      position: LatLng(position.latitude + 0.006, position.longitude + 0.016),
      etaMinutes: 3,
    ),
    NearbyCar(
      id: 'c',
      position: LatLng(position.latitude - 0.010, position.longitude - 0.020),
      etaMinutes: 4,
    ),
    NearbyCar(
      id: 'd',
      position: LatLng(position.latitude - 0.006, position.longitude + 0.010),
      etaMinutes: 5,
    ),
  ];
}

/// Ride repository that returns canned data (history / active ride) without any HTTP.
class QaRides implements RideRepository {
  QaRides({this.rides = const []});

  final List<Ride> rides;

  @override
  Future<Ride> cancel(int id, String reason) async => rides.first;

  @override
  Future<Ride> create(
    CreateRideRequest request, {
    required String idempotencyKey,
  }) async => rides.first;

  @override
  Future<Ride> get(int id) async =>
      rides.firstWhere((r) => r.id == id, orElse: () => rides.first);

  @override
  Future<RidePage> list({
    int page = 1,
    int perPage = 15,
    RideStatus? status,
  }) async => RidePage(rides: rides, currentPage: 1, lastPage: 1);

  @override
  Future<List<TimelineEntry>> timeline(int id) async =>
      rides.isEmpty ? const [] : rides.first.timeline;
}

/// Standard overrides for tab screens rendered with the signed-in QA user.
List<Override> qaOverrides({List<Ride> rides = const []}) => [
  sessionControllerProvider.overrideWith(() => FakeSession(kQaUser)),
  locationServiceProvider.overrideWithValue(QaLocation()),
  nearbyCarsRepositoryProvider.overrideWithValue(QaCars()),
  rideRepositoryProvider.overrideWithValue(QaRides(rides: rides)),
];

/// Renders a screen at the Stitch screenshot logical size (390 px wide) and writes
/// docs/visual-qa/flutter/NAME.png at the same pixel density as the Stitch screen.png,
/// so `python tool/visual_compare.py` can place them side by side.
///
/// [mapAsset] swaps live OSM tiles for the same static Oslo map the design uses.
Future<void> renderScreen(
  WidgetTester tester, {
  required String name,
  required double scale,
  required double logicalHeight,
  required Widget screen,
  List<Override> overrides = const [],
  String? mapAsset,
  bool liveTiles = false,
  String? outDir,
  Map<String, Object> prefs = const {},
  Future<void> Function(WidgetTester tester)? after,
  Duration settle = const Duration(milliseconds: 1600),
  double logicalWidth = 390,
  double textScale = 1,
}) async {
  if (liveTiles) {
    HttpOverrides.global = null; // allow real network for tile requests
  }
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  tester.view.devicePixelRatio = scale;
  tester.view.physicalSize = Size(logicalWidth * scale, logicalHeight * scale);
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        if (!liveTiles)
          mapTileLayerProvider.overrideWithValue(
            (ctx) => mapAsset == null
                ? const SizedBox.shrink()
                : Positioned.fill(child: StitchMapImage(mapAsset)),
          ),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: NordicTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: RepaintBoundary(key: key, child: screen),
      ),
    ),
  );
  // Let precached images + finite animations finish without waiting for infinite ones.
  await tester.runAsync(() async {
    // Live tiles come over the network: give them real time to arrive.
    await Future<void>.delayed(Duration(milliseconds: 250));
  });
  for (var i = 0; i < settle.inMilliseconds ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.runAsync(() async {
    final context = tester.element(find.byType(Scaffold).first);
    // Make sure image assets are decoded.
    for (final e in find.byType(Image).evaluate()) {
      final img = (e.widget as Image).image;
      await precacheImage(img, e);
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    context.hashCode; // keep the analyzer quiet about the unused local
  });
  await tester.pump(const Duration(milliseconds: 100));
  if (liveTiles) {
    // Tile requests start after the first frames; wait for the network, then repaint.
    for (var round = 0; round < 14; round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1200)),
      );
      // Advance the fake clock between real waits so tile images get painted.
      await tester.pump(const Duration(seconds: 1));
    }
  }
  if (after != null) await after(tester);

  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: scale);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final out = File('${outDir ?? 'docs/visual-qa/flutter'}/$name.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes.buffer.asUint8List());
  });
  if (liveTiles) {
    // Dispose the tree and let pending tile timers fire.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }
}

/// Starts the trip plan with a pickup (and optionally a drop-off) already chosen.
class PresetPlan extends TripPlanController {
  PresetPlan({this.pickup, this.dropoff, this.vehicle, this.payment});

  final Place? pickup;
  final Place? dropoff;
  final VehicleChoice? vehicle;
  final PaymentMethodType? payment;

  @override
  TripPlan build() => TripPlan(
    pickup: pickup,
    dropoff: dropoff,
    vehicle: vehicle ?? VehicleChoice.sedan,
    payment: payment ?? PaymentMethodType.cash,
  );
}

/// Fare repository returning a fixed backend-style estimate (no HTTP).
class QaFare implements FareRepository {
  QaFare({this.totalMinor = 10900, this.mock = false});

  final int totalMinor;
  final bool mock;

  @override
  Future<FareEstimate> estimate(FareEstimateRequest request) async =>
      FareEstimate(
        source: mock ? FareSource.mockFallback : FareSource.backend,
        breakdown: FareBreakdown(
          currency: 'EUR',
          distanceMeters: request.distanceMeters,
          durationSeconds: request.durationSeconds,
          baseFareMinor: 350,
          distanceChargeMinor: 6000,
          timeChargeMinor: 3000,
          rawFareMinor: 9350,
          minimumFareAdjustmentMinor: 0,
          fareMinor: 9350,
          bookingFeeMinor: 100,
          taxMinor: 1134,
          totalMinor: totalMinor,
        ),
      );
}
