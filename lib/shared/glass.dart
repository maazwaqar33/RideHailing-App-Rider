import 'package:flutter/material.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import 'stitch.dart';

/// `bg-surface-container-lowest/95 backdrop-blur-md rounded-full shadow-*` chip floating over a map.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.child,
    required this.padding,
    this.radius = 9999,
    this.alpha = 0.95,
    this.color = NordicColors.surfaceContainerLowest,
    this.shadows = Tw.lg,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double alpha;
  final Color color;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) => Elevated(
    shadows: shadows,
    radius: radius,
    child: BackdropBlur(
      radius: radius,
      blur: 12,
      child: Container(
        padding: padding,
        color: Tw.a(color, alpha),
        child: child,
      ),
    ),
  );
}

/// Round white map button (`w-11 h-11 rounded-full bg-surface-container-lowest shadow-*`).
class RoundMapButton extends StatelessWidget {
  const RoundMapButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconSize = 20,
    this.iconColor = NordicColors.primary,
    this.background = NordicColors.surfaceContainerLowest,
    this.shadows = Tw.md,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color iconColor;
  final Color background;
  final List<BoxShadow> shadows;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onTap,
      child: Elevated(
        shadows: shadows,
        circle: true,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Center(
            child: MIcon(icon, size: iconSize, color: iconColor),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
