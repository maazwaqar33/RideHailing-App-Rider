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

/// Stitch `live_tracking_3_states` for `driver_en_route` and `in_progress`.
///
/// Real: status, driver first name, vehicle, plate, drop-off/pickup text, payment method and fare.
/// MOCK: driver position, route line and ETA/distance chip. DEMO: portrait, rating, trip counter,
/// "100% EV", seat/trunk/temperature chips and the security PIN (generated locally, the backend
/// has no PIN). The segmented control is a status display driven by the real ride status.
class LiveTrackingView extends StatelessWidget {
  const LiveTrackingView({
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

  bool get _inTrip => ride.status == RideStatus.inProgress;

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
          StageStrip(stage: _inTrip ? 2 : 0),
          ValueListenableBuilder<DriverPosition?>(
            valueListenable: positions,
            builder: (context, telemetry, _) {
              final eta = telemetry?.etaSeconds;
              return SizedBox(
                height: 400,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: TrackingMap(
                        ride: ride,
                        telemetry: telemetry,
                        mode: TrackingMapMode.live,
                        fitPadding: const EdgeInsets.fromLTRB(60, 90, 60, 80),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: GlassPill(
                        color: NordicColors.surface,
                        shadows: const [
                          BoxShadow(
                            color: Color(0x2E0F2A4A),
                            blurRadius: 32,
                            spreadRadius: -4,
                            offset: Offset(0, 12),
                          ),
                        ],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Align(
                              widthFactor: 1,
                              child: Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: const BoxDecoration(
                                  color: NordicColors.secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Text(
                              eta == null
                                  ? ride.status.label
                                  : 'ETA ${Fmt.duration(eta)}',
                              key: const Key('eta_pill'),
                              style: NordicText.titleSm.copyWith(
                                color: NordicColors.onSurface,
                              ),
                            ),
                            if (telemetry?.remainingMeters != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                '· ${Fmt.distance(telemetry!.remainingMeters!.round())}',
                                style: NordicText.labelSm.copyWith(
                                  color: NordicColors.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Tw.a(NordicColors.primary, 0.9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: Tw.md,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const MIcon(
                              Symbols.navigation,
                              size: 16,
                              lh: 20,
                              color: NordicColors.secondaryFixed,
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: Text(
                                _inTrip
                                    ? ride.dropoff.title
                                    : ride.pickup.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: NordicText.labelMd.copyWith(
                                  color: Colors.white,
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
            },
          ),
          SheetShell(
            radius: 24,
            shadow: const [
              BoxShadow(
                color: Color(0x140F2A4A),
                blurRadius: 30,
                offset: Offset(0, -8),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: SheetHandle(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    key: const Key('status_headline'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                MIcon(
                                  _inTrip ? Symbols.route : Symbols.near_me,
                                  size: 22,
                                  color: NordicColors.secondary,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _inTrip
                                        ? 'Trip in progress'
                                        : '$name is approaching pickup spot',
                                    key: const Key('status_title'),
                                    style: NordicText.headlineSm.copyWith(
                                      color: NordicColors.onSurface,
                                      letterSpacing: 20 * -0.025,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _inTrip
                                  ? 'Heading to ${ride.dropoff.title}'
                                  : 'Estimated pickup at ${ride.pickup.title}',
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: NordicColors.secondaryContainer.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const MIcon(
                              Symbols.bolt,
                              size: 14,
                              lh: 14,
                              color: NordicColors.onSecondaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '100% EV',
                              style: NordicText.labelSm.copyWith(
                                color: NordicColors.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SecurityPinCard(ride: ride, firstName: name),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: NordicColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: Tw.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                        DemoPhotos.driverTracking,
                                        size: 56,
                                        shadows: Tw.sm,
                                        semanticLabel: 'Driver photo',
                                      ),
                                      Positioned(
                                        right: -4,
                                        bottom: -4,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: NordicColors.surface,
                                            shape: BoxShape.circle,
                                            boxShadow: Tw.sm,
                                          ),
                                          child: const MIcon(
                                            Symbols.verified,
                                            size: 16,
                                            color: NordicColors.secondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          driver?.firstName ?? 'Your driver',
                                          key: const Key('driver_name'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: NordicText.titleSm.copyWith(
                                            color: NordicColors.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const RatingLine(
                                          rating: DemoDriverProfile.rating,
                                          suffix: DemoDriverProfile.tripsLive,
                                          starSize: 15,
                                          dot: '·',
                                          gap: 6,
                                          style: TextStyle(
                                            fontFamily: NordicText.family,
                                            package: NordicText.package,
                                            fontSize: 12,
                                            height: 16 / 12,
                                            fontWeight: FontWeight.w600,
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
                            if (vehicle != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        vehicle.displayName.isEmpty
                                            ? 'Vehicle'
                                            : vehicle.displayName,
                                        key: const Key('vehicle_name'),
                                        style: NordicText.labelMd.copyWith(
                                          color: NordicColors.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const MIcon(
                                        Symbols.electric_car,
                                        size: 16,
                                        color: NordicColors.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  PlateSmall(vehicle.plateNumber),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _SpecChip(
                                Symbols.airline_seat_recline_normal,
                                DemoDriverProfile.seatsChip,
                              ),
                              _SpecChip(
                                Symbols.luggage,
                                DemoDriverProfile.trunkChip,
                              ),
                              _SpecChip(
                                Symbols.device_thermostat,
                                DemoDriverProfile.cabinTemp,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (hasDriverPhone(ride)) ...[
                    ActionRow(ride: ride, style: ActionTileStyle.live),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: NordicColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: Tw.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Elevated(
                              shadows: Tw.sm,
                              radius: 12,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: NordicColors.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: MIcon(
                                    paymentIcon(ride),
                                    size: 22,
                                    color: NordicColors.onTertiaryContainer,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      paymentLabel(ride),
                                      style: NordicText.labelMd.copyWith(
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
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              rideTotal(ride),
                              key: const Key('live_fare'),
                              style: NordicText.currencyDisplay.copyWith(
                                color: NordicColors.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Estimated fare incl. tax',
                              style: NordicText.labelSm.copyWith(
                                color: NordicColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (ride.status.canRiderCancel) ...[
                    const SizedBox(height: 16),
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

class _SpecChip extends StatelessWidget {
  const _SpecChip(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: NordicColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MIcon(icon, size: 14, lh: 14, color: NordicColors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: NordicText.labelSm.copyWith(
            color: NordicColors.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

/// `Security PIN` card of `live_tracking_3_states`. The 4-digit code is a DEMO value generated
/// locally by [demoSecurityPin]: the backend has no ride PIN and nothing verifies it.
class SecurityPinCard extends StatelessWidget {
  const SecurityPinCard({
    super.key,
    required this.ride,
    required this.firstName,
  });

  final Ride ride;
  final String firstName;

  @override
  Widget build(BuildContext context) => Elevated(
    shadows: Tw.md,
    radius: 16,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        key: const Key('pin_card'),
        color: NordicColors.primaryContainer,
        child: Stack(
          children: [
            Positioned(
              right: -24,
              bottom: -24,
              child: Blob(
                size: 112,
                color: NordicColors.secondary.withValues(alpha: 0.15),
                blur: 24,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SECURITY PIN',
                          style: NordicText.labelSm.copyWith(
                            color: NordicColors.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 10 * 0.05,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              demoSecurityPin(ride.id),
                              key: const Key('demo_pin'),
                              style: NordicText.displayLgMobile.copyWith(
                                color: NordicColors.surface,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 32 * 0.1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const MIcon(
                              Symbols.verified_user,
                              size: 18,
                              color: NordicColors.secondaryFixed,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Share with $firstName before entering car',
                          style: NordicText.bodySm.copyWith(
                            color: NordicColors.primaryFixedDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: NordicColors.surface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: MIcon(
                        Symbols.pin,
                        size: 28,
                        color: NordicColors.surfaceVariant,
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
  );
}

/// Lifecycle strip + segmented control from `live_tracking_3_states` (display only: the stage is
/// driven by the real ride status).
class StageStrip extends StatelessWidget {
  const StageStrip({super.key, required this.stage});

  final int stage;

  @override
  Widget build(BuildContext context) {
    Widget step(
      String label, {
      required Color dot,
      bool active = false,
      double opacity = 1,
      bool showLabel = true,
    }) => Opacity(
      opacity: opacity,
      child: Row(
        children: [
          active
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: NordicColors.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                )
              : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: NordicText.labelSm.copyWith(
                color: active
                    ? NordicColors.secondary
                    : NordicColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
    Widget line(Color c) => Container(height: 2, width: 16, color: c);
    final inTrip = stage == 2;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: NordicColors.surfaceContainerLow,
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                step(
                  '1. Finding',
                  dot: NordicColors.outline,
                  opacity: 0.6,
                  showLabel: false,
                ),
                line(NordicColors.outlineVariant),
                step(
                  '2. Driver found',
                  dot: NordicColors.secondary,
                  opacity: 0.8,
                  showLabel: false,
                ),
                line(NordicColors.secondary),
                step(
                  inTrip ? '3. Arrived' : '3. Arriving',
                  dot: NordicColors.secondary,
                  active: !inTrip,
                  opacity: inTrip ? 0.8 : 1,
                ),
                line(
                  inTrip ? NordicColors.secondary : NordicColors.outlineVariant,
                ),
                step(
                  '4. In trip',
                  dot: inTrip ? NordicColors.secondary : NordicColors.outline,
                  active: inTrip,
                  opacity: inTrip ? 1 : 0.6,
                ),
                line(NordicColors.outlineVariant),
                step(
                  '5. Done',
                  dot: NordicColors.outlineVariant,
                  opacity: 0.5,
                  showLabel: false,
                ),
              ],
            ),
          ),
          Container(
            key: const Key('stage_tabs'),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: NordicColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              boxShadow: Tw.sm,
            ),
            child: Row(
              children: [
                for (final (i, label) in [
                  'Driver on the way',
                  'Driver arrived',
                  'In trip',
                ].indexed) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: i == stage
                            ? NordicColors.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: i == stage ? Tw.sm : null,
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NordicText.labelMd.copyWith(
                          color: i == stage
                              ? NordicColors.surface
                              : NordicColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
