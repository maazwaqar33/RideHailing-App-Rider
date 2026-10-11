import 'package:flutter/material.dart';

import '../tokens/colors.dart';

/// 1-5 star rating. Interactive when [onChanged] is provided, otherwise display-only.
/// Each star is individually tappable and exposes semantics for tests and a11y.
class NordicRatingStars extends StatelessWidget {
  const NordicRatingStars({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 32,
    this.count = 5,
  });

  /// Current rating, 0 means "not rated yet".
  final int value;
  final ValueChanged<int>? onChanged;
  final double size;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final n = i + 1;
        final filled = n <= value;
        final icon = Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: filled ? NordicColors.star : NordicColors.outlineVariant,
        );
        return Semantics(
          button: onChanged != null,
          selected: filled,
          label: '$n ${n == 1 ? 'star' : 'stars'}',
          child: GestureDetector(
            key: ValueKey('star_$n'),
            behavior: HitTestBehavior.opaque,
            onTap: onChanged == null ? null : () => onChanged!(n),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: icon,
            ),
          ),
        );
      }),
    );
  }
}
