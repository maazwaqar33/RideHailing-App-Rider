import 'package:flutter/widgets.dart';

/// 8-point spacing scale, radii and shadows from DESIGN.md.
abstract final class NordicSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Page gutter on mobile (1rem).
  static const double gutterMobile = 16;
}

abstract final class NordicRadii {
  static const double sm = 8;
  static const double control = 16;
  static const double input = 16;
  static const double card = 16;
  static const double full = 9999;

  static BorderRadius get controlRadius => BorderRadius.circular(control);
  static BorderRadius get inputRadius => BorderRadius.circular(input);
  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get pillRadius => BorderRadius.circular(full);
}

abstract final class NordicShadows {
  /// Level 1: inline tiles, fare breakdowns, input wrappers.
  static const List<BoxShadow> level1 = [
    BoxShadow(color: Color(0x0A0F2A4A), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x050F2A4A), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Level 2: cards and service selectors.
  static const List<BoxShadow> level2 = [
    BoxShadow(
      color: Color(0x0F0F2A4A),
      blurRadius: 16,
      spreadRadius: -2,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x080F2A4A),
      blurRadius: 6,
      spreadRadius: -1,
      offset: Offset(0, 2),
    ),
  ];

  /// Level 3: floating map controls and modals.
  static const List<BoxShadow> level3 = [
    BoxShadow(
      color: Color(0x1A0F2A4A),
      blurRadius: 32,
      spreadRadius: -4,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x0A0F2A4A),
      blurRadius: 12,
      spreadRadius: -2,
      offset: Offset(0, 4),
    ),
  ];

  /// Level 4: draggable booking bottom sheets (top-facing).
  static const List<BoxShadow> level4 = [
    BoxShadow(color: Color(0x140F2A4A), blurRadius: 30, offset: Offset(0, -8)),
  ];
}
