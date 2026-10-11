import 'package:flutter/material.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/formatting/formatters.dart';
import '../../../shared/stitch.dart';
import '../../rides/domain/ride_models.dart';

/// White `rounded-t-*` sheet that overlaps the map above it (`-mt-4` / `-mt-6`).
class SheetShell extends StatelessWidget {
  const SheetShell({
    super.key,
    required this.child,
    this.radius = 28,
    this.overlap = 16,
    this.color = NordicColors.surfaceContainerLowest,
    this.shadow = const [
      BoxShadow(
        color: Color(0x140F2A4A),
        blurRadius: 32,
        offset: Offset(0, -8),
      ),
    ],
  });

  final Widget child;
  final double radius;
  final double overlap;
  final Color color;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(0, -overlap),
    child: Elevated(
      shadows: shadow,
      radius: radius,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        ),
        child: child,
      ),
    ),
  );
}

/// Small centred drag handle.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key, this.width = 36, this.color});

  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: width,
      height: 4,
      decoration: BoxDecoration(
        color: color ?? Tw.a(NordicColors.outlineVariant, 0.6),
        borderRadius: BorderRadius.circular(9999),
      ),
    ),
  );
}

/// Vehicle plate as printed in `driver_found_erik_larsen`: blue "N" strip with the Norwegian flag
/// and a large letter-spaced plate. The plate text is the real `vehicle.plate_number`.
class PlateLarge extends StatelessWidget {
  const PlateLarge(this.plate, {super.key});

  final String plate;

