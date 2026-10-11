import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'nordic_button.dart';

enum NordicTone { success, pending, critical, info, neutral }

({Color bg, Color fg, Color dot, Color border}) _tone(NordicTone tone) =>
    switch (tone) {
      NordicTone.success => (
        bg: NordicColors.successSurface,
        fg: NordicColors.successText,
        dot: NordicColors.success,
        border: const Color(0xFFA7F3D0),
      ),
      NordicTone.pending => (
        bg: NordicColors.warningSurface,
        fg: NordicColors.warningText,
        dot: NordicColors.warning,
        border: const Color(0xFFFDE68A),
      ),
      NordicTone.critical => (
        bg: NordicColors.criticalSurface,
        fg: NordicColors.criticalText,
        dot: NordicColors.critical,
        border: NordicColors.criticalBorder,
      ),
      NordicTone.info => (
        bg: NordicColors.infoSurface,
        fg: NordicColors.infoText,
        dot: NordicColors.info,
        border: const Color(0xFFBAE6FD),
      ),
      NordicTone.neutral => (
        bg: NordicColors.surfaceMuted,
        fg: NordicColors.textSecondary,
        dot: NordicColors.textSubdued,
        border: NordicColors.border,
      ),
    };

/// Pill-shaped status badge with a leading dot (DESIGN.md "Status Badges & Chips").
class NordicStatusBadge extends StatelessWidget {
  const NordicStatusBadge({
    super.key,
    required this.label,
    this.tone = NordicTone.neutral,
  });

  final String label;
  final NordicTone tone;

  @override
  Widget build(BuildContext context) {
    final c = _tone(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: NordicRadii.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: NordicText.labelSm.copyWith(color: c.fg),
          ),
        ],
      ),
    );
  }
}

/// Inline banner for info / warning / error / mock disclosures.
class NordicBanner extends StatelessWidget {
  const NordicBanner({
    super.key,
    required this.message,
    this.tone = NordicTone.info,
    this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final NordicTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  IconData get _defaultIcon => switch (tone) {
    NordicTone.success => Icons.check_circle_outline,
    NordicTone.pending => Icons.warning_amber_rounded,
    NordicTone.critical => Icons.error_outline,
    NordicTone.info => Icons.info_outline,
    NordicTone.neutral => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    final c = _tone(tone);
    return Semantics(
      container: true,
      liveRegion: tone == NordicTone.critical,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(NordicSpacing.md),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: NordicRadii.controlRadius,
          border: Border.all(color: c.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? _defaultIcon, color: c.dot, size: 20),
            const SizedBox(width: NordicSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: NordicText.labelLg.copyWith(color: c.fg),
                    ),
                  Text(message, style: NordicText.bodyMd.copyWith(color: c.fg)),
                  if (actionLabel != null && onAction != null)
                    Padding(
                      padding: const EdgeInsets.only(top: NordicSpacing.sm),
                      child: GestureDetector(
                        onTap: onAction,
                        child: Text(
                          actionLabel!,
                          style: NordicText.labelLg.copyWith(
                            color: c.fg,
                            decoration: TextDecoration.underline,
                          ),
                        ),
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

/// Small amber chip that marks UI backed by mock data. Use it everywhere a value
/// is NOT real telemetry or a real transaction.
class NordicMockBadge extends StatelessWidget {
  const NordicMockBadge({super.key, this.label = 'MOCK'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: NordicColors.warningSurface,
        borderRadius: NordicRadii.pillRadius,
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Text(
        label,
        style: NordicText.labelSm.copyWith(
          color: NordicColors.warningText,
          fontSize: 10,
        ),
      ),
    );
  }
}

/// Circle avatar with initials fallback (used for rider/driver placeholders).
class NordicAvatar extends StatelessWidget {
  const NordicAvatar({
    super.key,
    required this.name,
    this.size = 48,
    this.imageUrl,
  });

  final String name;
  final double size;
  final String? imageUrl;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final second = parts.length > 1 ? parts.last[0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Avatar of $name',
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: NordicColors.accentTealSurface,
        foregroundImage: imageUrl == null ? null : NetworkImage(imageUrl!),
        child: Text(
          _initials,
          style: NordicText.titleMd.copyWith(
            color: NordicColors.secondary,
            fontSize: size * 0.34,
          ),
        ),
      ),
    );
  }
}

/// Checkbox + arbitrary rich label row (terms & privacy consent).
class NordicCheckboxRow extends StatelessWidget {
  const NordicCheckboxRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.errorText,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget label;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            const SizedBox(width: NordicSpacing.sm + 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: label,
              ),
            ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 36),
            child: Text(
              errorText!,
              style: NordicText.bodySm.copyWith(color: NordicColors.error),
            ),
          ),
      ],
    );
  }
}

/// Full-area error state with retry.
class NordicErrorView extends StatelessWidget {
  const NordicErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Something went wrong',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NordicSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: NordicColors.textSubdued,
            ),
            const SizedBox(height: NordicSpacing.md),
            Text(title, style: NordicText.titleMd, textAlign: TextAlign.center),
            const SizedBox(height: NordicSpacing.xs),
            Text(
              message,
              style: NordicText.bodyMd.copyWith(
                color: NordicColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: NordicSpacing.md),
              NordicButton(
                label: 'Try again',
                onPressed: onRetry,
                variant: NordicButtonVariant.tertiary,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
