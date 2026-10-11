import 'package:flutter/material.dart';

import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

/// Light Material 3 theme built from the Nordic Mobility tokens.
abstract final class NordicTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: NordicColors.primaryContainer,
      onPrimary: NordicColors.onPrimary,
      primaryContainer: NordicColors.primaryContainer,
      onPrimaryContainer: NordicColors.onPrimaryContainer,
      secondary: NordicColors.secondary,
      onSecondary: NordicColors.onSecondary,
      secondaryContainer: NordicColors.secondaryContainer,
      onSecondaryContainer: NordicColors.onSecondaryContainer,
      tertiary: NordicColors.tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: NordicColors.tertiaryContainer,
      error: NordicColors.error,
      onError: NordicColors.onError,
      errorContainer: NordicColors.errorContainer,
      onErrorContainer: NordicColors.onErrorContainer,
      surface: NordicColors.surface,
      onSurface: NordicColors.onSurface,
      onSurfaceVariant: NordicColors.onSurfaceVariant,
      outline: NordicColors.outline,
      outlineVariant: NordicColors.outlineVariant,
      inverseSurface: NordicColors.inverseSurface,
      onInverseSurface: NordicColors.inverseOnSurface,
      inversePrimary: NordicColors.inversePrimary,
      surfaceTint: NordicColors.surfaceTint,
      surfaceContainerLowest: NordicColors.surfaceContainerLowest,
      surfaceContainerLow: NordicColors.surfaceContainerLow,
      surfaceContainer: NordicColors.surfaceContainer,
      surfaceContainerHigh: NordicColors.surfaceContainerHigh,
      surfaceContainerHighest: NordicColors.surfaceContainerHighest,
    );

    final textTheme = NordicText.textTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: NordicText.family,
      package: NordicText.package,
      textTheme: textTheme,
      scaffoldBackgroundColor: NordicColors.surface,
      dividerColor: NordicColors.border,
      appBarTheme: AppBarTheme(
        backgroundColor: NordicColors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: NordicColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: NordicText.titleMd,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NordicColors.primaryContainer
              : Colors.transparent,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NordicColors.deepFjord,
        contentTextStyle: NordicText.bodyMd.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: NordicRadii.controlRadius),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(NordicRadii.card),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: NordicRadii.cardRadius),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => NordicText.labelMd.copyWith(
            color: states.contains(WidgetState.selected)
                ? NordicColors.secondary
                : NordicColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? NordicColors.secondary
                : NordicColors.textSecondary,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: NordicColors.accentTeal,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NordicColors.secondary,
          textStyle: NordicText.labelLg,
        ),
      ),
    );
  }
}