  @override
  Widget build(BuildContext context) => Elevated(
    shadows: Tw.sm,
    radius: 6,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        color: NordicColors.surfaceContainerLowest,
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: NordicColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _NorwayFlag(),
                    const SizedBox(height: 2),
                    const Text(
                      'N',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Center(
                  child: Text(
                    plate.toUpperCase(),
                    key: const Key('vehicle_plate'),
                    style: NordicText.currencyDisplay.copyWith(
                      fontSize: 18,
                      color: NordicColors.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 18 * 0.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NorwayFlag extends StatelessWidget {
  const _NorwayFlag();

  @override
  Widget build(BuildContext context) => Container(
    width: 14,
    height: 10,
    decoration: BoxDecoration(
      color: const Color(0xFFDC2626),
      borderRadius: BorderRadius.circular(1),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(height: 2, color: Colors.white),
        Container(width: 2, color: Colors.white),
      ],
    ),
  );
}

/// Plate of `live_tracking_3_states`: small navy "N" box + bold tracked plate on a white chip.
class PlateSmall extends StatelessWidget {
  const PlateSmall(this.plate, {super.key});

  final String plate;

  @override
  Widget build(BuildContext context) => Elevated(
    shadows: Tw.sm,
    radius: 4,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: NordicColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 14,
            decoration: BoxDecoration(
              color: NordicColors.primary,
              borderRadius: BorderRadius.circular(1),
            ),
            alignment: Alignment.center,
            child: const Text(
              'N',
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w700,
                color: NordicColors.surface,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            plate,
            key: const Key('vehicle_plate'),
            style: NordicText.labelMd.copyWith(
              color: NordicColors.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 12 * 0.05,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Plate of `live_trip_driver_arrived_pin_4821`: tinted "N" tag + label-lg plate.
class PlateTag extends StatelessWidget {
  const PlateTag(this.plate, {super.key});

  final String plate;

  @override
  Widget build(BuildContext context) => Elevated(
    shadows: Tw.sm,
    radius: 4,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: NordicColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: NordicColors.secondaryFixed.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'N',
              style: NordicText.labelSm.copyWith(
                color: NordicColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            plate,
            key: const Key('vehicle_plate'),
            style: NordicText.labelLg.copyWith(
              color: NordicColors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 14 * 0.05,
            ),
          ),
        ],
      ),
    ),
  );
}

/// "★ 4.9 • 1,840+ trips" style line. DEMO values: the API has no driver rating.
class RatingLine extends StatelessWidget {
  const RatingLine({
    super.key,
    required this.rating,
    required this.suffix,
    this.starSize = 14,
    this.starColor = NordicColors.onTertiaryContainer,
    this.dot = '•',
    this.gap = 8,
    this.style,
    this.ratingStyle,
  });

  final String rating;
  final String suffix;
  final double starSize;
  final Color starColor;
  final String dot;
  final double gap;
  final TextStyle? style;
  final TextStyle? ratingStyle;

  @override
  Widget build(BuildContext context) {
    final base =
        style ??
        NordicText.labelSm.copyWith(
          color: NordicColors.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MIcon(Symbols.star, size: starSize, color: starColor),
        const SizedBox(width: 2),
        Text(
          rating,
          style:
              ratingStyle ??
              NordicText.labelMd.copyWith(
                color: NordicColors.onSurface,
                fontWeight: FontWeight.w700,
              ),
        ),
        SizedBox(width: gap),
        Text(dot, style: base.copyWith(color: NordicColors.outlineVariant)),
        SizedBox(width: gap),
        Flexible(
          child: Text(
            suffix,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: base,
          ),
        ),
      ],
    );
  }
}

/// True when the ride resource carries a phone number for the driver.
bool hasDriverPhone(Ride ride) => (ride.driver?.phone ?? '').trim().isNotEmpty;

/// Opens the phone app with `tel:<driver phone>`. Where the platform cannot place calls (desktop,
/// emulator without a dialer) the real number from the ride is shown instead.
Future<void> callDriver(BuildContext context, Ride ride) async {
  final phone = (ride.driver?.phone ?? '').trim();
  if (phone.isEmpty) return;
  var launched = false;
  try {
    launched = await launchUrl(Uri(scheme: 'tel', path: phone));
  } catch (_) {
    launched = false;
  }
  if (launched || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Driver phone'),
      content: SelectableText(phone, key: const Key('driver_phone')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// One quick-action tile. [kind] chooses the geometry of the design it is used in.
enum ActionTileStyle { found, live }

class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.style = ActionTileStyle.found,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ActionTileStyle style;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final found = style == ActionTileStyle.found;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: found ? 72 : 56,
        decoration: BoxDecoration(
          color: found
              ? NordicColors.surfaceContainerLow
              : NordicColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          boxShadow: found ? null : Tw.sm,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (found)
              Elevated(
                shadows: Tw.sm,
                circle: true,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: NordicColors.surfaceContainerLowest,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: MIcon(icon, size: 20, color: NordicColors.primary),
                  ),
                ),
              )
            else
              MIcon(
                icon,
                size: 20,
                color: danger ? NordicColors.error : NordicColors.primary,
              ),
            SizedBox(height: found ? 4 : 2),
            Text(
              label,
              style: NordicText.labelSm.copyWith(
                color: danger && !found
                    ? NordicColors.error
                    : NordicColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Call driver" action: dials the driver phone number from the ride resource. Chat, share and
/// SOS are intentionally absent (not built); the row is omitted when the ride has no phone.
class ActionRow extends StatelessWidget {
  const ActionRow({super.key, required this.ride, required this.style});

  final Ride ride;
  final ActionTileStyle style;

  @override
  Widget build(BuildContext context) {
    if (!hasDriverPhone(ride)) return const SizedBox.shrink();
    return ActionTile(
      key: const Key('action_call'),
      icon: Symbols.call,
      label: 'Call driver',
      style: style,
      onTap: () => callDriver(context, ride),
    );
  }
}

/// Payment method icon for a ride (cash / card).
IconData paymentIcon(Ride ride) =>
    PaymentMethodType.parse(ride.payment.method) == PaymentMethodType.cash
    ? Symbols.payments
    : Symbols.credit_card;

String paymentLabel(Ride ride) =>
    PaymentMethodType.parse(ride.payment.method).label;

/// Fare to show on a live ride: the final fare when known, otherwise the estimate / payable amount.
String rideTotal(Ride ride) =>
    Money.format(ride.fare.payableMinor ?? 0, ride.fare.currency);

/// "Cancel ride" button of the tracking sheets.
class CancelRideButton extends StatelessWidget {
  const CancelRideButton({super.key, required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('cancel_ride'),
    onTap: onCancel,
    child: Container(
      height: 56,
      decoration: BoxDecoration(
        color: NordicColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MIcon(
            Symbols.close,
            size: 18,
            lh: 24,
            color: NordicColors.error,
          ),
          const SizedBox(width: 8),
          Text(
            'Cancel ride',
            style: NordicText.titleSm.copyWith(
              color: NordicColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
