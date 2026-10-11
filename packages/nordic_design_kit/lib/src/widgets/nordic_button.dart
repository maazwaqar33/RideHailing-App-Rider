import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

enum NordicButtonVariant { primary, secondary, tertiary, destructive }

/// 56px high button with animated press scale and a loading state. While [isLoading]
/// the button ignores taps (prevents duplicate submissions) and shows a spinner.
class NordicButton extends StatefulWidget {
  const NordicButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = NordicButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final NordicButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool expand;

  @override
  State<NordicButton> createState() => _NordicButtonState();
}

class _NordicButtonState extends State<NordicButton> {
  bool _pressed = false;

  ({Color bg, Color fg, Color? border}) get _colors => switch (widget.variant) {
    NordicButtonVariant.primary => (
      bg: NordicColors.primaryContainer,
      fg: Colors.white,
      border: null,
    ),
    NordicButtonVariant.secondary => (
      bg: NordicColors.accentTeal,
      fg: Colors.white,
      border: null,
    ),
    NordicButtonVariant.tertiary => (
      bg: NordicColors.surfaceMuted,
      fg: NordicColors.primaryContainer,
      border: NordicColors.border,
    ),
    NordicButtonVariant.destructive => (
      bg: Colors.white,
      fg: NordicColors.error,
      border: NordicColors.criticalBorder,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    final enabled = widget.onPressed != null && !widget.isLoading;
    final disabledLook = widget.onPressed == null && !widget.isLoading;

    final child = widget.isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation(c.fg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20, color: c.fg),
                const SizedBox(width: NordicSpacing.sm),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: NordicText.titleSm.copyWith(
                    color: c.fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );

    final button = Semantics(
      button: true,
      enabled: enabled,
      label: widget.isLoading ? '${widget.label}, loading' : widget.label,
      child: AnimatedScale(
        scale: _pressed && enabled ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Opacity(
          opacity: disabledLook ? 0.5 : 1,
          child: Material(
            color: c.bg,
            shape: RoundedRectangleBorder(
              borderRadius: NordicRadii.controlRadius,
              side: c.border == null
                  ? BorderSide.none
                  : BorderSide(color: c.border!),
            ),
            child: InkWell(
              borderRadius: NordicRadii.controlRadius,
              onHighlightChanged: (v) {
                if (enabled && mounted) setState(() => _pressed = v);
              },
              onTap: enabled ? widget.onPressed : null,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(
                  horizontal: NordicSpacing.lg,
                ),
                alignment: Alignment.center,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    return widget.expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
