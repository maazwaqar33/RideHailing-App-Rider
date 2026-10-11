import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../core/formatting/formatters.dart';
import '../../../shared/app_map.dart';
import '../../../shared/nav_scaffold.dart';
import '../../../shared/stitch.dart';
import '../../../shared/widgets.dart' show FareBreakdownCard;
import '../../map/application/map_providers.dart';
import '../../map/domain/map_models.dart';
import '../../rides/application/ride_providers.dart';
import '../../rides/domain/ride_models.dart';
import '../application/booking_controller.dart';

/// Stitch `confirm_and_pay`: trip summary, payment method (cash/card, MOCK) and the Request Ride
/// action. The chosen method is sent as `payment_method`; the backend keeps `payment_status =
/// not_charged`. Vipps and saved cards are intentionally absent.
class ConfirmPayScreen extends ConsumerStatefulWidget {
  const ConfirmPayScreen({super.key});

  static const vehiclePhotos = {
    VehicleChoice.sedan: DemoPhotos.carStandard,
    VehicleChoice.estate: DemoPhotos.carComfort,
    VehicleChoice.van: DemoPhotos.carVan,
  };

  @override
  ConsumerState<ConfirmPayScreen> createState() => _ConfirmPayScreenState();
}

class _ConfirmPayScreenState extends ConsumerState<ConfirmPayScreen> {
  static const _photos = ConfirmPayScreen.vehiclePhotos;
  bool _showBreakdown = false;

  /// The ride API has no "driver note": the note rides along in the pickup address (max 255 chars).
  static String _withNote(String address, String note) {
    if (note.isEmpty) return address;
    final full = '$address | Note: $note';
    return full.length > 255 ? full.substring(0, 255) : full;
  }

