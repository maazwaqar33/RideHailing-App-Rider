import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

/// Helpers that reproduce the Stitch (Tailwind) building blocks 1:1 in Flutter.
///
/// Tailwind -> Flutter notes used throughout:
///  * `blur-xl/2xl/3xl` = 24/40/64 px blur radius -> Gaussian sigma = radius / 2
///  * box-shadow blur radius == Flutter `BoxShadow.blurRadius`
///  * `space-x-n` / `gap-n` = n * 4 px
///  * Material Symbols are rendered with the same variable font axes as the HTML (wght 400, GRAD 0, opsz 24)
abstract final class Tw {
  // Tailwind default shadows (colour is black unless noted).
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> base = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 2,
      spreadRadius: -1,
      offset: Offset(0, 1),
    ),
  ];
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 6,
      spreadRadius: -1,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      spreadRadius: -2,
      offset: Offset(0, 2),
    ),
  ];
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 15,
      spreadRadius: -3,
      offset: Offset(0, 10),
    ),
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 6,
      spreadRadius: -4,
      offset: Offset(0, 4),
    ),
  ];
  static const List<BoxShadow> xl = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 25,
      spreadRadius: -5,
      offset: Offset(0, 20),
    ),
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 10,
      spreadRadius: -6,
      offset: Offset(0, 8),
    ),
  ];
  static const List<BoxShadow> xl2 = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 50,
      spreadRadius: -12,
      offset: Offset(0, 25),
    ),
  ];

  /// `ring-N`: a solid box-shadow outline.
  static BoxShadow ring(Color c, [double w = 2]) =>
      BoxShadow(color: c, spreadRadius: w);

  static Color a(Color c, double opacity) => c.withValues(alpha: opacity);
}

/// The Stitch screenshots render every Material Symbol OUTLINED, even where the HTML asks for
/// `'FILL' 1` (the capture font lacked the FILL axis). To match the screenshots 1:1 the `fill`
/// request is ignored unless this flag is flipped.
const bool kHonorIconFill = false;

/// Material Symbols (Outlined) with the HTML's font axes (wght 400, GRAD 0, opsz 24).
///
/// [lh] reproduces the CSS line box of the glyph's `<span>`: Tailwind `text-sm` etc. give the
/// span a 20 px (or token) line-height, which makes pills/rows taller than the glyph itself.
class MIcon extends StatelessWidget {
  const MIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.fill = 0,
    this.color,
    this.weight = 400,
    this.lh,
  });

  final IconData icon;
  final double size;
  final double fill;
  final double weight;
  final Color? color;
  final double? lh;

  @override
  Widget build(BuildContext context) {
    final w = Icon(
      icon,
      size: size,
      fill: kHonorIconFill ? fill : 0,
      weight: weight,
      grade: 0,
      opticalSize: 24,
      color: color,
    );
    if (lh == null) return w;
    return SizedBox(
      height: lh,
      width: size,
      child: Center(child: w),
    );
  }
}

/// A soft glow circle (`blur-3xl` etc.). [blur] is the CSS `blur()` length (= Gaussian sigma).
///
/// Performance: instead of an `ImageFiltered` blur (an offscreen layer + Gaussian pass on every
/// repaint) the glow is a radial gradient whose alpha ramp is the numerically computed profile of
/// a Gaussian-blurred disc, painted once inside a [RepaintBoundary]. Visually equivalent, no
/// saveLayer, no blur shader.
class Blob extends StatelessWidget {
  const Blob({
    super.key,
    required this.size,
    required this.color,
    required this.blur,
  });

  final double size;
  final Color color;
  final double blur;

  static final Map<(double, double), List<double>> _profiles = {};

  /// Alpha (0..1) of a Gaussian(sigma)-blurred disc of radius [r] at [n]+1 evenly spaced radii
  /// from the centre to `r + 3 sigma`.
  static List<double> _profile(double r, double sigma, int n) {
    return _profiles.putIfAbsent((r, sigma), () {
      final reach = r + 3 * sigma;
      const g = 28; // sample grid inside the disc
      final out = <double>[];
      final norm = 1 / (2 * 3.141592653589793 * sigma * sigma);
      final cell = (2 * r) / g;
      for (var i = 0; i <= n; i++) {
        final rho = reach * i / n;
        var sum = 0.0;
        for (var ix = 0; ix < g; ix++) {
          final x = -r + (ix + 0.5) * cell;
          for (var iy = 0; iy < g; iy++) {
            final y = -r + (iy + 0.5) * cell;
            if (x * x + y * y > r * r) continue;
            final dx = x - rho;
            final d2 = dx * dx + y * y;
            sum += math.exp(-d2 / (2 * sigma * sigma));
          }
        }
        out.add((sum * norm * cell * cell).clamp(0.0, 1.0));
      }
      return out;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = size / 2;
    final reach = r + 3 * blur;
    const n = 14;
    final alphas = _profile(r, blur, n);
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -(reach - r),
              top: -(reach - r),
              right: -(reach - r),
              bottom: -(reach - r),
              child: RepaintBoundary(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        for (final a in alphas)
                          color.withValues(alpha: color.a * a),
                      ],
                      stops: [for (var i = 0; i <= n; i++) i / n],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Blurs its child with a Gaussian of standard deviation [sigma]
/// (CSS `filter: blur(Npx)` => sigma N; CSS box-shadow blur B => sigma B / 2).
class Blurred extends StatelessWidget {
  const Blurred({super.key, required this.sigma, required this.child});

  final double sigma;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.decal,
      ),
      child: child,
    ),
  );
}

/// Paints CSS-style box shadows behind [child].
///
/// Performance: by default this is a plain [BoxDecoration.boxShadow] (a cached mask-filter blur,
/// cheap on every GPU). The original implementation (a Gaussian `ImageFiltered` per shadow, clipped
/// to the outside of the box) forced an offscreen layer per card and was the main raster cost on
/// mid-range phones; it is only kept for the headless visual-QA renders (where mask-filter blurs are
/// skipped): set [useImageFilterShadows] in the test config.
class Elevated extends StatelessWidget {
  const Elevated({
    super.key,
    required this.shadows,
    required this.child,
    this.radius = 0,
    this.circle = false,
  });

