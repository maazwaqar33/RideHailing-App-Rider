import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../core/formatting/formatters.dart';
import '../../../mock/mock_nearby_cars.dart';
import '../../../shared/app_map.dart';
import '../../../shared/glass.dart';
import '../../../shared/nav_scaffold.dart';
import '../../../shared/stitch.dart';
import '../../map/application/map_providers.dart';
import '../../rides/domain/ride_models.dart';
import 'tracking_common.dart';

/// Stitch `searching_for_driver` (status `requested` / `offered`).
///
/// Real: pickup/drop-off, payment method, distance, duration, fare estimate and the elapsed time
/// since the request. The radar animation, the "Demo car" beacon (mock nearby cars) and the
/// progress filament are decorative. Nothing here is a real dispatch ETA.
class SearchingView extends ConsumerWidget {
  const SearchingView({
    super.key,
    required this.ride,
    required this.now,
    required this.onCancel,
  });

  final Ride ride;

  /// Ticks once a second; only the elapsed-time label listens to it.
  final ValueListenable<DateTime> now;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offered = ride.status == RideStatus.offered;
    final cars = ref.watch(nearbyCarsProvider).asData?.value ?? const [];
    final pad = MediaQuery.paddingOf(context);
    final method = PaymentMethodType.parse(ride.payment.method);
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: kHeaderHeight + pad.top),
      child: Column(
        children: [
          SizedBox(
            height: 540,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: NordicColors.surface,
                    child: AppMap(
                      center: ride.pickup.latLng,
                      zoom: 14.5,
                      interactive: false,
                      backgroundColor: NordicColors.surface,
                      markers: [
                        for (final c in carsAround(ride.pickup.latLng, cars))
                          nearbyCarMarker(c.position, c.etaMinutes),
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
                            Tw.a(NordicColors.primary, 0.35),
                            Tw.a(NordicColors.primary, 0.05),
                            NordicColors.surface,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(child: Center(child: _Radar())),
                ),
                if (cars.isNotEmpty)
                  Positioned(
                    top: 100,
                    right: 24,
                    child: _BeaconPill('Nearby car · ${cars[0].etaMinutes} min'),
                  ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: GlassPill(
                    key: const Key('searching_card'),
                    radius: 12,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: Tw.a(
                                              NordicColors.secondary,
                                              0.3,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: NordicColors.secondary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          offered
                                              ? 'Waiting for a driver to accept'
                                              : 'Searching for a driver...',
                                          style: NordicText.titleSm.copyWith(
                                            color: NordicColors.onSurface,
                                            fontWeight: FontWeight.w600,
                                            height: 1.25,
                                          ),
                                        ),
                                        Text(
                                          offered
                                              ? 'Your ride was offered to a driver'
                                              : 'Your request is with dispatch',
                                          style: NordicText.labelSm.copyWith(
                                            color:
                                                NordicColors.onSurfaceVariant,
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
                                color: NordicColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: ValueListenableBuilder<DateTime>(
                                valueListenable: now,
                                builder: (context, t, _) {
                                  final elapsed = ride.requestedAt == null
                                      ? Duration.zero
                                      : t.difference(ride.requestedAt!);
                                  return Text(
                                    '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                                    style: NordicText.labelSm.copyWith(
                                      color: NordicColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 4,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: NordicColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: const Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: 0.4,
                              heightFactor: 1,
                              child: ColoredBox(color: NordicColors.secondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SheetShell(
            radius: 12,
            overlap: 24,
            shadow: Tw.xl,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Text(
                                  'Ride request #${ride.id}',
                                  key: const Key('ride_title'),
                                  style: NordicText.headlineSm.copyWith(
                                    color: NordicColors.onSurface,
                                    letterSpacing: 20 * -0.025,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: NordicColors.secondaryContainer,
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Text(
                                    ride.status.label,
                                    style: NordicText.labelSm.copyWith(
                                      color: NordicColors.onSecondaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your request is waiting for a driver',
                              style: NordicText.bodySm.copyWith(
                                color: NordicColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            rideTotal(ride),
                            key: const Key('searching_fare'),
                            style: NordicText.currencyDisplay.copyWith(
                              color: NordicColors.primary,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Estimated fare',
                            style: NordicText.labelSm.copyWith(
                              color: NordicColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: NordicColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: NordicColors.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    color: Tw.a(
                                      NordicColors.outlineVariant,
                                      0.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: NordicColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _routeNode('PICKUP', ride.pickup.title),
                                const SizedBox(height: 12),
                                _routeNode('DROP-OFF', ride.dropoff.title),
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
                        child: _InfoChip(
                          icon: paymentIcon(ride),
                          label: method.label,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoChip(
                          icon: Symbols.straighten,
                          label: Fmt.distance(ride.distanceMeters),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoChip(
                          icon: Symbols.schedule,
                          label: '~${Fmt.duration(ride.durationSeconds)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: NordicColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: NordicColors.onTertiaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: MIcon(
                                  Symbols.smartphone,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              method.label,
                              key: const Key('payment_demo_label'),
                              style: NordicText.labelLg.copyWith(
                                color: NordicColors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Not charged',
                          style: NordicText.labelSm.copyWith(
                            color: NordicColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    key: const Key('cancel_request'),
                    onTap: onCancel,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      decoration: BoxDecoration(
                        color: NordicColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const MIcon(
                            Symbols.close,
                            size: 18,
                            lh: 28,
                            color: NordicColors.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cancel request',
                            style: NordicText.titleSm.copyWith(
                              color: NordicColors.onSurface,
                              fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  static Widget _routeNode(String label, String title) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: NordicText.labelSm.copyWith(
          color: NordicColors.onSurfaceVariant,
          letterSpacing: 10 * 0.05,
        ),
      ),
      Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: NordicText.titleSm.copyWith(
          color: NordicColors.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

/// Radar of `searching_for_driver`: three teal rings and the "you are here" pin. Decorative.
class _Radar extends StatefulWidget {
  const _Radar();

  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 320 + 12 * _c.value,
          height: 320 + 12 * _c.value,
          decoration: BoxDecoration(
            color: Tw.a(NordicColors.secondaryFixed, 0.09),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 224,
          height: 224,
          decoration: BoxDecoration(
            color: Tw.a(NordicColors.secondary, 0.1),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 144,
          height: 144,
          decoration: BoxDecoration(
            color: Tw.a(NordicColors.secondaryContainer, 0.25),
            shape: BoxShape.circle,
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Tw.a(NordicColors.primary, 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Elevated(
                  shadows: Tw.lg,
                  circle: true,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: NordicColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: MIcon(
                        Symbols.electric_car,
                        size: 18,
                        fill: 1,
                        color: NordicColors.secondaryFixed,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              child: Elevated(
                shadows: Tw.sm,
                radius: 9999,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: NordicColors.primary,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    'YOU ARE HERE',
                    style: NordicText.labelSm.copyWith(
                      color: Colors.white,
                      letterSpacing: 10 * 0.025,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _BeaconPill extends StatelessWidget {
  const _BeaconPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Elevated(
    shadows: Tw.md,
    radius: 9999,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Tw.a(NordicColors.surfaceContainerLowest, 0.95),
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
          const SizedBox(width: 4),
          Text(
            label,
            style: NordicText.labelSm.copyWith(
              color: NordicColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: NordicColors.surfaceContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        MIcon(icon, size: 20, color: NordicColors.secondary),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: NordicText.labelSm.copyWith(
            color: NordicColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
