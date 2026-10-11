import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../core/formatting/formatters.dart';
import '../../../mock/demo_content.dart';
import '../../../shared/app_map.dart';
import '../../../shared/nav_scaffold.dart';
import '../../../shared/stitch.dart';
import '../../../shared/widgets.dart' show InlineError;
import '../../map/application/map_providers.dart';
import '../../rides/application/ride_providers.dart';
import '../../rides/domain/ride_models.dart';
import '../../trip/application/trip_providers.dart';
import '../../trip/presentation/report_problem_sheet.dart';
import '../../trip/presentation/trip_widgets.dart';

/// Receipt / detail for any ride (Stitch `trip_receipt`): real data from GET rides/{id} and
/// GET rides/{id}/timeline. Local-only extras (demo payment confirmation, rating) are labelled.
///
/// Not in the API, so omitted or replaced: Vipps / BankID verification and transaction id,
/// driver rating, airport toll line, CO2 savings, PDF export.
class TripReceiptScreen extends ConsumerWidget {
  const TripReceiptScreen({super.key, required this.rideId});

  final int rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rideDetailProvider(rideId));
    return Scaffold(
      backgroundColor: NordicColors.surface,
      body: Column(
        children: [
          StitchBackHeader(
            title: 'Receipt',
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/trips'),
          ),
          Expanded(
            child: async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    NordicSkeletonRow(),
                    NordicSkeletonRow(),
                    NordicSkeletonRow(),
                  ],
                ),
              ),
              error: (e, _) => NordicErrorView(
                message: 'We could not load this trip.',
                onRetry: () => ref.invalidate(rideDetailProvider(rideId)),
              ),
              data: (ride) => _Body(ride: ride),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(rideTimelineProvider(ride.id));
    final feedback = ref.watch(savedFeedbackProvider(ride.id)).asData?.value;
    final receipt = ref.watch(mockReceiptProvider(ride.id)).asData?.value;
    final completed = ride.status == RideStatus.completed;
    final cancelled = ride.status == RideStatus.cancelled;
    final currency = ride.fare.currency;
    final total = ride.fare.finalMinor ?? ride.fare.estimateMinor ?? 0;
    final when = ride.completedAt ?? ride.cancelledAt ?? ride.requestedAt;
    final method = PaymentMethodType.parse(ride.payment.method);
    final b = ride.fare.breakdown;
    final pill = cancelled
        ? 'RIDE CANCELLED'
        : (completed
              ? 'TRIP COMPLETED'
              : ride.status.label.toUpperCase());

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: [
          // Hero: status stamp + total.
          StitchCard(
            backdrop: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  top: -48,
                  right: -48,
                  child: Blob(
                    size: 144,
                    color: NordicColors.secondaryFixed.withValues(alpha: 0.3),
                    blur: 40,
                  ),
                ),
                Positioned(
                  bottom: -40,
                  left: -40,
                  child: Blob(
                    size: 112,
                    color: NordicColors.surfaceVariant.withValues(alpha: 0.4),
                    blur: 24,
                  ),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Elevated(
                    shadows: Tw.sm,
                    circle: true,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cancelled
                            ? NordicColors.errorContainer
                            : NordicColors.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: MIcon(
                          cancelled
                              ? Symbols.cancel
                              : (completed
                                    ? Symbols.check_circle
                                    : Symbols.schedule),
                          size: 26,
                          color: cancelled
                              ? NordicColors.onErrorContainer
                              : NordicColors.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    key: const Key('receipt_status'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: NordicColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: cancelled
                                ? NordicColors.error
                                : NordicColors.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            pill,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: NordicText.labelMd.copyWith(
                              color: NordicColors.onSurfaceVariant,
                              letterSpacing: 12 * 0.025,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Money.format(total, currency),
                    key: const Key('receipt_total'),
                    textAlign: TextAlign.center,
                    style: NordicText.headlineLg.copyWith(
                      color: NordicColors.onSurface,
                      letterSpacing: 28 * -0.025,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      cancelled
                          ? 'Not charged'
                          : (completed ? 'Final fare' : 'Estimated fare'),
                      if (when != null) Fmt.fullDateTime(when),
                    ].join(' · '),
                    textAlign: TextAlign.center,
                    style: NordicText.bodySm.copyWith(
                      color: NordicColors.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (cancelled) ...[
            const SizedBox(height: 16),
            Container(
              key: const Key('receipt_cancelled'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: NordicColors.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const MIcon(
                    Symbols.info,
                    size: 20,
                    color: NordicColors.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      ride.cancellationReason == null
                          ? 'This ride was cancelled.'
                          : 'Ride cancelled. Reason: ${ride.cancellationReason}',
                      textAlign: TextAlign.center,
                      style: NordicText.bodySm.copyWith(
                        color: NordicColors.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Map + route + driver.
          StitchCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 128,
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
                            child: ColoredBox(
                              color: NordicColors.primaryContainer.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: NordicColors.surfaceContainerLowest
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(9999),
                              boxShadow: Tw.sm,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const MIcon(
                                  Symbols.bolt,
                                  size: 14,
                                  color: NordicColors.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '100% Zero Emission',
                                  style: NordicText.labelSm.copyWith(
                                    color: NordicColors.onSurface,
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
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: NordicColors.secondaryFixedDim,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 2,
                              height: 32,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: NordicColors.outlineVariant,
                            ),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: NordicColors.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Place('ORIGIN', ride.pickup.title),
                            _Place('DESTINATION', ride.dropoff.title),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (ride.driver != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NordicColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const PhotoCircle(
                                DemoPhotos.driverReceipt,
                                size: 40,
                                semanticLabel: 'Driver',
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ride.driver!.firstName,
                                      key: const Key('driver_name'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: NordicText.titleSm.copyWith(
                                        color: NordicColors.onSurface,
                                      ),
                                    ),
                                    if (ride.vehicle != null)
                                      Text(
                                        [
                                          if (ride
                                              .vehicle!
                                              .displayName
                                              .isNotEmpty)
                                            ride.vehicle!.displayName,
                                          ride.vehicle!.plateNumber,
                                        ].join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: NordicText.bodySm.copyWith(
                                          color: NordicColors.outline,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: NordicColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const MIcon(
                                Symbols.star,
                                size: 14,
                                color: NordicColors.onTertiaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                feedback == null
                                    ? DemoDriverProfile.receiptRating
                                    : '${DemoDriverProfile.receiptRating} · Rated ${feedback.rating}★',
                                key: const Key('receipt_rating'),
                                style: NordicText.labelMd.copyWith(
                                  color: NordicColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Fare breakdown.
          if (b != null)
            StitchCard(
              key: const Key('fare_breakdown'),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Comprehensive Breakdown',
                          style: NordicText.titleSm.copyWith(
                            color: NordicColors.onSurface,
                          ),
                        ),
                        Text(
                          'Trip #${ride.id}',
                          style: NordicText.labelMd.copyWith(
                            color: NordicColors.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        _Line(
                          'Base fare',
                          Money.format(b.baseFareMinor, currency),
                        ),
                        const SizedBox(height: 4),
                        _Line(
                          'Distance (${Fmt.distance(b.distanceMeters)})',
                          Money.format(b.distanceChargeMinor, currency),
                        ),
                        const SizedBox(height: 4),
                        _Line(
                          'Time (${Fmt.duration(b.durationSeconds)})',
                          Money.format(b.timeChargeMinor, currency),
                        ),
                        if (b.minimumFareAdjustmentMinor > 0) ...[
                          const SizedBox(height: 4),
                          _Line(
                            'Minimum fare adjustment',
                            Money.format(
                              b.minimumFareAdjustmentMinor,
                              currency,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        _Line(
                          'Booking fee',
                          Money.format(b.bookingFeeMinor, currency),
                        ),
                        const SizedBox(height: 4),
                        _Line('VAT / tax', Money.format(b.taxMinor, currency)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NordicColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          completed ? 'Total fare' : 'Total',
                          style: NordicText.titleSm.copyWith(
                            color: NordicColors.onSurface,
                          ),
                        ),
                        Text(
                          Money.format(total, currency),
                          key: const Key('receipt_fare_total'),
                          style: NordicText.headlineMd.copyWith(
                            color: NordicColors.onSurface,
                            letterSpacing: 24 * -0.025,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (b != null) const SizedBox(height: 24),
          // Payment.
          StitchCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Payment Method',
                  style: NordicText.titleSm.copyWith(
                    color: NordicColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NordicColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Elevated(
                        shadows: Tw.sm,
                        radius: 8,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: NordicColors.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: MIcon(
                              method == PaymentMethodType.cash
                                  ? Symbols.payments
                                  : Symbols.credit_card,
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              method.label,
                              style: NordicText.titleSm.copyWith(
                                color: NordicColors.onSurface,
                              ),
                            ),
                            Text(
                              'Payment status: Completed',
                              key: const Key('receipt_payment_status'),
                              style: NordicText.bodySm.copyWith(
                                color: NordicColors.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (receipt != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PAYMENT REFERENCE',
                          style: NordicText.labelMd.copyWith(
                            color: NordicColors.outline,
                            letterSpacing: 12 * 0.05,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: NordicColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            receipt.reference,
                            style: NordicText.labelMd.copyWith(
                              color: NordicColors.onSurface,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (receipt != null && receipt.tipMinor > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                    child: Text(
                      'Driver tip: ${Money.format(receipt.tipMinor, receipt.currency)}',
                      style: NordicText.bodySm.copyWith(
                        color: NordicColors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (completed || cancelled) ...[
            const SizedBox(height: 12),
            StitchButton(
              key: const Key('rebook'),
              label: 'Book this trip again',
              icon: Symbols.replay,
              trailingIcon: false,
              radius: 8,
              background: NordicColors.surfaceContainer,
              foreground: NordicColors.primary,
              shadow: const [],
              onPressed: () => rebookFromRide(context, ref, ride),
            ),
          ],
          const SizedBox(height: 24),
          StitchCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                if (completed && feedback == null && ride.driver != null)
                  _HelpRow(
                    key: const Key('receipt_rate'),
                    icon: Symbols.star,
                    iconColor: NordicColors.onTertiaryContainer,
                    iconBackground: NordicColors.tertiaryFixed,
                    label: 'Rate your driver',
                    onTap: () => context.push('/rate/${ride.id}'),
                  ),
                _HelpRow(
                  key: const Key('receipt_report'),
                  icon: Symbols.report_problem,
                  iconColor: NordicColors.onErrorContainer,
                  iconBackground: NordicColors.errorContainer,
                  label: 'Report a problem',
                  onTap: () => showReportProblemSheet(context, rideId: ride.id),
                ),
                _HelpRow(
                  icon: Symbols.luggage,
                  iconColor: NordicColors.onPrimaryContainer,
                  iconBackground: NordicColors.surfaceContainerHigh,
                  label: 'Lost item?',
                  onTap: () => showReportProblemSheet(
                    context,
                    rideId: ride.id,
                    initialCategory: 'Lost item',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            key: const Key('co2_stamp'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NordicColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
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
                      Symbols.eco,
                      size: 20,
                      color: NordicColors.onSecondaryFixedVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${co2SavedKg(ride.distanceMeters)} kg CO₂ Saved',
                        style: NordicText.titleSm.copyWith(
                          color: NordicColors.onSurface,
                        ),
                      ),
                      Text(
                        'Calculated versus standard petrol emissions (120 g/km).',
                        style: NordicText.bodySm.copyWith(
                          color: NordicColors.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NordicColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ride timeline',
                  style: NordicText.titleSm.copyWith(
                    color: NordicColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                timeline.when(
                  loading: () => const Column(
                    children: [NordicSkeletonRow(), NordicSkeletonRow()],
                  ),
                  error: (e, _) => InlineError(
                    message: 'Could not load the timeline.',
                    onRetry: () =>
                        ref.invalidate(rideTimelineProvider(ride.id)),
                  ),
                  data: (entries) => Column(
                    key: const Key('timeline_list'),
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        _TimelineRow(
                          entry: entries[i],
                          last: i == entries.length - 1,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Place extends StatelessWidget {
  const _Place(this.label, this.title);

  final String label;
  final String title;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: NordicText.labelSm.copyWith(
          color: NordicColors.outline,
          letterSpacing: 10 * 0.05,
        ),
      ),
      Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: NordicText.titleSm.copyWith(color: NordicColors.onSurface),
      ),
    ],
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: NordicText.bodySm.copyWith(color: NordicColors.onSurfaceVariant),
      ),
      Text(
        value,
        style: NordicText.bodySm.copyWith(color: NordicColors.onSurface),
      ),
    ],
  );
}

class _HelpRow extends StatelessWidget {
  const _HelpRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Center(child: MIcon(icon, size: 18, color: iconColor)),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: NordicText.titleSm.copyWith(
                  color: NordicColors.onSurface,
                ),
              ),
            ],
          ),
          const MIcon(
            Symbols.chevron_right,
            size: 20,
            color: NordicColors.outline,
          ),
        ],
      ),
    ),
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.last});

  final TimelineEntry entry;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final cancelled = entry.toStatus == RideStatus.cancelled;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: cancelled
                      ? NordicColors.error
                      : NordicColors.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    color: NordicColors.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.toStatus.label,
                    style: NordicText.titleSm.copyWith(
                      color: NordicColors.onSurface,
                    ),
                  ),
                  Text(
                    [
                      if (entry.createdAt != null)
                        Fmt.fullDateTime(entry.createdAt!),
                      if (entry.actorRole != null) 'by ${entry.actorRole}',
                    ].join(' - '),
                    style: NordicText.bodySm.copyWith(
                      color: NordicColors.onSurfaceVariant,
                    ),
                  ),
                  if (entry.reason != null && entry.reason!.isNotEmpty)
                    Text(
                      'Reason: ${entry.reason}',
                      style: NordicText.bodySm.copyWith(
                        color: NordicColors.onSurface,
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
}

/// Prefills the trip plan from a past ride and opens the ride chooser.
void rebookFromRide(BuildContext context, WidgetRef ref, Ride ride) {
  ref.read(tripPlanProvider.notifier).prefillFromRide(ride);
  context.push('/choose-ride');
}
