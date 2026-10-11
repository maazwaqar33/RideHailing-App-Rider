// Visual QA renders: `flutter test test/visual` then `python tool/visual_compare.py`.
// These are NOT assertions about pixels; they produce images for human comparison with Stitch.
import 'package:flutter/material.dart';
import 'package:rider_app/features/map/application/map_providers.dart';
import 'package:rider_app/features/map/domain/map_models.dart';
import 'package:rider_app/features/booking/presentation/choose_ride_screen.dart';
import 'package:rider_app/features/booking/presentation/fleets_screen.dart';
import 'package:rider_app/features/booking/presentation/confirm_pay_screen.dart';
import 'package:rider_app/features/rides/domain/ride_models.dart';
import 'package:rider_app/features/map/presentation/pick_on_map_screen.dart';
import 'package:rider_app/features/map/presentation/search_destination_screen.dart';
import 'package:rider_app/mock/mock_place_search.dart';
import 'package:latlong2/latlong.dart';

import 'dart:convert';

import 'package:rider_app/features/map/presentation/ride_tab.dart';
import 'package:rider_app/shared/nav_scaffold.dart';
import 'package:rider_app/shared/stitch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/auth/presentation/auth_hub_screen.dart';
import 'package:rider_app/features/onboarding/presentation/intro_onboarding_screen.dart';
import 'package:rider_app/features/auth/presentation/login_screen.dart';
import 'package:rider_app/features/auth/presentation/signup_screen.dart';
import 'package:rider_app/features/auth/presentation/welcome_screen.dart';
import 'package:rider_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:rider_app/features/auth/application/session_controller.dart';
import 'package:rider_app/features/onboarding/presentation/splash_screen.dart';

import '../helpers/test_helpers.dart' show rideJson;

import 'package:rider_app/features/tracking/presentation/ride_screen.dart';
import 'package:rider_app/features/history/presentation/trip_receipt_screen.dart';
import 'package:rider_app/features/history/presentation/trips_tab.dart';
import 'package:rider_app/features/wallet/presentation/wallet_tab.dart';
import 'package:rider_app/features/profile/presentation/profile_tab.dart';
import 'package:rider_app/features/auth/domain/auth_models.dart';
import 'package:rider_app/features/trip/presentation/rate_tip_screen.dart';
import 'package:rider_app/features/trip/presentation/trip_complete_screen.dart';

import 'visual_harness.dart';

