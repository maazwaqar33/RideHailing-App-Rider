import 'package:flutter/material.dart';

/// Nordic Mobility colour tokens (from the Stitch design system, light mode).
abstract final class NordicColors {
  // Material-style roles.
  static const Color surface = Color(0xFFF8F9FF);
  static const Color surfaceDim = Color(0xFFCBDBF5);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEFF4FF);
  static const Color surfaceContainer = Color(0xFFE5EEFF);
  static const Color surfaceContainerHigh = Color(0xFFDCE9FF);
  static const Color surfaceContainerHighest = Color(0xFFD3E4FE);
  static const Color onSurface = Color(0xFF0B1C30);
  static const Color onSurfaceVariant = Color(0xFF43474E);
  static const Color inverseSurface = Color(0xFF213145);
  static const Color inverseOnSurface = Color(0xFFEAF1FF);
  static const Color outline = Color(0xFF74777F);
  static const Color outlineVariant = Color(0xFFC4C6CF);
  static const Color surfaceTint = Color(0xFF485F82);

  static const Color primary = Color(0xFF00152F);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF0F2A4A);
  static const Color onPrimaryContainer = Color(0xFF7A92B7);
  static const Color inversePrimary = Color(0xFFB0C8F0);

  static const Color secondary = Color(0xFF006B5F);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF6DF5E1);
  static const Color onSecondaryContainer = Color(0xFF006F64);

  static const Color tertiary = Color(0xFF2E0700);
  static const Color tertiaryContainer = Color(0xFF521200);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Brand accents and neutrals described in DESIGN.md.
  static const Color deepFjord = Color(0xFF091A2F);
  static const Color accentTeal = Color(0xFF14B8A6);
  static const Color accentTealDark = Color(0xFF0D9488);
  static const Color accentTealSurface = Color(0xFFCCFBF1);
  static const Color canvas = Color(0xFFFFFFFF);
  static const Color surfaceSubdued = Color(0xFFF8FAFC);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0B1C30);
  static const Color textSecondary = Color(0xFF43474E);
  static const Color textSubdued = Color(0xFF74777F);

  // Operational status tokens.
  static const Color success = Color(0xFF10B981);
  static const Color successSurface = Color(0xFFECFDF5);
  static const Color successText = Color(0xFF065F46);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSurface = Color(0xFFFFFBEB);
  static const Color warningText = Color(0xFF92400E);
  static const Color critical = Color(0xFFF43F5E);
  static const Color criticalSurface = Color(0xFFFFF1F2);
  static const Color criticalText = Color(0xFF9F1239);
  static const Color criticalBorder = Color(0xFFFECDD3);
  static const Color info = Color(0xFF0284C7);
  static const Color infoSurface = Color(0xFFF0F9FF);
  static const Color infoText = Color(0xFF075985);

  /// Nordic Ember: payment brand / cancellations / ETA urgency (DESIGN.md tertiary).
  static const Color ember = Color(0xFFFF5B24);
  static const Color emberSurface = Color(0xFFFFEDE5);

  /// Slate 100 / tile fill used behind chips and tiles on cards.
  static const Color tile = Color(0xFFEFF4FF);

  // Stitch "fixed" and tertiary-container tokens (tailwind config of every screen).
  static const Color primaryFixed = Color(0xFFD4E3FF);
  static const Color primaryFixedDim = Color(0xFFB0C8F0);
  static const Color onPrimaryFixedVariant = Color(0xFF304869);
  static const Color secondaryFixed = Color(0xFF71F8E4);
  static const Color secondaryFixedDim = Color(0xFF4FDBC8);
  static const Color onSecondaryFixed = Color(0xFF00201C);
  static const Color onSecondaryFixedVariant = Color(0xFF005048);
  static const Color tertiaryFixed = Color(0xFFFFDBD0);
  static const Color tertiaryFixedDim = Color(0xFFFFB59F);
  static const Color onTertiaryFixedVariant = Color(0xFF852300);
  static const Color onTertiaryContainer = Color(0xFFFC5922);
  static const Color surfaceVariant = Color(0xFFD3E4FE);
  static const Color onSecondaryContainerTone = Color(0xFF006F64);

  static const Color star = Color(0xFFF59E0B);
}
