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
import '../../auth/application/session_controller.dart';
import '../../fare/domain/fare_models.dart';
import '../../map/application/map_providers.dart';
import '../../map/domain/map_models.dart';
import '../../rides/domain/ride_models.dart';

/// Stitch `ride_selection_oslo_s_to_osl`: route map with the duration / distance pill and the
/// "100% EV Zero Emission" chip, locate + layers buttons, origin/destination legend, and the white
/// "Select your ride" sheet with three vehicle cards (photo, seats, ETA, price), the payment row,
/// a notice row and the "Request (tier) - (price)" button, inside the tab chrome.
///
/// Real: pickup/drop-off, the fare (POST fares/estimate, the same for every vehicle because the
/// backend prices distance and time only), the payment method (cash / card, demo, never charged).
/// DEMO content: vehicle photos and class descriptions (Stitch placeholders), nearby-car ETAs and
/// markers (mock adapter), the "100% EV Zero Emission" brand chip.
class ChooseRideScreen extends ConsumerWidget {
  const ChooseRideScreen({super.key});

  static const _photos = {
    VehicleChoice.sedan: DemoPhotos.carStandard,
    VehicleChoice.estate: DemoPhotos.carComfort,
    VehicleChoice.van: DemoPhotos.carVan,
  };

  /// Class descriptions from the design (static demo copy: no vehicle-class data exists).
  static const _classes = {
    VehicleChoice.sedan: 'Camry or similar',
    VehicleChoice.estate: 'Extra legroom & heated seats',
    VehicleChoice.van: 'Mercedes EQV or similar',
  };

