import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/network/api_exception.dart';
import '../../../mock/demo_content.dart';
import '../../../shared/app_map.dart';
import '../../../shared/stitch.dart';
import '../../../shared/widgets.dart' show InlineError;
import '../../rides/application/ride_providers.dart';
import '../../rides/domain/ride_models.dart';
import 'trip_receipt_screen.dart';

/// Trip history (Stitch `trip_history_receipts`) from GET rides (the rider's own rides, newest
/// first, paginated).
///
/// Not in the API, so replaced: vehicle class label ("Comfort Electric"), Vipps / BankID text,
/// CO2 savings, toll lines, scheduled rides.
class TripsTab extends ConsumerStatefulWidget {
  const TripsTab({super.key});

  @override
  ConsumerState<TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends ConsumerState<TripsTab> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        ref.read(rideHistoryProvider.notifier).load();
      }
    });
    Future.microtask(
      () => ref.read(rideHistoryProvider.notifier).load(refresh: true),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rideHistoryProvider);
    final done = state.rides
        .where((r) => r.status == RideStatus.completed)
        .toList();
    final km = done.fold<int>(0, (a, r) => a + r.distanceMeters) / 1000;
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(rideHistoryProvider.notifier).load(refresh: true),
      child: ListView(
        key: const Key('trips_list'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OSLO MOBILITY HUB',
                      style: NordicText.labelSm.copyWith(
                        color: NordicColors.secondary,
                        letterSpacing: 10 * 0.05,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Trip Activity',
                      style: NordicText.headlineMd.copyWith(
                        color: NordicColors.onSurface,
                        letterSpacing: 24 * -0.025,
                      ),
                    ),
                  ],
                ),
                if (state.rides.isNotEmpty)
                  Elevated(
                    shadows: Tw.sm,
                    radius: 9999,
                    child: Container(
                      key: const Key('trips_count'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: NordicColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(9999),
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
                          const SizedBox(width: 8),
                          Text(
                            '${state.rides.length} Recent',
                            style: NordicText.labelMd.copyWith(
                              color: NordicColors.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              children: [
                if (state.loading && state.rides.isEmpty) ...[
                  for (var i = 0; i < 3; i++)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: NordicSkeleton(height: 120, radius: 12),
                    ),
                ] else if (state.error != null && state.rides.isEmpty)
                  SizedBox(
                    height: 300,
                    child: NordicErrorView(
                      message: state.error is ApiException
                          ? (state.error as ApiException).message
                          : 'We could not load your trips.',
                      onRetry: () => ref
                          .read(rideHistoryProvider.notifier)
                          .load(refresh: true),
                    ),
                  )
                else if (state.rides.isEmpty)
                  const _EmptyTrips()
                else ...[
                  for (final ride in state.rides)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: RideHistoryCard(ride: ride),
                    ),
                  Container(
                    key: const Key('trips_summary'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: NordicColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: Tw.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: NordicColors.secondaryFixed,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: MIcon(
                                    Symbols.forest,
                                    size: 20,
                                    color: NordicColors.onSecondaryFixed,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DemoClimate.summaryTitle,
                                      style: NordicText.labelMd.copyWith(
                                        color: NordicColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Saved ~${co2SavedKg((km * 1000).round())} kg CO₂ via electric rides (estimate)',
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
                        const SizedBox(width: 8),
                        Text(
                          DemoClimate.summaryBadge,
                          style: NordicText.titleSm.copyWith(
                            color: NordicColors.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (state.loading && state.rides.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: NordicLoader(),
                  ),
                if (state.error != null && state.rides.isNotEmpty)
                  InlineError(
                    message: 'Could not load more trips.',
                    onRetry: () =>
                        ref.read(rideHistoryProvider.notifier).load(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: NordicColors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: MIcon(
                Symbols.calendar_month,
                size: 36,
                color: NordicColors.secondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No trips yet',
            key: const Key('trips_empty'),
            style: NordicText.titleMd.copyWith(
              color: NordicColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your completed and cancelled rides will appear here.',
            style: NordicText.bodyMd.copyWith(
              color: NordicColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class RideHistoryCard extends ConsumerStatefulWidget {
  const RideHistoryCard({super.key, required this.ride});

  final Ride ride;

  @override
  ConsumerState<RideHistoryCard> createState() => _RideHistoryCardState();
}

class _RideHistoryCardState extends ConsumerState<RideHistoryCard> {
  bool _open = false;

  Ride get ride => widget.ride;

  void _openRide() => context.push(
    ride.status.isActive ? '/ride/${ride.id}' : '/trip/${ride.id}',
  );

  @override
  Widget build(BuildContext context) {
    final when = ride.completedAt ?? ride.cancelledAt ?? ride.requestedAt;
    final fare = ride.fare.payableMinor;
    final method = PaymentMethodType.parse(ride.payment.method);
    final withDriver = ride.driver != null && ride.vehicle != null;
    final currency = ride.fare.currency;
    final b = ride.fare.breakdown;
    return Elevated(
      key: Key('ride_card_${ride.id}'),
      shadows: Tw.md,
      radius: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: NordicColors.surfaceContainerLowest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: _openRide,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Elevated(
                                  shadows: Tw.sm,
                                  circle: true,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                      color: NordicColors.surfaceContainerHigh,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: MIcon(
                                        withDriver
                                            ? Symbols.local_taxi
                                            : Symbols.directions_car,
                                        size: 24,
                                        color: NordicColors.primary,
                                      ),
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
                                        '${ride.pickup.title} → ${ride.dropoff.title}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: NordicText.titleSm.copyWith(
                                          color: NordicColors.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          if (when != null) Fmt.dateTime(when),
                                          method.label,
                                        ].join(' • '),
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
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (fare != null)
                                Text(
                                  Money.format(fare, currency),
                                  style: NordicText.currencyDisplay.copyWith(
                                    color: NordicColors.primary,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              _StatusPill(ride.status),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: withDriver ? 16 : 8),
                      Padding(
                        padding: EdgeInsets.only(top: withDriver ? 8 : 8),
                        child: withDriver
                            ? Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const PhotoCircle(
                                          DemoPhotos.driverHistory,
                                          size: 28,
                                          semanticLabel: 'Driver',
                                        ),
                                        const SizedBox(width: 10),
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                ride.driver!.firstName,
                                                style: NordicText.labelMd
                                                    .copyWith(
                                                      color: NordicColors
                                                          .onSurface,
                                                    ),
                                              ),
                                              Text(
                                                '${ride.vehicle!.displayName} • ${ride.vehicle!.plateNumber}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: NordicText.labelSm
                                                    .copyWith(
                                                      color: NordicColors
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (ride.status.isActive)
                                    Text(
                                      'Track ride',
                                      style: NordicText.labelMd.copyWith(
                                        color: NordicColors.secondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  else
                                    GestureDetector(
                                      key: Key('receipt_toggle_${ride.id}'),
                                      onTap: () =>
                                          setState(() => _open = !_open),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              NordicColors.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Receipt details',
                                              style: NordicText.labelMd
                                                  .copyWith(
                                                    color:
                                                        NordicColors.secondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(width: 4),
                                            AnimatedRotation(
                                              turns: _open ? 0.5 : 0,
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              child: const MIcon(
                                                Symbols.expand_more,
                                                size: 16,
                                                color: NordicColors.secondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        MIcon(
                                          method == PaymentMethodType.cash
                                              ? Symbols.eco
                                              : Symbols.credit_card,
                                          size: 16,
                                          color: NordicColors.secondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '${method == PaymentMethodType.cash ? 'Zero-emission EV Ride' : method.label} • ${Fmt.distance(ride.distanceMeters)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: NordicText.labelSm.copyWith(
                                              color:
                                                  NordicColors.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (ride.status.isActive)
                                    Text(
                                      'Track ride',
                                      style: NordicText.labelMd.copyWith(
                                        color: NordicColors.secondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  else
                                    GestureDetector(
                                      key: Key('rebook_${ride.id}'),
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () =>
                                          rebookFromRide(context, ref, ride),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              'Re-book',
                                              style: NordicText.labelMd
                                                  .copyWith(
                                                    color: NordicColors.primary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                            const SizedBox(width: 4),
                                            const MIcon(
                                              Symbols.arrow_forward,
                                              size: 14,
                                              color: NordicColors.primary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_open && withDriver)
                Container(
                  key: Key('receipt_drawer_${ride.id}'),
                  color: NordicColors.surfaceContainerLow,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Elevated(
                        shadows: Tw.sm,
                        radius: 12,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 144,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: AppMap(
                                    center: ride.pickup.latLng,
                                    zoom: 12,
                                    interactive: false,
                                    fitPoints: [
                                      ride.pickup.latLng,
                                      ride.dropoff.latLng,
                                    ],
                                    fitPadding: const EdgeInsets.all(28),
                                    routePoints: [
                                      ride.pickup.latLng,
                                      ride.dropoff.latLng,
                                    ],
                                    markers: [
                                      pickupMarker(ride.pickup.latLng),
                                      dropoffMarker(ride.dropoff.latLng),
                                    ],
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            NordicColors.primary.withValues(
                                              alpha: 0.6,
                                            ),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 10,
                                  bottom: 10,
                                  child: Row(
                                    children: [
                                      const MIcon(
                                        Symbols.route,
                                        size: 14,
                                        color: NordicColors.secondaryFixed,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${Fmt.distance(ride.distanceMeters)} • ${Fmt.duration(ride.durationSeconds)}',
                                        style: NordicText.labelSm.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
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
                      const SizedBox(height: 16),
                      Elevated(
                        shadows: Tw.sm,
                        radius: 12,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: NordicColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              if (b != null) ...[
                                _DrawerLine(
                                  'Base fare + distance',
                                  Money.format(
                                    b.baseFareMinor + b.distanceChargeMinor,
                                    currency,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _DrawerLine(
                                  'Time charge',
                                  Money.format(b.timeChargeMinor, currency),
                                ),
                                const SizedBox(height: 8),
                                _DrawerLine(
                                  'Booking fee + tax',
                                  Money.format(
                                    b.bookingFeeMinor + b.taxMinor,
                                    currency,
                                  ),
                                ),
                              ],
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: NordicColors
                                                .onTertiaryContainer,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          method.label,
                                          style: NordicText.labelMd.copyWith(
                                            color: NordicColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      Money.format(fare ?? 0, currency),
                                      style: NordicText.titleSm.copyWith(
                                        color: NordicColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _DrawerButton(
                              key: Key('full_receipt_${ride.id}'),
                              icon: Symbols.receipt_long,
                              label: 'Full receipt',
                              onTap: _openRide,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _DrawerButton(
                              key: Key('rebook_${ride.id}'),
                              icon: Symbols.repeat,
                              label: 'Re-book Ride',
                              primary: true,
                              onTap: () => rebookFromRide(context, ref, ride),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerLine extends StatelessWidget {
  const _DrawerLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: NordicText.labelSm.copyWith(
          color: NordicColors.onSurfaceVariant,
        ),
      ),
      Text(
        value,
        style: NordicText.labelSm.copyWith(
          color: NordicColors.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _DrawerButton extends StatelessWidget {
  const _DrawerButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Elevated(
      shadows: primary ? Tw.md : Tw.sm,
      radius: 8,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: primary
              ? NordicColors.primary
              : NordicColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MIcon(
              icon,
              size: 18,
              color: primary
                  ? NordicColors.secondaryFixed
                  : NordicColors.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NordicText.labelLg.copyWith(
                  color: primary ? Colors.white : NordicColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Status pill of the history card (`rounded-full bg-secondary-fixed`, label-sm semibold).
class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);

  final RideStatus status;

  @override
  Widget build(BuildContext context) {
    final cancelled = status == RideStatus.cancelled;
    final completed = status == RideStatus.completed;
    final bg = cancelled
        ? NordicColors.errorContainer
        : (completed
              ? NordicColors.secondaryFixed
              : NordicColors.surfaceContainerHigh);
    final fg = cancelled
        ? NordicColors.onErrorContainer
        : (completed
              ? NordicColors.onSecondaryFixed
              : NordicColors.onSurfaceVariant);
    return Container(
      key: Key('status_pill_${status.apiValue}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MIcon(
            cancelled
                ? Symbols.cancel
                : (completed ? Symbols.check_circle : Symbols.schedule),
            size: 13,
            lh: 14,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: NordicText.labelSm.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
