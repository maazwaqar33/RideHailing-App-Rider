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

/// Stitch `driver_found_erik_larsen` (status `accepted`).
///
/// Real: driver first name, vehicle make/model/colour, plate, pickup address, payment method and
/// the fare. DEMO: portrait + car photo (Stitch placeholders), rating, trip count, languages,
/// "100% Hybrid" chip (no such data in the ride resource), mock driver position and ETA.
class DriverFoundView extends StatelessWidget {
  const DriverFoundView({
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
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: kHeaderHeight + pad.top),
      child: Column(
        children: [
          ValueListenableBuilder<DriverPosition?>(
            valueListenable: positions,
            builder: (context, telemetry, _) {
              final eta = telemetry?.etaSeconds;
              return SizedBox(
                height: 270,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: TrackingMap(
                        ride: ride,
                        telemetry: telemetry,
                        mode: TrackingMapMode.found,
                        fitPadding: const EdgeInsets.fromLTRB(56, 90, 56, 70),
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
                                Tw.a(NordicColors.primary, 0.6),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GlassPill(
                            shadows: const [
                              BoxShadow(
                                color: Color(0x1F0F2A4A),
                                blurRadius: 16,
                                offset: Offset(0, 4),
                              ),
                            ],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: NordicColors.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  eta == null
                                      ? 'DRIVER ASSIGNED'
                                      : '${(eta / 60).ceil()} MIN AWAY',
                                  key: const Key('eta_pill'),
                                  style: NordicText.labelMd.copyWith(
                                    color: NordicColors.onSurface,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 12 * 0.05,
                                  ),
                                ),
                                if (telemetry?.remainingMeters != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '• ${Fmt.distance(telemetry!.remainingMeters!.round())}',
                                    style: NordicText.bodySm.copyWith(
                                      color: NordicColors.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 28,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9999),
                        child: BackdropBlur(
                          radius: 9999,
                          blur: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            color: Tw.a(NordicColors.primary, 0.9),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const MIcon(
                                  Symbols.near_me,
                                  size: 14,
                                  lh: 20,
                                  color: NordicColors.secondaryFixed,
                                ),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 220,
                                  ),
                                  child: Text(
                                    ride.pickup.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: NordicText.labelMd.copyWith(
                                      color: Colors.white,
                                      letterSpacing: 12 * 0.025,
                                    ),
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
              );
            },
          ),
          SheetShell(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: SheetHandle(
                      width: 40,
                      color: NordicColors.surfaceContainer,
                    ),
                  ),
                  Container(
                    key: const Key('status_headline'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: NordicColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: NordicColors.secondary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: MIcon(
                                    Symbols.check,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Driver found',
                                      key: const Key('status_title'),
                                      style: NordicText.titleSm.copyWith(
                                        color: NordicColors.primary,
                                        fontWeight: FontWeight.w600,
                                        height: 1.25,
                                      ),
                                    ),
                                    Text(
                                      'Approaching pickup zone',
                                      style: NordicText.labelSm.copyWith(
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
                        Elevated(
                          shadows: Tw.sm,
                          radius: 9999,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: NordicColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const MIcon(
                                  Symbols.eco,
                                  size: 16,
                                  lh: 24,
                                  color: NordicColors.secondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '100% ${DemoDriverProfile.powertrain}',
                                  style: NordicText.labelSm.copyWith(
                                    color: NordicColors.secondary,
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
                  Elevated(
                    shadows: const [
                      BoxShadow(
                        color: Color(0x0F0F2A4A),
                        blurRadius: 16,
                        spreadRadius: -2,
                        offset: Offset(0, 4),
                      ),
                    ],
                    radius: 16,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NordicColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
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
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        const PhotoCircle(
                                          DemoPhotos.driverFound,
                                          size: 64,
                                          shadows: [
                                            BoxShadow(
                                              color: Color(0x1A0F2A4A),
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                          semanticLabel: 'Driver',
                                        ),
                                        Positioned(
                                          right: -4,
                                          bottom: -4,
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: NordicColors.secondary,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                Tw.ring(
                                                  NordicColors
                                                      .surfaceContainerLowest,
                                                ),
                                              ],
                                            ),
                                            child: const Center(
                                              child: MIcon(
                                                Symbols.verified,
                                                size: 12,
                                                color: Colors.white,
                                              ),
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
                                            style: NordicText.titleMd.copyWith(
                                              color: NordicColors.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const RatingLine(
                                            rating: DemoDriverProfile.rating,
                                            suffix:
                                                DemoDriverProfile.tripsFound,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DemoDriverProfile.languages,
                                            style: NordicText.labelSm.copyWith(
                                              color: NordicColors.secondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (vehicle != null) ...[
                                const SizedBox(width: 12),
                                PlateLarge(vehicle.plateNumber),
                              ],
                            ],
                          ),
                          if (vehicle != null) ...[
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                color: NordicColors.surfaceContainerLow,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      flex: 11,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'ASSIGNED VEHICLE',
                                            style: NordicText.labelSm.copyWith(
                                              color:
                                                  NordicColors.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 10 * 0.05,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            vehicle.displayName.isEmpty
                                                ? 'Assigned vehicle'
                                                : vehicle.displayName,
                                            key: const Key('vehicle_name'),
                                            style: NordicText.titleSm.copyWith(
                                              color: NordicColors.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: NordicColors.secondary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  [
                                                    DemoDriverProfile
                                                        .powertrain,
                                                    if (vehicle.colour !=
                                                            null &&
                                                        vehicle
                                                            .colour!
                                                            .isNotEmpty)
                                                      vehicle.colour!,
                                                  ].join(' • '),
                                                  style: NordicText.labelSm
                                                      .copyWith(
                                                        color: NordicColors
                                                            .onSurfaceVariant,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Transform.translate(
                                      offset: const Offset(8, 0),
                                      child: SizedBox(
                                        width: 160,
                                        height: 80,
                                        child: Image.asset(
                                          DemoPhotos.carComfort,
                                          fit: BoxFit.contain,
                                          alignment: Alignment.centerRight,
                                          semanticLabel: 'Vehicle',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (hasDriverPhone(ride)) ...[
                    ActionRow(ride: ride, style: ActionTileStyle.found),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Tw.a(NordicColors.surfaceContainerLow, 0.7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const MIcon(
                                    Symbols.pin_drop,
                                    size: 20,
                                    lh: 28,
                                    color: NordicColors.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Pickup spot',
                                          style: NordicText.labelSm.copyWith(
                                            color:
                                                NordicColors.onSurfaceVariant,
                                          ),
                                        ),
                                        Text(
                                          ride.pickup.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: NordicText.titleSm.copyWith(
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
                          ],
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
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
                                      color: NordicColors.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                rideTotal(ride),
                                key: const Key('live_fare'),
                                style: NordicText.currencyDisplay.copyWith(
                                  color: NordicColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
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