  static void _go(BuildContext context, int i) =>
      context.go(const ['/home', '/trips', '/wallet', '/profile'][i]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(tripPlanProvider);
    final route = ref.watch(routeProvider);
    final fare = ref.watch(fareEstimateProvider);
    final session = ref.watch(sessionControllerProvider);
    final cars =
        ref.watch(nearbyCarsProvider).asData?.value ?? const <NearbyCar>[];
    final userName = session is SessionAuthenticated ? session.user.name : '';

    if (!plan.isComplete) {
      return StitchNavScaffold(
        index: 0,
        onSelect: (i) => _go(context, i),
        sectionLabel: 'Ride Booking',
        userName: userName,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose a pickup and destination first.',
                  style: NordicText.bodyMd.copyWith(
                    color: NordicColors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                StitchButton(
                  label: 'Search destination',
                  onPressed: () => context.go('/search'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final routeInfo = route.asData?.value;
    final estimate = fare.asData?.value;
    final fareError = fare.hasError ? fare.error : null;
    final canContinue = estimate != null;
    final selected = plan.vehicle;
    final pickup = plan.pickup!;
    final dropoff = plan.dropoff!;
    final arrival = routeInfo == null
        ? null
        : DateTime.now().add(Duration(seconds: routeInfo.durationSeconds));
    final points = routeInfo?.points ?? [pickup.position, dropoff.position];

    return StitchNavScaffold(
      index: 0,
      onSelect: (i) => _go(context, i),
      sectionLabel: 'Ride Booking',
      userName: userName,
      body: SingleChildScrollView(
        key: const Key('ride_selection_scroll'),
        child: Column(
          children: [
            SizedBox(
              height: 320,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: NordicColors.surfaceContainer,
                      child: AppMap(
                        center: pickup.position,
                        interactive: false,
                        fitMaxZoom: 13.6,
                        fitPoints: [pickup.position, dropoff.position],
                        fitPadding: const EdgeInsets.fromLTRB(40, 70, 40, 70),
                        routePoints: points,
                        markers: [
                          for (final c in carsAround(pickup.position, cars))
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
                              Tw.a(NordicColors.primary, 0.2),
                              Tw.a(NordicColors.primary, 0),
                              Tw.a(NordicColors.primary, 0.4),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: _GlassPill(
                            key: const Key('route_pill'),
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
                                Flexible(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: routeInfo == null
                                              ? '...'
                                              : Fmt.duration(
                                                  routeInfo.durationSeconds,
                                                ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: NordicColors.primary,
                                          ),
                                        ),
                                        const TextSpan(
                                          text: '  ·  ',
                                          style: TextStyle(
                                            color: NordicColors.outline,
                                          ),
                                        ),
                                        TextSpan(
                                          text: routeInfo == null
                                              ? ''
                                              : '${Fmt.distance(routeInfo.distanceMeters)} (est.)',
                                        ),
                                      ],
                                    ),
                                    style: NordicText.labelMd.copyWith(
                                      color: NordicColors.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _GlassPill(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const MIcon(
                                Symbols.eco,
                                size: 14,
                                lh: 20,
                                fill: 1,
                                color: NordicColors.secondary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '100% EV Zero Emission',
                                  style: NordicText.labelSm.copyWith(
                                    color: NordicColors.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 24,
                    child: Column(
                      children: [
                        _RoundMapButton(
                          key: const Key('layers_button'),
                          icon: Symbols.layers,
                          onTap: () => context.push('/fleets'),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 24,
                    bottom: 16,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 210),
                      child: _GlassPill(
                        radius: 12,
                        alpha: 0.9,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LegendRow(
                              shape: BoxShape.circle,
                              color: NordicColors.secondary,
                              text: pickup.name,
                              strong: true,
                            ),
                            const SizedBox(height: 6),
                            _LegendRow(
                              shape: BoxShape.rectangle,
                              color: NordicColors.primary,
                              text: dropoff.name,
                              strong: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -16),
              child: Elevated(
                shadows: const [
                  BoxShadow(
                    color: Color(0x140F2A4A),
                    blurRadius: 30,
                    offset: Offset(0, -8),
                  ),
                ],
                radius: 24,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  decoration: const BoxDecoration(
                    color: NordicColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Tw.a(NordicColors.outlineVariant, 0.6),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select your ride',
                                    style: NordicText.headlineSm.copyWith(
                                      color: NordicColors.primary,
                                      letterSpacing: 20 * -0.025,
                                    ),
                                  ),
                                  Text(
                                    arrival == null
                                        ? 'Estimating your trip...'
                                        : 'Estimated arrival ${Fmt.time(arrival)}',
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
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: NordicColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Text(
                                'Oslo Metro',
                                style: NordicText.labelSm.copyWith(
                                  color: NordicColors.onPrimaryFixedVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (fareError != null) ...[
                        InlineError(
                          key: const Key('fare_error'),
                          message: fareError is ApiException
                              ? fareError.message
                              : 'We could not get a price. Check your connection and try again.',
                          onRetry: () => ref.invalidate(fareEstimateProvider),
                        ),
                        const SizedBox(height: 10),
                      ],

                      for (final (i, v) in VehicleChoice.values.indexed) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _TierCard(
                          choice: v,
                          selected: v == selected,
                          photo: _photos[v]!,
                          description: _classes[v]!,
                          etaMinutes: cars.length > i
                              ? cars[i].etaMinutes
                              : null,
                          estimate: estimate,
                          loading: fare.isLoading,
                          onTap: () =>
                              ref.read(tripPlanProvider.notifier).setVehicle(v),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _PaymentRow(
                        method: plan.payment,
                        onChange: () => _pickPayment(context, ref, plan),
                      ),
                      Container(
                        key: const Key('vehicle_note'),
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: NordicColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const MIcon(
                              Symbols.info,
                              size: 18,
                              lh: 24,
                              color: NordicColors.onPrimaryContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'One fare for every vehicle. Your choice is a preference.',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: NordicText.bodySm.copyWith(
                                  color: NordicColors.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Elevated(
                        shadows: Tw.xl,
                        radius: 16,
                        child: Opacity(
                          opacity: canContinue ? 1 : 0.5,
                          child: Material(
                            color: NordicColors.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              key: const Key('continue_to_payment'),
                              borderRadius: BorderRadius.circular(16),
                              onTap: canContinue
                                  ? () => context.push('/confirm-pay')
                                  : null,
                              child: SizedBox(
                                height: 56,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const MIcon(
                                      Symbols.electric_bolt,
                                      size: 20,
                                      color: NordicColors.secondaryFixed,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        estimate == null
                                            ? 'Getting your price...'
                                            : 'Request ${selected.title} • ${Money.format(estimate.totalMinor, estimate.currency)}',
                                        overflow: TextOverflow.ellipsis,
                                        style: NordicText.titleSm.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const MIcon(
                              Symbols.check_circle,
                              size: 12,
                              lh: 14,
                              color: NordicColors.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Cancel until the trip starts',
                              style: NordicText.labelSm.copyWith(
                                color: NordicColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '·',
                              style: NordicText.labelSm.copyWith(
                                color: NordicColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Cash / Card',
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
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _pickPayment(
    BuildContext context,
    WidgetRef ref,
    TripPlan plan,
  ) async {
    final picked = await showModalBottomSheet<PaymentMethodType>(
      context: context,
      backgroundColor: NordicColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Payment method',
                style: NordicText.headlineSm.copyWith(
                  color: NordicColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose your preferred payment method.',
                style: NordicText.bodySm.copyWith(
                  color: NordicColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (final m in PaymentMethodType.values)
                ListTile(
                  key: Key('pay_option_${m.apiValue}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: NordicColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: MIcon(
                        m == PaymentMethodType.cash
                            ? Symbols.payments
                            : Symbols.credit_card,
                        size: 22,
                        color: NordicColors.primary,
                      ),
                    ),
                  ),
                  title: Text(m.label, style: NordicText.titleSm),
                  trailing: m == plan.payment
                      ? const MIcon(
                          Symbols.check_circle,
                          size: 22,
                          color: NordicColors.secondary,
                        )
                      : null,
                  onTap: () => Navigator.pop(ctx, m),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) ref.read(tripPlanProvider.notifier).setPayment(picked);
  }
}

/// `bg-surface-container-lowest/95 backdrop-blur-md rounded-full shadow-lg` chip over the map.
class _GlassPill extends StatelessWidget {
  const _GlassPill({
    super.key,
    required this.child,
    required this.padding,
    this.radius = 9999,
    this.alpha = 0.95,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double alpha;

  @override
  Widget build(BuildContext context) => Elevated(
    shadows: Tw.lg,
    radius: radius,
    child: BackdropBlur(
      radius: radius,
      blur: 12,
      child: Container(
        padding: padding,
        color: Tw.a(NordicColors.surfaceContainerLowest, alpha),
        child: child,
      ),
    ),
  );
}

class _RoundMapButton extends StatelessWidget {
  const _RoundMapButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Elevated(
      shadows: Tw.xl,
      circle: true,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: NordicColors.surfaceContainerLowest,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: MIcon(icon, size: 18, color: NordicColors.onSurface),
        ),
      ),
    ),
  );
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.shape,
    required this.color,
    required this.text,
    required this.strong,
  });

  final BoxShape shape;
  final Color color;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle
              ? BorderRadius.circular(2)
              : null,
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: NordicText.labelSm.copyWith(
            color: strong
                ? NordicColors.onSurface
                : NordicColors.onSurfaceVariant,
            fontWeight: strong ? FontWeight.w600 : FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.choice,
    required this.selected,
    required this.photo,
    required this.description,
    required this.etaMinutes,
    required this.estimate,
    required this.loading,
    required this.onTap,
  });

  final VehicleChoice choice;
  final bool selected;
  final String photo;
  final String description;
  final int? etaMinutes;
  final FareEstimate? estimate;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final seatIcon = choice == VehicleChoice.van
        ? Symbols.group
        : Symbols.person;
    final titleColor = selected ? NordicColors.primary : NordicColors.onSurface;
    final seatColor = selected
        ? NordicColors.secondary
        : NordicColors.onSurfaceVariant;
    final card = Container(
      key: Key('vehicle_${choice.apiType}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected
            ? NordicColors.surfaceContainerLowest
            : NordicColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: selected
            ? Border.all(color: NordicColors.secondary, width: 2)
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 48,
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              choice.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: NordicText.titleSm.copyWith(
                                color: titleColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          MIcon(seatIcon, size: 14, lh: 14, color: seatColor),
                          const SizedBox(width: 2),
                          Text(
                            '${choice.seats}',
                            style: NordicText.labelSm.copyWith(
                              color: seatColor,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w600,
                            ),
                          ),
                          if (selected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color: NordicColors.secondaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Silent EV',
                                style: NordicText.labelSm.copyWith(
                                  color: NordicColors.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      selected
                          ? _SubtitleLine(
                              description: description,
                              etaMinutes: etaMinutes,
                              etaKey: Key('eta_${choice.apiType}'),
                              wrap: false,
                            )
                          : _SubtitleLine(
                              description: description,
                              etaMinutes: etaMinutes,
                              etaKey: Key('eta_${choice.apiType}'),
                              wrap: true,
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                loading || estimate == null
                    ? const SizedBox(
                        width: 56,
                        child: NordicSkeleton(height: 16, radius: 4),
                      )
                    : Text(
                        Money.format(estimate!.totalMinor, estimate!.currency),
                        key: Key('price_${choice.apiType}'),
                        style: NordicText.titleMd.copyWith(
                          color: NordicColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                Text(
                  selected ? 'Incl. fees & tax' : 'Estimated fare',
                  style: NordicText.labelSm.copyWith(
                    color: selected
                        ? NordicColors.secondary
                        : NordicColors.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          selected ? Elevated(shadows: Tw.md, radius: 16, child: card) : card,
          if (selected)
            Positioned(
              top: -10,
              right: 16,
              child: Elevated(
                shadows: Tw.sm,
                radius: 9999,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
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

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.method, required this.onChange});

  final PaymentMethodType method;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('payment_row'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: NordicColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Elevated(
                shadows: Tw.sm,
                circle: true,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: NordicColors.onTertiaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: MIcon(
                      method == PaymentMethodType.cash
                          ? Symbols.payments
                          : Symbols.credit_card,
                      size: 18,
                      color: NordicColors.surface,
                    ),
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
                        Flexible(
                          child: Text(
                            method.label,
                            key: const Key('payment_label'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NordicText.titleSm.copyWith(
                              color: NordicColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const MIcon(
                          Symbols.verified_user,
                          size: 12,
                          lh: 14,
                          color: NordicColors.secondary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Not charged in this version',
                          style: NordicText.labelSm.copyWith(
                            color: NordicColors.secondary,
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
        const SizedBox(width: 8),
        GestureDetector(
          key: const Key('change_payment'),
          onTap: onChange,
          child: Elevated(
            shadows: Tw.sm,
            radius: 9999,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: NordicColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Change',
                    style: NordicText.labelMd.copyWith(
                      color: NordicColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const MIcon(
                    Symbols.expand_more,
                    size: 16,
                    lh: 24,
                    color: NordicColors.primary,
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

/// "Camry or similar  ·  4 min away". Unselected cards wrap like the design; the selected card
/// is a single clipped line (the design truncates it).
class _SubtitleLine extends StatelessWidget {
  const _SubtitleLine({
    required this.description,
    required this.etaMinutes,
    required this.etaKey,
    required this.wrap,
  });

  final String description;
  final int? etaMinutes;
  final Key etaKey;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final base = NordicText.bodySm.copyWith(
      color: NordicColors.onSurfaceVariant,
    );
    final text = Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: description),
          if (etaMinutes != null) ...[
            const TextSpan(text: '  ·  '),
            TextSpan(
              text: '$etaMinutes min away',
              style: base.copyWith(
                color: NordicColors.secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
      maxLines: wrap ? 3 : 1,
      softWrap: wrap,
      overflow: wrap ? TextOverflow.ellipsis : TextOverflow.clip,
    );
    return Semantics(
      key: etaKey,
      label: etaMinutes == null ? null : '$etaMinutes min away',
      child: text,
    );
  }
}
