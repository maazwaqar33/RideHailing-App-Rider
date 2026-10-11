import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// White 16px-radius card with a hairline border, smooth selection and press animations.
class NordicCard extends StatefulWidget {
  const NordicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NordicSpacing.md),
    this.elevated = false,
    this.onTap,
    this.selected = false,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool elevated;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  State<NordicCard> createState() => _NordicCardState();
}

class _NordicCardState extends State<NordicCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: Colors.white,
      borderRadius: NordicRadii.cardRadius,
      border: Border.all(
        color: widget.selected
            ? NordicColors.primaryContainer
            : NordicColors.border,
        width: widget.selected ? 2 : 1,
      ),
      boxShadow: widget.elevated || widget.selected
          ? NordicShadows.level2
          : NordicShadows.level1,
    );
    final content = Padding(padding: widget.padding, child: widget.child);

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: widget.margin,
      decoration: decoration,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: NordicRadii.cardRadius,
        child: widget.onTap == null
            ? content
            : InkWell(
                borderRadius: NordicRadii.cardRadius,
                onHighlightChanged: (v) {
                  if (mounted) setState(() => _pressed = v);
                },
                onTap: widget.onTap,
                child: content,
              ),
      ),
    );

    if (widget.onTap == null) return card;

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: card,
    );
  }
}