  Future<void> _book() async {
    final plan = ref.read(tripPlanProvider);
    final route = ref.read(routeProvider).asData?.value;
    if (!plan.isComplete || route == null) return;
    final request = CreateRideRequest(
      pickup: RideLocation(
        latitude: plan.pickup!.position.latitude,
        longitude: plan.pickup!.position.longitude,
        address: _withNote(plan.pickup!.apiAddress, plan.pickupNote),
      ),
      dropoff: RideLocation(
        latitude: plan.dropoff!.position.latitude,
        longitude: plan.dropoff!.position.longitude,
        address: plan.dropoff!.apiAddress,
      ),
      distanceMeters: route.distanceMeters < 1 ? 1 : route.distanceMeters,
      durationSeconds: route.durationSeconds < 1 ? 1 : route.durationSeconds,
      paymentMethod: plan.payment,
    );
    final ride = await ref
        .read(bookingControllerProvider.notifier)
        .submit(request);
    if (ride != null && mounted) {
      ref.read(tripPlanProvider.notifier).resetAfterBooking();
      ref.read(bookingControllerProvider.notifier).reset();
      context.go('/home');
      context.push('/ride/${ride.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(tripPlanProvider);
    final route = ref.watch(routeProvider).asData?.value;
    final fare = ref.watch(fareEstimateProvider);
    final estimate = fare.asData?.value;
    final booking = ref.watch(bookingControllerProvider);
    final cars = ref.watch(nearbyCarsProvider).asData?.value ?? const [];
    final canBook =
        estimate != null &&
        route != null &&
        plan.isComplete &&
        !booking.isSubmitting;
    final pad = MediaQuery.paddingOf(context);

    if (!plan.isComplete) {
      return Scaffold(
        backgroundColor: NordicColors.surface,
        body: Stack(
          children: [
            const Center(child: Text('Nothing to confirm yet.')),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: StitchBackHeader(
                title: 'Confirm And Pay',
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
              ),
            ),
          ],
        ),
      );
    }

    final total = estimate == null
        ? null
        : Money.format(estimate.totalMinor, estimate.currency);
    final nearestEta = cars.isEmpty
        ? null
        : cars.map((c) => c.etaMinutes).reduce((a, b) => a < b ? a : b);

    return Scaffold(
      backgroundColor: NordicColors.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                kHeaderHeight + pad.top + 16,
                16,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (booking.error != null) ...[
                    if (booking.hasActiveRideConflict)
                      NordicBanner(
                        key: const Key('active_ride_conflict'),
                        title: 'You already have an active ride',
                        message: 'Finish or cancel your current ride before requesting another one.',
                        tone: NordicTone.pending,
                        actionLabel: 'View active ride',
                        onAction: () async {
                          ref.invalidate(activeRideProvider);
                          final active = await ref.read(
                            activeRideProvider.future,
                          );
                          if (active != null && context.mounted) {
                            context.go('/home');
                            context.push('/ride/${active.id}');
                          }
                        },
                      )
                    else
                      NordicBanner(
                        key: const Key('booking_error'),
                        message: booking.error!.message,
                        tone: NordicTone.critical,
                      ),
                    const SizedBox(height: 16),
                  ],
                  // Route preview tile
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
                              child: ColoredBox(
                                color: NordicColors.surfaceContainer,
                                child: AppMap(
                                  center: plan.pickup!.position,
                                  interactive: false,
                                  fitPoints: [
                                    plan.pickup!.position,
                                    plan.dropoff!.position,
                                  ],
                                  fitPadding: const EdgeInsets.fromLTRB(
                                    40,
                                    30,
                                    40,
                                    50,
                                  ),
                                  routePoints: route?.points ?? const [],
                                  markers: [
                                    pickupMarker(plan.pickup!.position),
                                    dropoffMarker(plan.dropoff!.position),
                                  ],
                                ),
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
                                        Tw.a(NordicColors.primary, 0.8),
                                        Tw.a(NordicColors.primary, 0.2),
                                        Tw.a(NordicColors.primary, 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 16,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const MIcon(
                                          Symbols.electric_bolt,
                                          size: 18,
                                          color: NordicColors.secondaryFixed,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'ROUTE PREVIEW',
                                            overflow: TextOverflow.ellipsis,
                                            style: NordicText.labelMd.copyWith(
                                              color:
                                                  NordicColors.secondaryFixed,
                                              letterSpacing: 12 * 0.05,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Tw.a(NordicColors.primary, 0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      route == null
                                          ? '…'
                                          : '${Fmt.distance(route.distanceMeters)} · ~${Fmt.duration(route.durationSeconds)}',
                                      style: NordicText.labelSm.copyWith(
                                        color: NordicColors.surface,
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
                  ),
                  const SizedBox(height: 16),
                  // Trip summary card
                  Elevated(
                    shadows: Tw.md,
                    radius: 12,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NordicColors.surfaceContainerLowest,
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
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              color: NordicColors.secondary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              plan.pickup!.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: NordicText.titleSm
                                                  .copyWith(
                                                    color:
                                                        NordicColors.onSurface,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        margin: const EdgeInsets.only(left: 5),
                                        width: 2,
                                        height: 16,
                                        color: NordicColors
                                            .surfaceContainerHighest,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: NordicColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              plan.dropoff!.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: NordicText.titleSm
                                                  .copyWith(
                                                    color:
                                                        NordicColors.onSurface,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (total == null)
                                    const NordicSkeleton(width: 80, height: 28)
                                  else
                                    Text(
                                      total,
                                      key: const Key('confirm_total'),
                                      style: NordicText.currencyDisplay
                                          .copyWith(
                                            color: NordicColors.onSurface,
                                          ),
                                    ),
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
                                      Container(
                                        width: 56,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: NordicColors
                                              .surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Image.asset(
                                          _photos[plan.vehicle]!,
                                          fit: BoxFit.cover,
                                          semanticLabel:
                                              '${plan.vehicle.title} vehicle',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${plan.vehicle.title} · ${plan.vehicle.apiType[0].toUpperCase()}${plan.vehicle.apiType.substring(1)}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: NordicText.titleSm
                                                  .copyWith(
                                                    color:
                                                        NordicColors.onSurface,
                                                  ),
                                            ),
                                            Text(
                                              '${plan.vehicle.seats} seats · ${plan.vehicle.bags} bags',
                                              style: NordicText.bodySm.copyWith(
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
                                if (nearestEta != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Tw.a(
                                        NordicColors.secondaryContainer,
                                        0.4,
                                      ),
                                      borderRadius: BorderRadius.circular(9999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const MIcon(
                                          Symbols.schedule,
                                          size: 14,
                                          color:
                                              NordicColors.onSecondaryContainer,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$nearestEta min away',
                                          style: NordicText.labelSm.copyWith(
                                            color: NordicColors
                                                .onSecondaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const MIcon(
                                      Symbols.verified,
                                      size: 16,
                                      color: NordicColors.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Includes booking fee & tax',
                                      style: NordicText.labelSm.copyWith(
                                        color: NordicColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'No surge pricing',
                                  style: NordicText.labelSm.copyWith(
                                    color: NordicColors.onSurface,
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
                  // Fare breakdown expander (replaces the design's eco badge, which carried unverifiable claims)
                  GestureDetector(
                    key: const Key('toggle_breakdown'),
                    onTap: estimate == null
                        ? null
                        : () =>
                              setState(() => _showBreakdown = !_showBreakdown),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Tw.a(NordicColors.secondaryContainer, 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: NordicColors.secondary,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: MIcon(
                                Symbols.receipt_long,
                                size: 20,
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
                                  'Fare breakdown',
                                  style: NordicText.titleSm.copyWith(
                                    color: NordicColors.onSecondaryContainer,
                                  ),
                                ),
                                Text(
                                  _showBreakdown
                                      ? 'Tap to hide how your estimate is built'
                                      : 'Tap to see how your estimate is built',
                                  style: NordicText.bodySm.copyWith(
                                    color: NordicColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: _showBreakdown ? 0.25 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const MIcon(
                              Symbols.arrow_back_ios_new,
                              size: 20,
                              color: NordicColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showBreakdown && estimate != null) ...[
                    const SizedBox(height: 16),
                    FareBreakdownCard(
                      breakdown: estimate.breakdown,
                      title: 'Estimated fare breakdown',
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment Method',
                        style: NordicText.headlineSm.copyWith(
                          color: NordicColors.onSurface,
                        ),
                      ),
                      Text(
                        'Selected: ${plan.payment.apiValue == 'cash' ? 'Cash' : 'Card'}',
                        style: NordicText.labelSm.copyWith(
                          color: NordicColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _PayOption(
                    key: const Key('pay_card'),
                    selected: plan.payment == PaymentMethodType.card,
                    iconBg: NordicColors.surfaceContainerHighest,
                    icon: Symbols.credit_card,
                    iconColor: NordicColors.onSurfaceVariant,
                    title: 'Card',
                    subtitle: 'Visa, Mastercard, BankID',
                    onTap: () => ref
                        .read(tripPlanProvider.notifier)
                        .setPayment(PaymentMethodType.card),
                  ),
                  const SizedBox(height: 8),
                  _PayOption(
                    key: const Key('pay_cash'),
                    selected: plan.payment == PaymentMethodType.cash,
                    iconBg: NordicColors.surfaceContainerHighest,
                    icon: Symbols.payments,
                    iconColor: NordicColors.onSurfaceVariant,
                    title: 'Cash to Driver',
                    subtitle: total == null
                        ? 'Pay cash at trip completion'
                        : 'Pay $total cash at trip completion',
                    onTap: () => ref
                        .read(tripPlanProvider.notifier)
                        .setPayment(PaymentMethodType.cash),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    key: const Key('payment_info_banner'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: NordicColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            DesignAssets.cabin,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment selection',
                                style: NordicText.labelLg.copyWith(
                                  color: NordicColors.onSurface,
                                ),
                              ),
                              Text(
                                'Your choice is securely linked to your ride. Pay the driver directly if you chose cash.',
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
                  Padding(
                    padding: const EdgeInsets.only(top: 4 + 16, bottom: 24),
                    child: Column(
                      children: [
                        Semantics(
                          button: true,
                          enabled: canBook,
                          child: Opacity(
                            opacity: canBook || booking.isSubmitting ? 1 : 0.5,
                            child: Elevated(
                              shadows: Tw.lg,
                              radius: 8,
                              child: Material(
                                color: NordicColors.primary,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  key: const Key('request_ride'),
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: canBook ? _book : null,
                                  child: Container(
                                    height: 56,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: booking.isSubmitting
                                        ? const Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                      Colors.white,
                                                    ),
                                              ),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const MIcon(
                                                    Symbols.lock,
                                                    size: 20,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Book ride',
                                                    style: NordicText.titleSm
                                                        .copyWith(
                                                          color: Colors.white,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                total ?? '',
                                                style: NordicText
                                                    .currencyDisplay
                                                    .copyWith(
                                                      color: Colors.white,
                                                    ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tapping confirm sends your request to dispatch. You can cancel until your trip starts.',
                          textAlign: TextAlign.center,
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
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: StitchBackHeader(
              title: 'Confirm And Pay',
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayOption extends StatelessWidget {
  const _PayOption({
    super.key,
    required this.selected,
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final Color iconBg;
  final IconData icon;
  final Color iconColor;

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Elevated(
        shadows: selected ? Tw.md : Tw.sm,
        radius: 12,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? NordicColors.surfaceContainerLowest
                : NordicColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Elevated(
                      shadows: iconBg == NordicColors.tertiaryFixed
                          ? Tw.sm
                          : const [],
                      radius: 12,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: MIcon(
                            icon,
                            size: 24,
                            fill: 0,
                            color: iconColor,
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
                            title,
                            style: NordicText.titleSm.copyWith(
                              color: NordicColors.onSurface,
                            ),
                          ),
                          Text(
                            subtitle,
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
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected
                      ? NordicColors.secondary
                      : NordicColors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: MIcon(
                    Symbols.check,
                    size: 16,
                    weight: 700,
                    color: selected ? Colors.white : Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
