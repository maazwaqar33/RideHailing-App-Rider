import 'package:flutter/material.dart';

import 'colors.dart';

/// Inter-based type scale (DESIGN.md). Financial fields, ETAs and plates use
/// tabular figures via [NordicText.tabular].
abstract final class NordicText {
  static const String family = 'Inter';

  /// Package that bundles the font files (needed so the app resolves 'Inter').
  static const String package = 'nordic_design_kit';
  static const List<FontFeature> _tnum = [FontFeature.tabularFigures()];

  static TextStyle _s(
    double size,
    FontWeight w,
    double height, {
    double letter = 0,
  }) => TextStyle(
    fontFamily: family,
    package: package,
    fontSize: size,
    fontWeight: w,
    height: height / size,
    letterSpacing: letter * size,
    color: NordicColors.textPrimary,
  );

  // Type scale from the Rider DESIGN.md.
  static final TextStyle displayLg = _s(40, FontWeight.w700, 48, letter: -0.02);
  static final TextStyle displayLgMobile = _s(
    32,
    FontWeight.w700,
    40,
    letter: -0.02,
  );
  static final TextStyle headlineLg = _s(
    28,
    FontWeight.w600,
    36,
    letter: -0.015,
  );
  static final TextStyle headlineMd = _s(
    24,
    FontWeight.w600,
    32,
    letter: -0.01,
  );
  static final TextStyle headlineSm = _s(
    20,
    FontWeight.w600,
    28,
    letter: -0.005,
  );
  static final TextStyle titleMd = _s(18, FontWeight.w600, 24);
  static final TextStyle titleSm = _s(16, FontWeight.w600, 22);
  static final TextStyle bodyLg = _s(18, FontWeight.w400, 28);
  static final TextStyle bodyMd = _s(16, FontWeight.w400, 24);
  static final TextStyle bodySm = _s(14, FontWeight.w400, 20, letter: 0.01);
  static final TextStyle labelLg = _s(14, FontWeight.w500, 20, letter: 0.01);
  static final TextStyle labelMd = _s(12, FontWeight.w600, 16, letter: 0.02);
  static final TextStyle labelSm = _s(10, FontWeight.w600, 14, letter: 0.04);
  static final TextStyle currencyDisplay = _s(
    22,
    FontWeight.w700,
    28,
    letter: -0.01,
  ).copyWith(fontFeatures: _tnum);

  /// Adds tabular figures to any style (money, ETA, plates).
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: _tnum);

  static TextTheme textTheme() => TextTheme(
    displaySmall: displayLgMobile,
    headlineLarge: headlineLg,
    headlineMedium: headlineMd,
    headlineSmall: headlineSm,
    titleLarge: titleMd,
    titleMedium: titleSm,
    titleSmall: labelLg,
    bodyLarge: bodyLg,
    bodyMedium: bodyMd,
    bodySmall: bodySm.copyWith(color: NordicColors.textSecondary),
    labelLarge: labelLg,
    labelMedium: labelMd,
    labelSmall: labelSm,
  );
}
