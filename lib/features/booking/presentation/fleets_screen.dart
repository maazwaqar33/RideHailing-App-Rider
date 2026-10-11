import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/network/api_exception.dart';
import '../../../mock/mock_nearby_cars.dart';
import '../../../shared/app_map.dart';
import '../../../shared/nav_scaffold.dart';
import '../../../shared/stitch.dart';
import '../../../shared/widgets.dart' show InlineError;
import '../../fare/domain/fare_models.dart';
import '../../map/application/map_providers.dart';
import '../../map/domain/map_models.dart';

/// Stitch `choose_your_ride_oslo_s_to_osl` ("Available Fleets"): the detailed vehicle list with
/// route chips, per-class highlights and a sticky "Request" bar. It is the alternate layout of
/// the ride chooser and is reached from the layers button on the ride-selection screen
/// (`/fleets`); both screens write the same trip plan and continue to Confirm and Pay.
///
/// Real: route, fare (one fare for every vehicle), seats from the vehicle choice. DEMO: class
/// descriptions, bag counts, "Free Wi-Fi" / "Silent EV" highlights, vehicle pictures, ETAs
/// (mock nearby cars), the "100% EV Zero Emission" chip and the Winter Ready card.
class FleetsScreen extends ConsumerWidget {
  const FleetsScreen({super.key});

  static const _photos = {
    VehicleChoice.sedan: DemoPhotos.carStandard,
    VehicleChoice.estate: DemoPhotos.carComfort,
    VehicleChoice.van: DemoPhotos.carVan,
  };