  /// Test-only switch, see the class comment.
  static bool useImageFilterShadows = false;

  final List<BoxShadow> shadows;
  final Widget child;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    if (shadows.isEmpty) return child;
    if (!useImageFilterShadows) {
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(radius),
          boxShadow: shadows,
        ),
        child: child,
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        // CSS box-shadows are never painted under the element's own box; clip the blurred shapes
        // to the outside of the (rounded) box so translucent fills look the same as in the browser.
        Positioned.fill(
          child: ClipPath(
            clipper: _OutsideClipper(radius: radius, circle: circle),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final s in shadows)
                  Positioned(
                    left: s.offset.dx - s.spreadRadius,
                    top: s.offset.dy - s.spreadRadius,
                    right: -s.offset.dx - s.spreadRadius,
                    bottom: -s.offset.dy - s.spreadRadius,
                    child: Blurred(
                      sigma: s.blurRadius / 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: s.color,
                          shape: circle ? BoxShape.circle : BoxShape.rectangle,
                          borderRadius: circle
                              ? null
                              : BorderRadius.circular(
                                  (radius + s.spreadRadius).clamp(0, 9999),
                                ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _OutsideClipper extends CustomClipper<Path> {
  const _OutsideClipper({required this.radius, required this.circle});

  final double radius;
  final bool circle;

  @override
  Path getClip(Size size) {
    final rect = Offset.zero & size;
    final inner = circle
        ? (Path()..addOval(rect))
        : (Path()..addRRect(
            RRect.fromRectAndRadius(
              rect,
              Radius.circular(radius.clamp(0, size.shortestSide / 2)),
            ),
          ));
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(rect.inflate(2000)),
      inner,
    );
  }

  @override
  bool shouldReclip(covariant _OutsideClipper old) =>
      old.radius != radius || old.circle != circle;
}

/// `backdrop-blur-*` over a translucent fill.
///
/// Performance: a [BackdropFilter] re-blurs everything behind it on every frame (it needs an
/// offscreen copy of the backdrop), which is very expensive over a moving map on mid-range GPUs.
/// The glass panels in this app all carry a mostly opaque translucent fill, so the blur is dropped:
/// the child is just clipped to its rounded shape. [blur] is kept for API compatibility.
class BackdropBlur extends StatelessWidget {
  const BackdropBlur({
    super.key,
    required this.child,
    this.radius = 12,
    this.blur = 12,
    this.borderRadius,
  });

  final Widget child;
  final double radius;
  final double blur;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: borderRadius ?? BorderRadius.circular(radius),
    child: child,
  );
}

/// Static map backdrop used by the design's map screens when real tiles are not wanted
/// (visual QA renders). The runtime app uses [AppMap] instead.
class StitchMapImage extends StatelessWidget {
  const StitchMapImage(
    this.asset, {
    super.key,
    this.alignment = Alignment.center,
    this.fit = BoxFit.cover,
  });

  final String asset;
  final Alignment alignment;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    fit: fit,
    alignment: alignment,
    width: double.infinity,
    height: double.infinity,
  );
}

/// Paths of the design imagery bundled under assets/design.
abstract final class DesignAssets {
  static const logo = 'assets/images/stitch/logo.jpg';
  static const logoSheet = 'assets/images/stitch/logo_sheet.jpg';
  static const emblem = 'assets/images/stitch/emblem.jpg';
  static const skyline = 'assets/images/stitch/oslo_skyline.jpg';
  static const mapHome = 'assets/images/stitch/map_oslo_home.png';
  static const mapPickup = 'assets/images/stitch/map_oslo_pickup.png';
  static const mapA = 'assets/images/stitch/map_oslo_a.png';
  static const mapB = 'assets/images/stitch/map_oslo_b.png';
  static const mapC = 'assets/images/stitch/map_oslo_c.png';
  static const mapLive = 'assets/images/stitch/map_oslo_live.png';
  static const mapGardermoen = 'assets/images/stitch/map_gardermoen.png';
  static const carStandard = 'assets/images/stitch/car_camry_standard.jpg';
  static const carStandardWhite = 'assets/images/stitch/car_standard_white.jpg';
  static const carComfort = 'assets/images/stitch/car_camry_silver.jpg';
  static const carComfortPolestar =
      'assets/images/stitch/car_comfort_polestar.jpg';
  static const carVan = 'assets/images/stitch/car_van_black.jpg';
  static const carVanEqv = 'assets/images/stitch/car_van_eqv.jpg';
  static const cabin = 'assets/images/stitch/cabin_dashboard.jpg';
  static const avatarSara = 'assets/images/stitch/avatar_sara.jpg';
}

/// DEMO PLACEHOLDER PHOTOS taken from the Stitch export (`assets/images/stitch`).
///
/// The backend has no photo for riders, drivers or vehicles, so wherever the design shows a
/// portrait or a car picture the app shows the same static Stitch image. They are NOT the real
/// person/vehicle: the name, plate and car model next to them always come from the API.
abstract final class DemoPhotos {
  /// Rider avatar ("Sara") shown for every rider.
  static const rider = 'assets/images/stitch/avatar_sara.jpg';

  /// Driver portrait ("Erik"), one crop per Stitch screen.
  static const driverFound = 'assets/images/stitch/driver_erik_1.jpg';
  static const driverTracking = 'assets/images/stitch/driver_erik_2.jpg';
  static const driverArrived = 'assets/images/stitch/driver_erik_3.jpg';
  static const driverRating = 'assets/images/stitch/driver_erik_4.jpg';
  static const driverHistory = 'assets/images/stitch/driver_erik_5.jpg';
  static const driverReceipt = 'assets/images/stitch/driver_erik_6.jpg';

  /// Vehicle pictures (Standard / Comfort / XL) from the ride-selection screens.
  static const carStandard = 'assets/images/stitch/car_camry_standard.jpg';
  static const carComfort = 'assets/images/stitch/car_camry_silver.jpg';
  static const carVan = 'assets/images/stitch/car_van_black.jpg';

  /// Vehicle pictures of the "Available Fleets" screen (object-contain on white).
  static const fleetStandard = 'assets/images/stitch/car_standard_white.jpg';
  static const fleetComfort = 'assets/images/stitch/car_comfort_polestar.jpg';
  static const fleetVan = 'assets/images/stitch/car_van_eqv.jpg';
}

/// Round photo with an optional ring (`rounded-full object-cover ring-2 ...`).
class PhotoCircle extends StatelessWidget {
  const PhotoCircle(
    this.asset, {
    super.key,
    required this.size,
    this.ring,
    this.ringWidth = 2,
    this.shadows = const [],
    this.semanticLabel,
  });

  final String asset;
  final double size;
  final Color? ring;
  final double ringWidth;
  final List<BoxShadow> shadows;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        if (ring != null) BoxShadow(color: ring!, spreadRadius: ringWidth),
        ...shadows,
      ],
    ),
    child: ClipOval(
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: semanticLabel,
      ),
    ),
  );
}

