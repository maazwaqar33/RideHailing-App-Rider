import 'package:flutter/material.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../shared/stitch.dart';

/// Tailwind `text-amber-400`, used for rating stars in the Stitch trip screens.
const Color kStarAmber = Color(0xFFFBBF24);

/// White rounded-xl card with `shadow-sm` (the Stitch receipt/rating card).
class StitchCard extends StatelessWidget {
  const StitchCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 12,
    this.color = NordicColors.surfaceContainerLowest,
    this.shadows = Tw.sm,
    this.backdrop,
  });

  /// Painted over the card colour and under [child], clipped to the card (e.g. a glow blob).
  final Widget? backdrop;
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) => Elevated(
    shadows: shadows,
    radius: radius,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: double.infinity,
        color: color,
        child: Stack(
          children: [
            if (backdrop != null) Positioned.fill(child: backdrop!),
            SizedBox(
              width: double.infinity,
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Interactive five-star control. Tap targets are `p-1` buttons around the glyph.
class StitchStars extends StatelessWidget {
  const StitchStars({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 30,
    this.gap = 8,
    this.minTarget = 0,
    this.activeColor = kStarAmber,
  });

  final int value;
  final ValueChanged<int>? onChanged;
  final double size;
  final double gap;
  final double minTarget;
  final Color activeColor;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var n = 1; n <= 5; n++) ...[
        if (n > 1) SizedBox(width: gap),
        Semantics(
          button: true,
          label: '$n star${n == 1 ? '' : 's'}',
          child: GestureDetector(
            key: ValueKey('star_$n'),
            behavior: HitTestBehavior.opaque,
            onTap: onChanged == null ? null : () => onChanged!(n),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minTarget,
                minHeight: minTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Center(
                  child: MIcon(
                    Symbols.star,
                    size: size,
                    lh: size * 1.2,
                    color: n <= value
                        ? activeColor
                        : NordicColors.outlineVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

/// Five-column tip selector (`grid-cols-5 gap-1.5`).
class TipSelector extends StatelessWidget {
  const TipSelector({
    super.key,
    required this.labels,
    required this.selected,
    required this.onTap,
    this.height = 44,
    this.selectedBackground = NordicColors.primaryContainer,
    this.unselectedBackground = NordicColors.surfaceContainerLow,
    this.unselectedForeground = NordicColors.onSurfaceVariant,
    this.sublabels = const {},
    this.keys = const [],
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onTap;
  final double height;
  final Color selectedBackground;
  final Color unselectedBackground;
  final Color unselectedForeground;

  /// Optional second line per index (e.g. "Popular").
  final Map<int, String> sublabels;
  final List<Key> keys;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < labels.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: GestureDetector(
            key: i < keys.length ? keys[i] : null,
            behavior: HitTestBehavior.opaque,
            onTap: onTap == null ? null : () => onTap!(i),
            child: Opacity(
              opacity: onTap == null && i != selected ? 0.6 : 1,
              child: Elevated(
                shadows: i == selected ? Tw.sm : const [],
                radius: 8,
                child: Container(
                  height: height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected
                        ? selectedBackground
                        : unselectedBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        labels[i],
                        maxLines: 1,
                        style: NordicText.labelMd.copyWith(
                          color: i == selected
                              ? Colors.white
                              : unselectedForeground,
                          fontWeight: i == selected
                              ? FontWeight.w600
                              : FontWeight.w600,
                        ),
                      ),
                      if (sublabels[i] != null)
                        Text(
                          sublabels[i]!,
                          style: NordicText.labelSm.copyWith(
                            color: i == selected
                                ? Colors.white.withValues(alpha: 0.9)
                                : unselectedForeground,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

/// Initials avatar used where the design shows a driver/rider photo (the API has no photos).
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    super.key,
    required this.name,
    required this.size,
    this.ring,
    this.shadow = Tw.sm,
  });

  final String name;
  final double size;
  final BoxShadow? ring;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    final t = name.trim();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: NordicColors.accentTealSurface,
        shape: BoxShape.circle,
        boxShadow: [
          ...?(ring == null ? null : [ring!]),
          ...shadow,
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        t.isEmpty ? '?' : t[0].toUpperCase(),
        style: NordicText.headlineSm.copyWith(
          color: NordicColors.secondary,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A label/value row of the fare summary (`body-sm`, value `font-medium text-primary`).
class FareRow extends StatelessWidget {
  const FareRow({
    super.key,
    required this.label,
    required this.value,
    this.suffix,
    this.valueKey,
  });

  final String label;
  final String value;
  final String? suffix;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Text(
            label,
            style: NordicText.bodySm.copyWith(
              color: NordicColors.onSurfaceVariant,
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 6),
            Text(
              suffix!,
              style: NordicText.labelSm.copyWith(color: NordicColors.outline),
            ),
          ],
        ],
      ),
      Text(
        value,
        key: valueKey,
        style: NordicText.bodySm.copyWith(
          color: NordicColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}
