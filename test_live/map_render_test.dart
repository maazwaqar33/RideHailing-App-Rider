// LIVE map render (needs internet): draws the real CARTO Voyager tiles with the app's markers,
// route and cars to docs/visual-qa/live-map/*.png so the basemap style can be judged against
// the Stitch maps. Tiles are downloaded with dart:io and served through PrefetchedTileProvider
// because `flutter test` cannot complete NetworkImage tile loads.
// Run: flutter test test_live/map_render_test.dart
import 'dart:io';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_app/features/booking/presentation/choose_ride_screen.dart';
import 'package:rider_app/features/map/application/map_providers.dart';
import 'package:rider_app/features/map/domain/map_models.dart';
import 'package:rider_app/features/map/presentation/ride_tab.dart';
import 'package:rider_app/features/rides/domain/ride_models.dart';
import 'package:rider_app/features/tracking/presentation/ride_screen.dart';
import 'package:rider_app/shared/app_map.dart';
import 'package:rider_app/shared/nav_scaffold.dart';

import '../test/helpers/test_helpers.dart' show rideJson;
import '../test/visual/visual_harness.dart';
import 'support/prefetched_tiles.dart';

void main() {
  late PrefetchedTileProvider tiles;

  setUpAll(() async {
    HttpOverrides.global = null;
    tiles = await PrefetchedTileProvider.load(const [
      LatLng(59.9110, 10.7528),
      LatLng(59.9106, 10.7298),
      LatLng(60.1939, 11.1004),
    ]);
  });

  Override realTiles() => mapTileLayerProvider.overrideWithValue(
    (ctx) => buildTileLayer(provider: tiles),
  );

  testWidgets('home map with cars', (tester) async {
    await renderScreen(
      tester,
      name: 'home',
      outDir: 'docs/visual-qa/live-map',
      scale: 2,
      liveTiles: true,
      logicalHeight: 844,
      overrides: [...qaOverrides(), realTiles()],
      screen: StitchNavScaffold(
        index: 0,
        onSelect: (_) {},
        sectionLabel: 'Ride Booking',
        userName: 'Sara Hansen',
        body: const RideTab(),
      ),
    );
  });

  testWidgets('ride selection map', (tester) async {
    const oslo = Place(
      id: 'oslo-s',
      name: 'Oslo S',
      address: 'Jernbanetorget',
      position: LatLng(59.9110, 10.7528),
      kind: PlaceKind.transit,
    );
    const aker = Place(
      id: 'aker',
      name: 'Aker Brygge',
      address: 'Stranden',
      position: LatLng(59.9106, 10.7298),
      kind: PlaceKind.address,
    );
    await renderScreen(
      tester,
      name: 'ride_selection',
      outDir: 'docs/visual-qa/live-map',
      scale: 2,
      liveTiles: true,
      logicalHeight: 900,
      overrides: [
        ...qaOverrides(),
        realTiles(),
        tripPlanProvider.overrideWith(
          () => PresetPlan(
            pickup: oslo,
            dropoff: aker,
            vehicle: VehicleChoice.estate,
          ),
        ),
        fareRepositoryProvider.overrideWithValue(QaFare()),
      ],
      screen: const ChooseRideScreen(),
    );
  });

  for (final status in ['accepted', 'driver_en_route', 'in_progress']) {
    testWidgets('tracking $status', (tester) async {
      final ago = DateTime.now()
          .subtract(const Duration(seconds: 20))
          .toIso8601String();
      final ride = Ride.fromJson(
        rideJson(
          id: 42,
          status: status,
          withDriver: true,
          timestamps: {
            'accepted_at': ago,
            'driver_en_route_at': ago,
            'started_at': ago,
          },
        ),
      );
      await renderScreen(
        tester,
        name: 'tracking_$status',
        outDir: 'docs/visual-qa/live-map',
        scale: 2,
        liveTiles: true,
        logicalHeight: 900,
        overrides: [
          ...qaOverrides(rides: [ride]),
          realTiles(),
        ],
        screen: const RideScreen(rideId: 42),
      );
    });
  }
}