/// The signed-in rider's avatar: the Stitch demo portrait with the secondary-container ring.
class RiderAvatar extends StatelessWidget {
  const RiderAvatar({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => PhotoCircle(
    DemoPhotos.rider,
    size: size,
    ring: NordicColors.secondaryContainer,
    semanticLabel: 'Profile',
  );
}

/// Rounded `bg-primary text-on-primary` CTA used across the Stitch screens (h-14, rounded-xl).
class StitchButton extends StatelessWidget {
  const StitchButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.background = NordicColors.primary,
    this.foreground = Colors.white,
    this.radius = 12,
    this.height = 56,
    this.shadow = Tw.md,
    this.loading = false,
    this.trailingIcon = true,
    this.textStyle,
    this.border,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final double radius;
  final double height;
  final List<BoxShadow> shadow;
  final bool loading;
  final bool trailingIcon;
  final TextStyle? textStyle;
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: loading ? '$label, loading' : label,
      child: Opacity(
        opacity: onPressed == null && !loading ? 0.5 : 1,
        child: Elevated(
          shadows: shadow,
          radius: radius,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(radius),
              border: border == null ? null : Border.fromBorderSide(border!),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: enabled ? onPressed : null,
                child: Center(
                  child: loading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(foreground),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null && !trailingIcon) ...[
                              MIcon(icon!, size: 20, color: foreground),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                                style: (textStyle ?? NordicText.titleSm)
                                    .copyWith(color: foreground),
                              ),
                            ),
                            if (icon != null && trailingIcon) ...[
                              const SizedBox(width: 8),
                              MIcon(icon!, size: 20, color: foreground),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