void main() {
  testWidgets('splash_screen', (tester) async {
    await renderScreen(
      tester,
      name: 'splash_screen',
      scale: 706 / 390,
      logicalHeight: 884,
      screen: const SplashScreen(),
    );
  });

  testWidgets('splash_screen@restore_failed', (tester) async {
    await renderScreen(
      tester,
      name: 'splash_screen@restore_failed',
      scale: 706 / 390,
      logicalHeight: 884,
      screen: const SplashScreen(),
      overrides: [
        sessionControllerProvider.overrideWith(FakeFailedSession.new),
      ],
    );
  });

  testWidgets('splash_screen@restore_failed_360x640', (tester) async {
    await renderScreen(
      tester,
      name: 'splash_screen@restore_failed_360x640',
      scale: 2,
      logicalWidth: 360,
      logicalHeight: 640,
      screen: const SplashScreen(),
      overrides: [
        sessionControllerProvider.overrideWith(FakeFailedSession.new),
      ],
    );
  });

  testWidgets('splash_screen@restore_failed_360x640_text1.6', (tester) async {
    await renderScreen(
      tester,
      name: 'splash_screen@restore_failed_360x640_text1.6',
      scale: 2,
      logicalWidth: 360,
      logicalHeight: 640,
      textScale: 1.6,
      screen: const SplashScreen(),
      overrides: [
        sessionControllerProvider.overrideWith(FakeFailedSession.new),
      ],
    );
  });

  for (final (i, name) in [
    (0, 'onboarding_1_book_in_seconds'),
    (1, 'onboarding_2_track_live'),
    (2, 'onboarding_3_pay_your_way'),
  ]) {
    testWidgets(name, (tester) async {
      await renderScreen(
        tester,
        name: name,
        scale: 706 / 390,
        logicalHeight: 884,
        screen: OnboardingScreen(initialPage: i),
      );
    });
  }

  testWidgets('welcome_screen', (tester) async {
    await renderScreen(
      tester,
      name: 'welcome_screen',
      scale: 706 / 390,
      logicalHeight: 884,
      screen: const WelcomeScreen(),
    );
  });

  testWidgets('log_in_screen', (tester) async {
    await renderScreen(
      tester,
      name: 'log_in_screen',
      scale: 680 / 390,
      logicalHeight: 918,
      screen: const LoginScreen(),
      prefs: {
        'last_user_name': 'Erlend Kvist',
        'last_user_email': 'erlend.kvist@nordic.oslo',
      },
      after: (t) async {
        await t.enterText(
          find.byKey(const Key('login_email')),
          'erlend.kvist@nordic.oslo',
        );
        await t.pump();
      },
    );
  });

  testWidgets('create_account_step_1_of_3', (tester) async {
    await renderScreen(
      tester,
      name: 'create_account_step_1_of_3',
      scale: 649 / 390,
      logicalHeight: 1040,
      screen: const SignupScreen(),
      after: (t) async {
        await t.enterText(find.byKey(const Key('signup_name')), 'Sara Hansen');
        await t.enterText(
          find.byKey(const Key('signup_email')),
          'sara.hansen@example.no',
        );
        await t.enterText(
          find.byKey(const Key('signup_password')),
          'polestar2',
        );
        await t.tap(find.byKey(const Key('signup_password_toggle')));
        await t.tap(find.byKey(const Key('signup_continue')));
        await t.pump(const Duration(milliseconds: 100));
      },
    );
  });
  testWidgets('create_account_step_3_of_3_agreements_permissions', (
    tester,
  ) async {
    await renderScreen(
      tester,
      name: 'create_account_step_3_of_3_agreements_permissions',
      scale: 629 / 390,
      logicalHeight: 992,
      screen: const SignupScreen(initialStep: 2),
      after: (t) async {
        await t.tap(find.byKey(const Key('signup_terms')));
        await t.pump();
      },
    );
  });

  testWidgets('home_oslo_map', (tester) async {
    Map<String, dynamic> place(
      String id,
      String name,
      String address,
      double lat,
      double lng,
    ) => {
      'id': id,
      'name': name,
      'address': address,
      'lat': lat,
      'lng': lng,
      'kind': 'address',
    };
    await renderScreen(
      tester,
      name: 'home_oslo_map',
      scale: 504 / 390,
      logicalHeight: 1238,
      mapAsset: DesignAssets.mapHome,
      overrides: qaOverrides(),
      prefs: {
        'places.saved.home.v1': jsonEncode(
          place('home', 'Frognerveien 14', 'Frognerveien 14', 59.919, 10.706),
        ),
        'places.saved.work.v1': jsonEncode(
          place('work', 'Aker Brygge 4', 'Aker Brygge 4', 59.91, 10.729),
        ),
        'places.recents.v1': jsonEncode([
          place(
            'opera',
            'Den Norske Opera & Ballett',
            'Kirsten Flagstads plass 1, Bjørvika',
            59.9075,
            10.7531,
          ),
          place(
            'munch',
            'MUNCH Museum',
            'Edvard Munchs plass 1, 0194 Oslo',
            59.9059,
            10.755,
          ),
          place(
            'nat',
            'Nationaltheatret Stasjon',
            'Johanne Dybwads plass 1',
            59.9146,
            10.734,
          ),
        ]),
      },
      screen: StitchNavScaffold(
        index: 0,
        onSelect: (_) {},
        sectionLabel: 'Ride Booking',
        userName: 'Sara Hansen',
        body: const RideTab(),
      ),
    );
  });

  testWidgets('search_destination', (tester) async {
    Place p(
      String id,
      String name,
      String address,
      double lat,
      double lng, [
      PlaceKind k = PlaceKind.address,
    ]) => Place(
      id: id,
      name: name,
      address: address,
      position: LatLng(lat, lng),
      kind: k,
    );
    final oslo = p(
      'oslo-s',
      'Current location (Oslo S, Jernbanetorget)',
      'Jernbanetorget',
      59.9110,
      10.7528,
    );
    final airport = p(
      'osl-airport',
      'Oslo Airport Gardermoen (OSL)',
      'Edvard Munchs veg',
      60.1939,
      11.1004,
      PlaceKind.airport,
    );
    await renderScreen(
      tester,
      name: 'search_destination',
      scale: 675 / 390,
      logicalHeight: 924,
      overrides: [
        ...qaOverrides(),
        tripPlanProvider.overrideWith(
          () => PresetPlan(pickup: oslo, dropoff: airport),
        ),
        placeSearchRepositoryProvider.overrideWithValue(
          MockPlaceSearchRepository(
            places: [
              airport,
              p(
                'munch',
                'MUNCH Museum',
                'Edvard Munchs plass 1, Bjørvika',
                59.9059,
                10.755,
                PlaceKind.museum,
              ),
              p(
                'nat',
                'Nationaltheatret Stasjon',
                'Johanne Dybwads plass 1',
                59.9146,
                10.734,
                PlaceKind.transit,
              ),
              p(
                'holmenkollen',
                'Holmenkollen Ski Museum',
                'Kongeveien 5',
                59.9637,
                10.6676,
                PlaceKind.museum,
              ),
            ],
          ),
        ),
      ],
      prefs: {
        'places.saved.home.v1': jsonEncode({
          'id': 'home',
          'name': 'Frognerveien 14',
          'address': 'Frognerveien 14, 0263 Oslo',
          'lat': 59.919,
          'lng': 10.706,
          'kind': 'address',
        }),
        'places.saved.work.v1': jsonEncode({
          'id': 'work',
          'name': 'Aker Brygge, Str. 1',
          'address': 'Aker Brygge, Stranden 1',
          'lat': 59.91,
          'lng': 10.729,
          'kind': 'address',
        }),
      },
      screen: const SearchDestinationScreen(),
    );
  });

  testWidgets('confirm_pickup', (tester) async {
    const oslo = Place(
      id: 'oslo-s',
      name: 'Oslo S (Jernbanetorget)',
      address: 'At the taxi stand by the sea side entrance (Sjøsiden)',
      position: LatLng(59.9110, 10.7528),
      kind: PlaceKind.transit,
    );
    await renderScreen(
      tester,
      name: 'confirm_pickup',
      scale: 706 / 390,
      logicalHeight: 884,
      mapAsset: DesignAssets.mapPickup,
      overrides: [
        ...qaOverrides(),
        tripPlanProvider.overrideWith(() => PresetPlan(pickup: oslo)),
        placeSearchRepositoryProvider.overrideWithValue(
          const MockPlaceSearchRepository(places: [oslo]),
        ),
      ],
      screen: const PickOnMapScreen(target: PickTarget.pickup),
    );
  });

  testWidgets('ride_selection_oslo_s_to_osl', (tester) async {
    const oslo = Place(
      id: 'oslo-s',
      name: 'Oslo S',
      address: 'Jernbanetorget',
      position: LatLng(59.9110, 10.7528),
      kind: PlaceKind.transit,
    );
    const airport = Place(
      id: 'osl',
      name: 'Oslo Airport (OSL)',
      address: 'Gardermoen',
      position: LatLng(60.1939, 11.1004),
      kind: PlaceKind.airport,
    );
    await renderScreen(
      tester,
      name: 'ride_selection_oslo_s_to_osl',
      scale: 571 / 390,
      logicalHeight: 1093,
      mapAsset: DesignAssets.mapPickup,
      overrides: [
        ...qaOverrides(),
        tripPlanProvider.overrideWith(
          () => PresetPlan(
            pickup: oslo,
            dropoff: airport,
            vehicle: VehicleChoice.estate,
          ),
        ),
        fareRepositoryProvider.overrideWithValue(QaFare()),
      ],
      screen: const ChooseRideScreen(),
    );
  });

  testWidgets('confirm_and_pay', (tester) async {
    const oslo = Place(
      id: 'oslo-s',
      name: 'Oslo S (Jernbanetorget)',
      address: 'Jernbanetorget',
      position: LatLng(59.9110, 10.7528),
      kind: PlaceKind.transit,
    );
    const airport = Place(
      id: 'osl',
      name: 'Oslo Airport (OSL)',
      address: 'Gardermoen',
      position: LatLng(60.1939, 11.1004),
      kind: PlaceKind.airport,
    );
    await renderScreen(
      tester,
      name: 'confirm_and_pay',
      scale: 531 / 390,
      logicalHeight: 1175,
      mapAsset: DesignAssets.mapA,
      overrides: [
        ...qaOverrides(),
        tripPlanProvider.overrideWith(
          () => PresetPlan(
            pickup: oslo,
            dropoff: airport,
            vehicle: VehicleChoice.estate,
            payment: PaymentMethodType.cash,
          ),
        ),
        fareRepositoryProvider.overrideWithValue(QaFare()),
      ],
      screen: const ConfirmPayScreen(),
    );
  });

  // ---- Ride lifecycle (RideScreen stages) ----
  Ride qaRide(String status, {bool driver = true}) => Ride.fromJson(
    rideJson(
      id: 42,
      status: status,
      withDriver: driver,
      timestamps: {
        'requested_at': DateTime.now()
            .subtract(const Duration(seconds: 23))
            .toIso8601String(),
      },
    ),
  );
  final stages = <(String, String, double, double, bool)>[
    ('searching_for_driver', 'requested', 560, 1114, false),
    ('driver_found_erik_larsen', 'accepted', 619, 1008, true),
    ('live_tracking_3_states@en_route', 'driver_en_route', 563, 1110, true),
    ('live_tracking_3_states@in_progress', 'in_progress', 563, 1110, true),
    ('live_trip_driver_arrived_pin_4821', 'arrived', 657, 951, true),
  ];
  for (final (name, status, w, h, driver) in stages) {
    testWidgets(name, (tester) async {
      await renderScreen(
        tester,
        name: name,
        scale: w / 390,
        logicalHeight: h,
        // The searching design has an empty map container (no image in the export).
        mapAsset: switch (status) {
          'requested' => null,
          'driver_en_route' || 'in_progress' => DesignAssets.mapLive,
          _ => DesignAssets.mapPickup,
        },
        overrides: qaOverrides(rides: [qaRide(status, driver: driver)]),
        screen: const RideScreen(rideId: 42),
      );
    });
  }

  testWidgets('trip_complete_receipt', (tester) async {
    await renderScreen(
      tester,
      name: 'trip_complete_receipt',
      scale: 497 / 390,
      logicalHeight: 1255,
      overrides: qaOverrides(rides: [qaRide('completed')]),
      screen: const TripCompleteScreen(rideId: 42),
      after: (t) async {
        await t.tap(find.byKey(const ValueKey('star_5')));
        await t.tap(find.byKey(const Key('tag_Punctual arrival')));
        await t.tap(find.byKey(const Key('tag_Quiet ride')));
        await t.tap(find.byKey(const Key('tip_500')));
        await t.pump(const Duration(milliseconds: 200));
      },
    );
  });

  testWidgets('rate_and_tip_driver', (tester) async {
    await renderScreen(
      tester,
      name: 'rate_and_tip_driver',
      scale: 577 / 390,
      logicalHeight: 1081,
      overrides: qaOverrides(rides: [qaRide('completed')]),
      screen: const RateTipScreen(rideId: 42),
      after: (t) async {
        await t.tap(find.byKey(const ValueKey('star_5')));
        await t.tap(find.byKey(const Key('tag_Punctual arrival')));
        await t.tap(find.byKey(const Key('tag_Smooth driving')));
        await t.tap(find.byKey(const Key('tag_Clean cabin')));
        await t.enterText(
          find.byKey(const Key('rating_comment')),
          'Erik was fantastic, warm car and smooth ride out to Gardermoen.',
        );
        await t.tap(find.byKey(const Key('tip_500')));
        await t.pump(const Duration(milliseconds: 200));
      },
    );
  });

  testWidgets('trip_receipt', (tester) async {
    await renderScreen(
      tester,
      name: 'trip_receipt',
      scale: 443 / 390,
      logicalHeight: 1409,
      mapAsset: DesignAssets.mapA,
      overrides: qaOverrides(rides: [qaRide('completed')]),
      screen: const TripReceiptScreen(rideId: 42),
    );
  });

  testWidgets('trip_history_receipts', (tester) async {
    Ride hist(
      int id,
      String from,
      String to,
      int km,
      int minor,
      DateTime at, {
      bool driver = false,
      String method = 'cash',
    }) {
      final j = rideJson(
        id: id,
        status: 'completed',
        withDriver: driver,
        paymentMethod: method,
        finalMinor: minor,
        timestamps: {'completed_at': at.toIso8601String()},
      );
      (j['pickup'] as Map)['address'] = from;
      (j['dropoff'] as Map)['address'] = to;
      j['distance_meters'] = km;
      return Ride.fromJson(j);
    }

    final now = DateTime.now();
    await renderScreen(
      tester,
      name: 'trip_history_receipts',
      scale: 561 / 390,
      logicalHeight: 1112,
      overrides: qaOverrides(
        rides: [
          hist(4, 'Oslo S', 'Oslo Lufthavn', 47200, 10900, now, driver: true),
          hist(
            3,
            'Aker Brygge',
            'Frognerveien 14',
            2800,
            2100,
            now.subtract(const Duration(days: 1)),
          ),
          hist(
            2,
            'MUNCH Museum',
            'Nationaltheatret',
            2100,
            1850,
            now.subtract(const Duration(days: 3)),
            method: 'card',
          ),
          hist(
            1,
            'Oslo S',
            'Holmenkollen',
            10400,
            6400,
            now.subtract(const Duration(days: 5)),
          ),
        ],
      ),
      screen: StitchNavScaffold(
        index: 1,
        onSelect: (_) {},
        sectionLabel: 'Activity Trips',
        userName: 'Sara Hansen',
        body: const TripsTab(),
      ),
    );
  });

  for (final (name, index, label, body) in <(String, int, String, Widget)>[
    ('profile_wallet', 2, 'Wallet', const WalletTab()),
    ('profile_tab', 3, 'Profile', const ProfileTab()),
  ]) {
    testWidgets(name, (tester) async {
      Map<String, dynamic> place(
        String id,
        String n,
        String a,
        double lat,
        double lng,
      ) => {
        'id': id,
        'name': n,
        'address': a,
        'lat': lat,
        'lng': lng,
        'kind': 'address',
      };
      await renderScreen(
        tester,
        name: name,
        scale: 386 / 390,
        logicalHeight: 1616,
        overrides: [
          ...qaOverrides(),
          riderProfileProvider.overrideWith(
            (ref) async => const RiderProfile(
              id: 1,
              firstName: 'Sara',
              lastName: 'Hansen',
              defaultPaymentMethod: 'cash',
            ),
          ),
        ],
        prefs: {
          'places.saved.home.v1': jsonEncode(
            place(
              'home',
              'Frognerveien 14',
              'Frognerveien 14, 0263 Oslo',
              59.919,
              10.706,
            ),
          ),
          'places.saved.work.v1': jsonEncode(
            place(
              'work',
              'Aker Brygge',
              'Aker Brygge, Stranden 1, Oslo',
              59.91,
              10.729,
            ),
          ),
        },
        screen: StitchNavScaffold(
          index: index,
          onSelect: (_) {},
          sectionLabel: label,
          userName: 'Sara Hansen',
          body: body,
        ),
      );
    });
  }

  // ---- Alternate Stitch variants ----
  testWidgets('login_sign_up', (tester) async {
    await renderScreen(
      tester,
      name: 'login_sign_up',
      scale: 588 / 390,
      logicalHeight: 1061,
      screen: const AuthHubScreen(),
      after: (t) async {
        await t.enterText(
          find.byKey(const Key('hub_email')),
          'sara.hansen@example.no',
        );
        await t.enterText(
          find.byKey(const Key('hub_password')),
          'FjordOslo2025!',
        );
        await t.pump();
      },
    );
  });

  testWidgets('splash_onboarding', (tester) async {
    await renderScreen(
      tester,
      name: 'splash_onboarding',
      scale: 487 / 390,
      logicalHeight: 702,
      screen: const IntroOnboardingScreen(),
    );
  });

  testWidgets('choose_your_ride_oslo_s_to_osl', (tester) async {
    const oslo = Place(
      id: 'oslo-s',
      name: 'Oslo S',
      address: 'Jernbanetorget',
      position: LatLng(59.9110, 10.7528),
      kind: PlaceKind.transit,
    );
    const airport = Place(
      id: 'osl',
      name: 'Oslo Airport (OSL)',
      address: 'Gardermoen',
      position: LatLng(60.1939, 11.1004),
      kind: PlaceKind.airport,
    );
    await renderScreen(
      tester,
      name: 'choose_your_ride_oslo_s_to_osl',
      scale: 557 / 390,
      logicalHeight: 1120,
      mapAsset: DesignAssets.mapA,
      overrides: [
        ...qaOverrides(),
        tripPlanProvider.overrideWith(
          () => PresetPlan(
            pickup: oslo,
            dropoff: airport,
            vehicle: VehicleChoice.estate,
          ),
        ),
        fareRepositoryProvider.overrideWithValue(QaFare()),
      ],
      screen: const FleetsScreen(),
    );
  });
}
