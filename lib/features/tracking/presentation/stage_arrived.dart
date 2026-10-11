import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../core/formatting/formatters.dart';
import '../../../mock/demo_content.dart';
import '../../../shared/glass.dart';
import '../../../shared/nav_scaffold.dart';
import '../../../shared/stitch.dart';
import '../../rides/domain/ride_models.dart';
import '../domain/driver_telemetry.dart';
import 'tracking_common.dart';
import 'tracking_map.dart';

/// Stitch `live_trip_driver_arrived_pin_4821` (status `arrived`).
///
/// Real: driver name, vehicle, plate, pickup/drop-off, payment method, fare. DEMO: portrait,
/// rating + ride count, and the security PIN (generated locally; the backend has no PIN).
class DriverArrivedView extends StatelessWidget {
  const DriverArrivedView({
    super.key,
    required this.ride,
    required this.positions,
    required this.onCancel,
  });

  final Ride ride;

  /// Mock driver position, updated once a second. Only the map section listens to it, so the
  /// sheet below is not rebuilt every tick.
  final ValueListenable<DriverPosition?> positions;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final driver = ride.driver;
    final vehicle = ride.vehicle;
    final name = driver?.firstName ?? 'Your driver';
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: kHeaderHeight + pad.top),
      child: Column(
        children: [
          ValueListenableBuilder<DriverPosition?>(
            valueListenable: positions,
            builder: (context, telemetry, _) {
              return SizedBox(
                height: 288,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: TrackingMap(
                        ride: ride,
                        telemetry: telemetry,
                        mode: TrackingMapMode.arrived,
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
                      top: 16,
                      left: 16,
                      child: GlassPill(
                        shadows: Tw.md,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
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
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 210),
                              child: Text(
                                '${ride.pickup.title} → ${ride.dropoff.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                key: const Key('eta_pill'),
                                style: NordicText.labelMd.copyWith(
                                  color: NordicColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              Fmt.duration(ride.durationSeconds),
                              style: NordicText.labelSm.copyWith(
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
              );
            },
          ),
          SheetShell(
            overlap: 24,
            color: NordicColors.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 4),
                    child: SheetHandle(color: NordicColors.outlineVariant),
                  ),
                  const SizedBox(height: 24),
                  Elevated(
                    shadows: Tw.sm,
                    radius: 12,
                    child: Container(
                      key: const Key('status_headline'),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NordicColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: NordicColors.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: MIcon(
                                Symbols.near_me,
                                size: 24,
                                fill: 1,
                                color: NordicColors.onSecondaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Driver arrived',
                                      key: const Key('status_title'),
                                      style: NordicText.headlineSm.copyWith(
                                        color: NordicColors.primary,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 20 * -0.025,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: NordicColors.secondaryContainer,
                                        borderRadius: BorderRadius.circular(
                                          9999,
                                        ),
                                      ),
                                      child: Text(
                                        'LIVE',
                                        style: NordicText.labelSm.copyWith(
                                          color:
                                              NordicColors.onSecondaryContainer,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 10 * 0.05,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$name is waiting at ${ride.pickup.title}.',
                                  maxLines: 2,
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
                  ),
                  const SizedBox(height: 24),
                  Elevated(
                    shadows: Tw.md,
                    radius: 12,
                    child: Container(
                      key: const Key('pin_card'),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NordicColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const MIcon(
                                      Symbols.verified_user,
                                      size: 16,
                                      lh: 24,
                                      color: NordicColors.secondaryFixed,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'SECURITY PIN',
                                      style: NordicText.labelSm.copyWith(
                                        color: NordicColors.secondaryFixed,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 10 * 0.05,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Share with $name before entering car',
                                  style: NordicText.bodySm.copyWith(
                                    color: NordicColors.primaryFixedDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: NordicColors.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              demoSecurityPin(ride.id),
                              key: const Key('demo_pin'),
                              style: NordicText.headlineLg.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 28 * 0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Elevated(
                    shadows: Tw.sm,
                    radius: 12,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NordicColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        const PhotoCircle(
                                          DemoPhotos.driverArrived,
                                          size: 56,
                                          shadows: Tw.sm,
                                          semanticLabel: 'Driver',
                                        ),
                                        Positioned(
                                          right: -4,
                                          bottom: -4,
                                          child: Elevated(
                                            shadows: Tw.sm,
                                            circle: true,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: NordicColors
                                                    .surfaceContainerLowest,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Container(
                                                width: 20,
                                                height: 20,
                                                decoration: const BoxDecoration(
                                                  color: NordicColors.secondary,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Center(
                                                  child: MIcon(
                                                    Symbols.electric_car,
                                                    size: 12,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  driver?.firstName ??
                                                      'Your driver',
                                                  key: const Key('driver_name'),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: NordicText.titleMd
                                                      .copyWith(
                                                        color: NordicColors
                                                            .primary,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const MIcon(
                                                Symbols.check_circle,
                                                size: 14,
                                                lh: 20,
                                                fill: 1,
                                                color: NordicColors.secondary,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          RatingLine(
                                            rating: DemoDriverProfile.rating,
                                            suffix:
                                                DemoDriverProfile.ridesArrived,
                                            starColor: const Color(0xFFF59E0B),
                                            gap: 4,
                                            style: NordicText.labelMd.copyWith(
                                              color:
                                                  NordicColors.onSurfaceVariant,
                                            ),
                                            ratingStyle: NordicText.labelMd
                                                .copyWith(
                                                  color: NordicColors.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasDriverPhone(ride))
                                    _RoundIcon(
                                      icon: Symbols.call,
                                      tooltip: 'Call driver',
                                      onTap: () => callDriver(context, ride),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          if (vehicle != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: NordicColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Elevated(
                                          shadows: Tw.sm,
                                          radius: 8,
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: NordicColors
                                                  .surfaceContainerLowest,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Center(
                                              child: MIcon(
                                                Symbols.directions_car,
                                                size: 20,
                                                color: NordicColors.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                vehicle.displayName.isEmpty
                                                    ? 'Assigned vehicle'
                                                    : vehicle.displayName,
                                                key: const Key('vehicle_name'),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: NordicText.titleSm
                                                    .copyWith(
                                                      color:
                                                          NordicColors.primary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              if (vehicle.colour != null &&
                                                  vehicle.colour!.isNotEmpty)
                                                Text(
                                                  vehicle.colour!,
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
                                  const SizedBox(width: 8),
                                  PlateTag(vehicle.plateNumber),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            MIcon(
                              paymentIcon(ride),
                              size: 16,
                              lh: 24,
                              color: NordicColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              paymentLabel(ride),
                              key: const Key('payment_demo_label'),
                              style: NordicText.bodySm.copyWith(
                                color: NordicColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          rideTotal(ride),
                          key: const Key('live_fare'),
                          style: NordicText.titleSm.copyWith(
                            color: NordicColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ride.status.canRiderCancel) ...[
                    const SizedBox(height: 8),
                    CancelRideButton(onCancel: onCancel),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: NordicColors.surfaceContainer,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: MIcon(icon, size: 20, color: NordicColors.primary),
        ),
      ),
    ),
  );
}
