import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// The bare Nordic Mobility emblem (transparent PNG): app bars, onboarding, splash.
class NordicLogoMark extends StatelessWidget {
  const NordicLogoMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/nordic_logo.png',
    package: 'nordic_design_kit',
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticLabel: 'Nordic Mobility logo',
  );
}

/// Emblem with the "Nordic Mobility" wordmark (transparent PNG, about 1.08 : 1).
class NordicLogoFull extends StatelessWidget {
  const NordicLogoFull({super.key, this.height = 96});

  final double height;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/nordic_logo_full.png',
    package: 'nordic_design_kit',
    height: height,
    fit: BoxFit.contain,
    semanticLabel: 'Nordic Mobility',
  );
}

/// The Nordic Mobility logo (bundled in this package), optionally on a rounded white tile.
class NordicLogo extends StatelessWidget {
  const NordicLogo({super.key, this.size = 72, this.rounded = true});

  final double size;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/nordic_logo.png',
      package: 'nordic_design_kit',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Nordic Mobility logo',
    );
    if (!rounded) return image;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: NordicShadows.level2,
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }
}

/// Small rounded pill with optional leading icon/dot (e.g. "OSLO - ZERO EMISSION").
class NordicPill extends StatelessWidget {
  const NordicPill({
    super.key,
    required this.label,
    this.icon,
    this.dot = false,
    this.background = NordicColors.surfaceContainer,
    this.foreground = NordicColors.textPrimary,
    this.uppercase = false,
  });

  final String label;
  final IconData? icon;
  final bool dot;
  final Color background;
  final Color foreground;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: NordicRadii.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (icon != null) ...[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              uppercase ? label.toUpperCase() : label,
              overflow: TextOverflow.ellipsis,
              style: NordicText.labelMd.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Selectable pill chip (36px). Selected = solid navy with white text.
class NordicChip extends StatelessWidget {
  const NordicChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? NordicColors.primaryContainer
            : NordicColors.surfaceContainer,
        borderRadius: NordicRadii.pillRadius,
        child: InkWell(
          borderRadius: NordicRadii.pillRadius,
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: selected
                        ? Colors.white
                        : NordicColors.primaryContainer,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: NordicText.labelLg.copyWith(
                    color: selected
                        ? Colors.white
                        : NordicColors.primaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-or-more option segmented tab track (e.g. "Past Trips | Scheduled").
class NordicSegmented extends StatelessWidget {
  const NordicSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.enabled,
    this.onDisabledTap,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  /// Optional per-segment enabled flags.
  final List<bool>? enabled;

  /// Called when a disabled segment is tapped (e.g. to explain why it is unavailable).
  final ValueChanged<int>? onDisabledTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: NordicColors.surfaceContainer,
        borderRadius: NordicRadii.controlRadius,
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: (enabled?[i] ?? true)
                      ? () => onChanged(i)
                      : () => onDisabledTap?.call(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == index
                          ? NordicColors.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      labels[i],
                      style: NordicText.titleSm.copyWith(
                        fontSize: 14,
                        color: i == index
                            ? Colors.white
                            : ((enabled?[i] ?? true)
                                  ? NordicColors.textSecondary
                                  : NordicColors.textSubdued),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pickup (teal dot) and destination (navy square) joined by a dotted line.
class NordicRouteSummary extends StatelessWidget {
  const NordicRouteSummary({
    super.key,
    required this.pickupLabel,
    required this.dropoffLabel,
    this.pickupCaption,
    this.dropoffCaption,
    this.background,
  });

  final String pickupLabel;
  final String dropoffLabel;
  final String? pickupCaption;
  final String? dropoffCaption;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NordicSpacing.md),
      decoration: BoxDecoration(
        color: background ?? NordicColors.surfaceContainerLow,
        borderRadius: NordicRadii.cardRadius,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                const SizedBox(height: 6),
                const NordicRouteDot(),
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: NordicColors.border,
                  ),
                ),
                const NordicRouteDot(destination: true),
                const SizedBox(height: 6),
              ],
            ),
            const SizedBox(width: NordicSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pickupLabel,
                    style: NordicText.titleSm,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (pickupCaption != null)
                    Text(
                      pickupCaption!,
                      style: NordicText.bodySm.copyWith(
                        color: NordicColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: NordicSpacing.md),
                  Text(
                    dropoffLabel,
                    style: NordicText.titleSm,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (dropoffCaption != null)
                    Text(
                      dropoffCaption!,
                      style: NordicText.bodySm.copyWith(
                        color: NordicColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NordicRouteDot extends StatelessWidget {
  const NordicRouteDot({super.key, this.destination = false});

  final bool destination;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: destination
            ? NordicColors.primaryContainer
            : NordicColors.accentTeal,
        shape: destination ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: destination ? BorderRadius.circular(2) : null,
      ),
    );
  }
}

/// Round white floating control (recentre, layers) with Level 3 shadow.
class NordicFloatingButton extends StatelessWidget {
  const NordicFloatingButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: NordicShadows.level3,
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(icon, color: NordicColors.primaryContainer),
          ),
        ),
      ),
    );
  }
}

/// Small uppercase section label ("SAVED PLACES").
class NordicSectionLabel extends StatelessWidget {
  const NordicSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: NordicText.labelMd.copyWith(
              color: NordicColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Icon in a rounded tile + title/subtitle (+ optional trailing). Used in lists and settings.
class NordicListTile extends StatelessWidget {
  const NordicListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor = NordicColors.primaryContainer,
    this.iconBackground = NordicColors.surfaceContainer,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color iconBackground;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: NordicRadii.cardRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: NordicSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: NordicText.titleSm.copyWith(color: titleColor),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
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
      ),
    );
  }
}

/// Step progress track used by the multi-step sign-up.
class NordicStepProgress extends StatelessWidget {
  const NordicStepProgress({
    super.key,
    required this.step,
    required this.total,
  });

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $step of $total',
      child: ClipRRect(
        borderRadius: NordicRadii.pillRadius,
        child: LinearProgressIndicator(
          value: step / total,
          minHeight: 6,
          backgroundColor: NordicColors.surfaceContainer,
          valueColor: const AlwaysStoppedAnimation(NordicColors.accentTeal),
        ),
      ),
    );
  }
}

/// Persistent bottom sheet look used over maps (handle + Level 4 shadow).
class NordicMapSheet extends StatelessWidget {
  const NordicMapSheet({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: NordicShadows.level4,
      ),
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            NordicSpacing.md,
            12,
            NordicSpacing.md,
            NordicSpacing.md,
          ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: NordicSpacing.md),
                decoration: BoxDecoration(
                  color: NordicColors.border,
                  borderRadius: NordicRadii.pillRadius,
                ),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
