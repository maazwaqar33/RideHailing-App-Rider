import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Centered spinner with optional message.
class NordicLoader extends StatelessWidget {
  const NordicLoader({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          if (message != null) ...[
            const SizedBox(height: NordicSpacing.md),
            Text(
              message!,
              style: NordicText.bodyMd.copyWith(
                color: NordicColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pulsing placeholder block used while content loads.
class NordicSkeleton extends StatefulWidget {
  const NordicSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<NordicSkeleton> createState() => _NordicSkeletonState();
}

class _NordicSkeletonState extends State<NordicSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    final inTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (inTest) {
      _c.value = 0.5;
    } else {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            NordicColors.surfaceMuted,
            NordicColors.border,
            _c.value,
          ),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Skeleton for a card-like list row (avatar + two text lines).
class NordicSkeletonRow extends StatelessWidget {
  const NordicSkeletonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: NordicSpacing.sm),
      child: Row(
        children: [
          NordicSkeleton(width: 44, height: 44, radius: 22),
          SizedBox(width: NordicSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NordicSkeleton(height: 14),
                SizedBox(height: 8),
                NordicSkeleton(width: 140, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
