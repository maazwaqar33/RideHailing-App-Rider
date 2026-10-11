import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../core/formatting/formatters.dart';
import '../../../shared/app_map.dart';
import '../../../shared/stitch.dart';
import '../../auth/application/session_controller.dart';
import '../../rides/application/ride_providers.dart';
import '../application/map_providers.dart';
import '../data/local_places_store.dart';
import '../domain/map_models.dart';

/// Stitch `home_oslo_map`: a 477 px map with floating pills, nearby (MOCK) cars and map controls,
/// and the white bottom sheet with greeting, "Where to?", saved places and recent destinations.
class RideTab extends ConsumerStatefulWidget {
  const RideTab({super.key});

  @override
  ConsumerState<RideTab> createState() => _RideTabState();
}

class _RideTabState extends ConsumerState<RideTab> {
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tripPlanProvider.notifier).ensurePickup();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 5) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  static String _dayName(DateTime d) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][d.weekday - 1];

  @override
  Widget build(BuildContext context) {
    final start = ref.watch(startLocationProvider);
    final session = ref.watch(sessionControllerProvider);
    final firstName = session is SessionAuthenticated
        ? session.user.firstName
        : 'there';
    final cars =
        ref.watch(nearbyCarsProvider).asData?.value ?? const <NearbyCar>[];
    final active = ref.watch(activeRideProvider).asData?.value;
    final store = ref.watch(localPlacesStoreProvider);
    final plan = ref.watch(tripPlanProvider);
    final now = DateTime.now();
    final startLoc = start.asData?.value;
    final centre = plan.pickup?.position ?? startLoc?.position;

    final markers = <Marker>[
      for (final (i, c) in cars.indexed)
        nearbyCarMarker(
          c.position,
          c.etaMinutes,
          iconColor: i == 2 ? NordicColors.secondary : NordicColors.primary,
        ),
      if (plan.pickup != null) pickupMarker(plan.pickup!.position),
    ];

    final recents = store.recents();
    final home = store.saved(SavedSlot.home);
    final work = store.saved(SavedSlot.work);

    return SingleChildScrollView(
      key: const Key('ride_tab_scroll'),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 477,
            child: ColoredBox(
              color: NordicColors.surfaceContainer,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: centre == null
                        ? const Center(child: CircularProgressIndicator())
                        : AppMap(
                            controller: _mapController,
                            center: centre,
                            zoom: 12.8,
                            markers: markers,
                          ),
                  ),
                  // Fjord water & map tone scrim: from-primary/10 via-transparent to-primary/25
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Tw.a(NordicColors.primary, 0.1),
                              Tw.a(NordicColors.primary, 0),
                              Tw.a(NordicColors.primary, 0.25),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Elevated(
                                shadows: Tw.md,
                                radius: 9999,
                                child: BackdropBlur(
                                  radius: 9999,
                                  blur: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    color: Tw.a(
                                      NordicColors.surfaceContainerLowest,
                                      0.9,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: NordicColors.secondary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Oslo Sentrum',
                                          style: NordicText.labelMd.copyWith(
                                            color: NordicColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '•',
                                          style: NordicText.labelSm.copyWith(
                                            color: NordicColors.outlineVariant,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '100% Electric Fleet',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: NordicText.labelSm.copyWith(
                                              color:
                                                  NordicColors.onSurfaceVariant,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Elevated(
                              shadows: Tw.md,
                              radius: 9999,
                              child: BackdropBlur(
                                radius: 9999,
                                blur: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  color: Tw.a(
                                    NordicColors.surfaceContainerLowest,
                                    0.9,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const MIcon(
                                        Symbols.eco,
                                        size: 16,
                                        color: NordicColors.secondary,
                                        lh: 24,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '0g CO₂',
                                        key: const Key('location_pill'),
                                        style: NordicText.labelMd.copyWith(
                                          color: NordicColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (startLoc?.bannerMessage != null) ...[
                          const SizedBox(height: 8),
                          NordicBanner(
                            key: const Key('location_banner'),
                            message: startLoc!.bannerMessage!,
                            actionLabel: 'Retry location',
                            onAction: () =>
                                ref.invalidate(startLocationProvider),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 20,
                    child: Column(
                      children: [
                        _RoundControl(
                          key: const Key('recenter'),
                          icon: Symbols.my_location,
                          color: NordicColors.primary,
                          onTap: () {
                            final p = plan.pickup?.position ?? centre;
                            if (p != null) _mapController.move(p, 14.5);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 477 - 20),
              Elevated(
                shadows: const [
                  BoxShadow(
                    color: Color(0x140F2A4A),
                    blurRadius: 30,
                    offset: Offset(0, -8),
                  ),
                ],
                radius: 28,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  decoration: const BoxDecoration(
                    color: NordicColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: Tw.a(NordicColors.outlineVariant, 0.6),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_dayName(now)}, ${Fmt.time(now)}',
                                  style: NordicText.labelMd.copyWith(
                                    color: NordicColors.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${_greeting(now)}, $firstName',
                                  key: const Key('home_greeting'),
                                  style: NordicText.headlineSm.copyWith(
                                    color: NordicColors.primary,
                                    letterSpacing: 20 * -0.025,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: NordicColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const MIcon(
                                  Symbols.location_on,
                                  size: 14,
                                  lh: 20,
                                  color: NordicColors.secondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Oslo',
                                  style: NordicText.labelSm.copyWith(
                                    color: NordicColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (active != null) ...[
                        const SizedBox(height: 16),
                        _ActiveRideCard(
                          key: const Key('active_ride_card'),
                          label: active.status.label,
                          route:
                              '${active.pickup.title} to ${active.dropoff.title}',
                          onTap: () => context.push('/ride/${active.id}'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      GestureDetector(
                        key: const Key('where_to'),
                        onTap: () => context.push('/search'),
                        child: Elevated(
                          shadows: Tw.sm,
                          radius: 12,
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: NordicColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: const BoxDecoration(
                                        color: NordicColors.secondaryContainer,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: MIcon(
                                          Symbols.search,
                                          size: 18,
                                          color:
                                              NordicColors.onSecondaryContainer,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Text(
                                      'Where to?',
                                      style: NordicText.titleSm.copyWith(
                                        color: NordicColors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Container(
                                      height: 20,
                                      width: 1,
                                      color: Tw.a(
                                        NordicColors.outlineVariant,
                                        0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            NordicColors.surfaceContainerLowest,
                                        borderRadius: BorderRadius.circular(
                                          9999,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const MIcon(
                                            Symbols.bolt,
                                            size: 16,
                                            fill: 1,
                                            color: NordicColors.secondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Now',
                                            style: NordicText.labelSm.copyWith(
                                              color: NordicColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SAVED PLACES',
                            style: NordicText.labelMd.copyWith(
                              color: NordicColors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 12 * 0.05,
                            ),
                          ),
                          GestureDetector(
                            key: const Key('saved_edit'),
                            onTap: () => context.go('/profile'),
                            child: Text(
                              'Edit',
                              style: NordicText.labelSm.copyWith(
                                color: NordicColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _SavedTile(
                              slot: SavedSlot.home,
                              place: home,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SavedTile(
                              slot: SavedSlot.work,
                              place: work,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          recents.isEmpty
                              ? 'SUGGESTED DESTINATIONS'
                              : 'RECENT DESTINATIONS',
                          style: NordicText.labelMd.copyWith(
                            color: NordicColors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 12 * 0.05,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _RecentList(places: recents),
                      const SizedBox(height: 16 + 4),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: NordicColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: NordicColors.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: MIcon(
                                      Symbols.contactless,
                                      size: 20,
                                      color: NordicColors.onTertiaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Design copy: "Vipps Quick-Pay Ready / +47 982 •• •21" (Vipps is not integrated).
                                    Text(
                                      'Pay with cash or card',
                                      style: NordicText.labelMd.copyWith(
                                        color: NordicColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Secure and frictionless payments',
                                      style: NordicText.bodySm.copyWith(
                                        color: NordicColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const MIcon(
                              Symbols.verified,
                              size: 20,
                              color: NordicColors.secondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Elevated(
      shadows: Tw.lg,
      circle: true,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: NordicColors.surfaceContainerLowest,
          shape: BoxShape.circle,
        ),
        child: Center(child: MIcon(icon, size: 24, color: color)),
      ),
    ),
  );
}

class _ActiveRideCard extends StatelessWidget {
  const _ActiveRideCard({
    super.key,
    required this.label,
    required this.route,
    required this.onTap,
  });

  final String label;
  final String route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NordicColors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const MIcon(
              Symbols.directions_car,
              size: 24,
              color: NordicColors.secondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ride in progress: $label',
                    style: NordicText.titleSm.copyWith(color: Colors.white),
                  ),
                  Text(
                    route,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NordicText.bodySm.copyWith(
                      color: NordicColors.inversePrimary,
                    ),
                  ),
                ],
              ),
            ),
            const MIcon(Symbols.arrow_forward, size: 24, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _SavedTile extends ConsumerWidget {
  const _SavedTile({required this.slot, required this.place});

  final SavedSlot slot;
  final Place? place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHome = slot == SavedSlot.home;
    return GestureDetector(
      key: Key('saved_${slot.name}'),
      onTap: () {
        if (place != null) {
          ref.read(tripPlanProvider.notifier).setDropoff(place!);
          context.push('/choose-ride');
        } else {
          context.push('/search?set=${slot.name}');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NordicColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Elevated(
              shadows: Tw.sm,
              circle: true,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: NordicColors.surfaceContainerLowest,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: MIcon(
                    isHome ? Symbols.home : Symbols.apartment,
                    size: 20,
                    fill: 1,
                    color: NordicColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHome ? 'Home' : 'Work',
                    style: NordicText.titleSm.copyWith(
                      color: NordicColors.primary,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  Text(
                    place?.name ?? 'Set location',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NordicText.bodySm.copyWith(
                      color: NordicColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentList extends ConsumerWidget {
  const _RecentList({required this.places});

  final List<Place> places;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions =
        ref.watch(_suggestionsProvider).asData?.value ?? const <Place>[];
    final list = places.isEmpty
        ? suggestions.take(3).toList()
        : places.take(3).toList();
    return Column(
      children: [
        for (final (i, p) in list.indexed) ...[
          if (i > 0) const SizedBox(height: 6),
          InkWell(
            key: Key('recent_${p.id}'),
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              ref.read(tripPlanProvider.notifier).setDropoff(p);
              context.push('/choose-ride');
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: NordicColors.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: MIcon(
                        places.isEmpty ? Symbols.place : Symbols.schedule,
                        size: 18,
                        color: NordicColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NordicText.titleSm.copyWith(
                            color: NordicColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          p.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NordicText.bodySm.copyWith(
                            color: NordicColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const MIcon(
                    Symbols.north_east,
                    size: 20,
                    color: NordicColors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

final _suggestionsProvider = FutureProvider.autoDispose<List<Place>>((ref) {
  final plan = ref.watch(tripPlanProvider);
  return ref
      .watch(placeSearchRepositoryProvider)
      .suggestions(near: plan.pickup?.position);
});