  static const _descriptions = {
    VehicleChoice.sedan: 'Camry or similar',
    VehicleChoice.estate: 'Polestar 2 or Executive EV',
    VehicleChoice.van: 'Mercedes EQV or similar',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(tripPlanProvider);
    final route = ref.watch(routeProvider);
    final fare = ref.watch(fareEstimateProvider);
    final cars =
        ref.watch(nearbyCarsProvider).asData?.value ?? const <NearbyCar>[];

    Widget scaffold(Widget body) => Scaffold(
      backgroundColor: NordicColors.surface,
      body: Column(
        children: [
          StitchBackHeader(
            title: 'Choose Your Ride',
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          Expanded(child: body),
        ],
      ),
    );

    if (!plan.isComplete) {
      return scaffold(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose a pickup and destination first.',
                style: NordicText.bodyMd,
              ),
              const SizedBox(height: 12),
              StitchButton(
                label: 'Search destination',
                onPressed: () => context.go('/search'),
              ),
            ],
          ),
        ),
      );
    }

    final routeInfo = route.asData?.value;
    final estimate = fare.asData?.value;
    final canContinue = estimate != null;
    final selected = plan.vehicle;
    final pickup = plan.pickup!;
    final dropoff = plan.dropoff!;
    final points = routeInfo?.points ?? [pickup.position, dropoff.position];

    return scaffold(
      Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: const Key('fleets_scroll'),
              child: Column(
                children: [
                  SizedBox(
                    height: 176,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(
                            color: NordicColors.surfaceContainerHigh,
                            child: AppMap(
                              center: pickup.position,
                              interactive: false,
                              fitMaxZoom: 13.6,
                              fitPoints: [pickup.position, dropoff.position],
                              fitPadding: const EdgeInsets.fromLTRB(
                                40,
                                70,
                                40,
                                20,
                              ),
                              routePoints: points,
                              markers: [
                                for (final c in carsAround(
                                  pickup.position,
                                  cars,
                                ))
                                  nearbyCarMarker(c.position, c.etaMinutes),
                                pickupMarker(pickup.position),
                                dropoffMarker(dropoff.position),
                              ],
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Tw.a(NordicColors.primary, 0.3),
                                    Tw.a(NordicColors.primary, 0),
                                    NordicColors.surface,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 16,
                          right: 16,
                          child: Elevated(
                            shadows: Tw.md,
                            radius: 12,
                            child: BackdropBlur(
                              radius: 12,
                              blur: 12,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                color: Tw.a(NordicColors.surface, 0.9),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              color: NordicColors.secondary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'ESTIMATED ROUTE',
                                                  style: NordicText.labelSm
                                                      .copyWith(
                                                        color: NordicColors
                                                            .onSurfaceVariant,
                                                        letterSpacing:
                                                            10 * 0.05,
                                                      ),
                                                ),
                                                Text(
                                                  '${pickup.name} → ${dropoff.name}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: NordicText.titleSm
                                                      .copyWith(
                                                        color: NordicColors
                                                            .onSurface,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const MIcon(
                                            Symbols.navigation,
                                            size: 16,
                                            lh: 16,
                                            color: NordicColors.secondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Straight line',
                                            style: NordicText.labelMd.copyWith(
                                              color: NordicColors.secondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _RouteCard(
                            distance: routeInfo == null
                                ? '...'
                                : Fmt.distance(routeInfo.distanceMeters),
                            duration: routeInfo == null
                                ? '...'
                                : Fmt.duration(routeInfo.durationSeconds),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Available Fleets',
                                  style: NordicText.titleMd.copyWith(
                                    color: NordicColors.onSurface,
                                  ),
                                ),
                                Text(
                                  'Tap to choose',
                                  style: NordicText.labelSm.copyWith(
                                    color: NordicColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (fare.hasError) ...[
                            InlineError(
                              key: const Key('fare_error'),
                              message: fare.error is ApiException
                                  ? (fare.error as ApiException).message
                                  : 'We could not get a price. Check your connection and try again.',
                              onRetry: () =>
                                  ref.invalidate(fareEstimateProvider),
                            ),
                            const SizedBox(height: 14),
                          ],

                          for (final (i, v)
                              in VehicleChoice.values.indexed) ...[
                            if (i > 0) const SizedBox(height: 14),
                            _FleetCard(
                              choice: v,
                              selected: v == selected,
                              photo: _photos[v]!,
                              description: _descriptions[v]!,
                              etaMinutes: cars.length > i
                                  ? cars[i].etaMinutes
                                  : null,
                              estimate: estimate,
                              onTap: () => ref
                                  .read(tripPlanProvider.notifier)
                                  .setVehicle(v),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: NordicColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: NordicColors.surfaceContainerHigh,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: MIcon(
                                      Symbols.ac_unit,
                                      size: 20,
                                      color: NordicColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Winter Ready & Preheated',
                                        style: NordicText.titleSm.copyWith(
                                          color: NordicColors.onSurface,
                                        ),
                                      ),
                                      Text(
                                        'One fare applies to every vehicle; your choice is a preference.',
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Tw.a(NordicColors.surface, 0.95),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F2A4A),
                  blurRadius: 30,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Elevated(
                    shadows: Tw.lg,
                    radius: 12,
                    child: Opacity(
                      opacity: canContinue ? 1 : 0.5,
                      child: Material(
                        color: NordicColors.primary,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          key: const Key('continue_to_payment'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: canContinue
                              ? () => context.push('/confirm-pay')
                              : null,
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Row(
                                    children: [
                                      const MIcon(
                                        Symbols.electric_car,
                                        size: 22,
                                        color: NordicColors.secondaryFixed,
                                      ),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          estimate == null
                                              ? 'Getting your price...'
                                              : 'Request ${selected.title} · ${Money.format(estimate.totalMinor, estimate.currency)}',
                                          overflow: TextOverflow.ellipsis,
                                          style: NordicText.titleSm.copyWith(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const MIcon(
                                  Symbols.arrow_forward,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const MIcon(
                        Symbols.check_circle,
                        size: 14,
                        lh: 16,
                        color: NordicColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Cancel until the trip starts · Next step: Payment & confirmation',
                          textAlign: TextAlign.center,
                          style: NordicText.labelSm.copyWith(
                            color: NordicColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.distance, required this.duration});

  final String distance;
  final String duration;

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String text, {bool strong = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: strong
            ? NordicColors.secondaryContainer.withValues(alpha: 0.6)
            : NordicColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MIcon(
            icon,
            size: 16,
            lh: 16,
            color: strong
                ? NordicColors.onSecondaryContainer
                : NordicColors.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: NordicText.labelMd.copyWith(
              color: strong
                  ? NordicColors.onSecondaryContainer
                  : NordicColors.onSurface,
              fontWeight: strong ? FontWeight.w600 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return Elevated(
      shadows: Tw.sm,
      radius: 12,
      child: Container(
        key: const Key('route_pill'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NordicColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const MIcon(
                        Symbols.eco,
                        size: 20,
                        fill: 1,
                        color: NordicColors.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ECO CORRIDOR',
                        style: NordicText.labelMd.copyWith(
                          color: NordicColors.secondary,
                          letterSpacing: 12 * 0.05,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Oslo area',
                    style: NordicText.labelSm.copyWith(
                      color: NordicColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                chip(Symbols.distance, '$distance (est.)'),
                chip(Symbols.schedule, duration),
                chip(Symbols.bolt, '100% EV Zero Emission', strong: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FleetCard extends StatelessWidget {
  const _FleetCard({
    required this.choice,
    required this.selected,
    required this.photo,
    required this.description,
    required this.etaMinutes,
    required this.estimate,
    required this.onTap,
  });

  final VehicleChoice choice;
  final bool selected;
  final String photo;
  final String description;
  final int? etaMinutes;
  final FareEstimate? estimate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isVan = choice == VehicleChoice.van;
    final isComfort = choice == VehicleChoice.estate;
    final highlight = switch (choice) {
      VehicleChoice.sedan => null,
      VehicleChoice.estate => ('Silent EV & Heated Seats', Symbols.air),
      VehicleChoice.van => ('Large Luggage Capacity', Symbols.workspaces),
    };
    final card = Container(
      key: Key('vehicle_${choice.apiType}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected
            ? NordicColors.secondaryContainer.withValues(alpha: 0.2)
            : NordicColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Elevated(
                      shadows: selected ? Tw.sm : const [],
                      radius: 12,
                      child: Container(
                        width: 72,
                        height: 52,
                        decoration: BoxDecoration(
                          color: selected
                              ? NordicColors.surfaceContainerHigh
                              : NordicColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          photo,
                          fit: BoxFit.cover,
                          semanticLabel: '${choice.title} vehicle',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                choice.title,
                                style: NordicText.titleSm.copyWith(
                                  color: NordicColors.onSurface,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (etaMinutes != null)
                                Container(
                                  key: Key('eta_${choice.apiType}'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? NordicColors.secondary.withValues(
                                            alpha: 0.15,
                                          )
                                        : NordicColors.surfaceContainer,
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Text(
                                    '$etaMinutes min',
                                    style: NordicText.labelSm.copyWith(
                                      color: selected
                                          ? NordicColors.secondary
                                          : NordicColors.onSurfaceVariant,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NordicText.bodySm.copyWith(
                              color: selected
                                  ? NordicColors.onSurface
                                  : NordicColors.onSurfaceVariant,
                              fontWeight: selected
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  estimate == null
                      ? const SizedBox(
                          width: 64,
                          child: NordicSkeleton(height: 20, radius: 4),
                        )
                      : Text(
                          Money.format(
                            estimate!.totalMinor,
                            estimate!.currency,
                          ),
                          key: Key('price_${choice.apiType}'),
                          style: NordicText.currencyDisplay.copyWith(
                            color: NordicColors.onSurface,
                          ),
                        ),
                  Text(
                    selected ? 'Incl. fees & tax' : 'Estimated fare',
                    style: NordicText.labelSm.copyWith(
                      color: selected
                          ? NordicColors.secondary
                          : NordicColors.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (highlight != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isComfort
                      ? NordicColors.surfaceContainerLowest.withValues(
                          alpha: 0.8,
                        )
                      : NordicColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MIcon(
                      highlight.$2,
                      size: 16,
                      lh: 16,
                      color: isComfort
                          ? NordicColors.secondary
                          : NordicColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      highlight.$1,
                      style: NordicText.labelMd.copyWith(
                        color: NordicColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Wrap(
                  spacing: 12,
                  children: [
                    _Spec(
                      isVan ? Symbols.group : Symbols.person,
                      '${choice.seats} seats',
                    ),
                    _Spec(
                      Symbols.luggage,
                      isVan ? '${choice.bags}+ bags' : '${choice.bags} bags',
                    ),
                    if (isComfort)
                      const _Spec(Symbols.wifi, 'Free Wi-Fi', accent: true),
                    if (isVan) const _Spec(Symbols.accessible, 'Extra space'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: selected
                      ? NordicColors.secondary
                      : NordicColors.surfaceContainer,
                  shape: BoxShape.circle,
                  boxShadow: selected ? Tw.sm : null,
                ),
                child: Center(
                  child: MIcon(
                    Symbols.check,
                    size: 14,
                    color: selected ? Colors.white : Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Elevated(shadows: selected ? Tw.md : Tw.sm, radius: 12, child: card),
          if (selected)
            Positioned(
              top: -10,
              right: 16,
              child: Elevated(
                shadows: Tw.sm,
                radius: 9999,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: NordicColors.secondary,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MIcon(
                        Symbols.star,
                        size: 12,
                        lh: 14,
                        fill: 1,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Best Choice',
                        style: NordicText.labelSm.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Spec extends StatelessWidget {
  const _Spec(this.icon, this.label, {this.accent = false});

  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent
        ? NordicColors.secondary
        : NordicColors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MIcon(icon, size: 16, lh: 20, color: color),
        const SizedBox(width: 4),
        Text(label, style: NordicText.labelMd.copyWith(color: color)),
      ],
    );
  }
}
