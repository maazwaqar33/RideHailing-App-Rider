import 'package:flutter/material.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../core/formatting/formatters.dart';
import '../features/rides/domain/ride_models.dart';

/// Navy-to-teal hero used on welcome / auth headers.
class GradientHero extends StatelessWidget {
  const GradientHero({
    super.key,
    required this.child,
    this.light = false,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final bool light;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: light
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE5EEFF), Color(0xFFE1FAF6)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F2A4A),
                  Color(0xFF0B3A48),
                  Color(0xFF0E5A5A),
                ],
              ),
        boxShadow: NordicShadows.level2,
      ),
      child: child,
    );
  }
}

NordicTone toneFor(RideStatus s) => switch (s) {
  RideStatus.completed => NordicTone.success,
  RideStatus.cancelled => NordicTone.critical,
  RideStatus.unknown => NordicTone.neutral,
  RideStatus.inProgress => NordicTone.info,
  _ => NordicTone.pending,
};

class RideStatusBadge extends StatelessWidget {
  const RideStatusBadge(this.status, {super.key});

  final RideStatus status;

  @override
  Widget build(BuildContext context) =>
      NordicStatusBadge(label: status.label, tone: toneFor(status));
}

/// Fare breakdown as returned by the API (`fare.breakdown`) or by the estimate endpoint.
/// All values are integer minor units rendered with the API currency.
class FareBreakdownCard extends StatelessWidget {
  const FareBreakdownCard({
    super.key,
    required this.breakdown,
    this.title = 'Fare breakdown',
    this.totalLabel = 'Total',
    this.footer,
  });

  final FareBreakdown breakdown;
  final String title;
  final String totalLabel;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final b = breakdown;
    final c = b.currency;
    final rows = <(String, String, String?)>[
      ('Base fare', Money.format(b.baseFareMinor, c), null),
      (
        'Distance',
        Money.format(b.distanceChargeMinor, c),
        Fmt.distance(b.distanceMeters),
      ),
      (
        'Time',
        Money.format(b.timeChargeMinor, c),
        Fmt.duration(b.durationSeconds),
      ),
      if (b.minimumFareAdjustmentMinor > 0)
        (
          'Minimum fare adjustment',
          Money.format(b.minimumFareAdjustmentMinor, c),
          null,
        ),
      ('Booking fee', Money.format(b.bookingFeeMinor, c), null),
      ('Tax', Money.format(b.taxMinor, c), null),
    ];
    return Container(
      key: const Key('fare_breakdown'),
      padding: const EdgeInsets.all(NordicSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: NordicRadii.cardRadius,
        border: Border.all(color: NordicColors.border),
        boxShadow: NordicShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: NordicText.titleMd),
          const SizedBox(height: 12),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Text(r.$1, style: NordicText.bodyMd),
                  if (r.$3 != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '(${r.$3})',
                      style: NordicText.bodySm.copyWith(
                        color: NordicColors.textSecondary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(r.$2, style: NordicText.tabular(NordicText.bodyMd)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: NordicColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(totalLabel, style: NordicText.titleSm),
                const Spacer(),
                Text(
                  Money.format(b.totalMinor, c),
                  key: const Key('fare_total'),
                  style: NordicText.currencyDisplay,
                ),
              ],
            ),
          ),
          if (footer != null) ...[const SizedBox(height: 10), footer!],
        ],
      ),
    );
  }
}

/// Driver + vehicle summary built ONLY from what the ride resource exposes
/// (first name, phone while the ride is live; vehicle make/model/colour/plate).
/// The API has no driver photo or rating, so an initials avatar is used and no rating is shown.
class DriverSummaryCard extends StatelessWidget {
  const DriverSummaryCard({super.key, required this.ride, this.trailing});

  final Ride ride;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final driver = ride.driver;
    final vehicle = ride.vehicle;
    return Container(
      padding: const EdgeInsets.all(NordicSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: NordicRadii.cardRadius,
        border: Border.all(color: NordicColors.border),
        boxShadow: NordicShadows.level1,
      ),
      child: Column(
        children: [
          Row(
            children: [
              NordicAvatar(name: driver?.firstName ?? 'Driver', size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver?.firstName ?? 'Your driver',
                      key: const Key('driver_name'),
                      style: NordicText.headlineSm,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Nordic Ride driver',
                      style: NordicText.bodySm.copyWith(
                        color: NordicColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (vehicle != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: NordicColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_car_filled_outlined,
                      color: NordicColors.primaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.displayName.isEmpty
                              ? 'Assigned vehicle'
                              : vehicle.displayName,
                          key: const Key('vehicle_name'),
                          style: NordicText.titleSm,
                        ),
                        if (vehicle.colour != null &&
                            vehicle.colour!.isNotEmpty)
                          Text(
                            vehicle.colour!,
                            style: NordicText.bodySm.copyWith(
                              color: NordicColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: NordicColors.border),
                    ),
                    child: Text(
                      vehicle.plateNumber,
                      key: const Key('vehicle_plate'),
                      style: NordicText.tabular(NordicText.titleSm)
                          .copyWith(letterSpacing: 1.2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Friendly inline error with optional retry.
class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => NordicBanner(
    message: message,
    tone: NordicTone.critical,
    actionLabel: onRetry == null ? null : 'Try again',
    onAction: onRetry,
  );
}
