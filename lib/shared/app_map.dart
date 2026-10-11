import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import 'stitch.dart';

/// Base map: Esri "World Street Map" raster tiles (OpenStreetMap-derived data). They need no API key
/// and are the closest free keyless style to the light Google-like maps of the Stitch export (pale
/// land, green parks, blue water, white roads, few labels). Note the `{z}/{y}/{x}` order.
///
/// TERMS: Esri's public tile service is acceptable for a proof of concept / demo with attribution;
/// a production app needs a licensed provider or key (Google Maps, MapTiler, Mapbox or an Esri
/// subscription). Swap [kMapTileUrl] / [buildTileLayer] only; nothing else depends on the source.
const String kMapTileUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
const String kMapAttribution = 'Esri, HERE, Garmin, OpenStreetMap contributors';

/// Pale map colour shown while tiles load (never black / blank).
const Color kMapLoadingColor = Color(0xFFE8EEF6);

/// The single tile-layer factory used by every map. [provider] lets tests/QA inject tiles.
///
/// Performance: no `ColorFiltered` over the tiles (it forced a full-screen saveLayer on every frame
/// of a pan/zoom), so Esri's native colours are shown. Tiles appear instantly (no per-tile fade
/// animation) and only a small buffer of off-screen tiles is kept.
Widget buildTileLayer({TileProvider? provider, bool retina = false}) =>
    _tiles(provider: provider, retina: retina);

Widget _tiles({TileProvider? provider, required bool retina}) => TileLayer(
  urlTemplate: kMapTileUrl,
  userAgentPackageName: 'com.nordicmobility.rider_app',
  // Esri has no @2x tiles: retina mode requests one zoom level deeper and scales down (crisper).
  retinaMode: retina,
  maxNativeZoom: 18,
  maxZoom: 19,
  tileDisplay: const TileDisplay.instantaneous(),
  keepBuffer: 1,
  panBuffer: 1,
  evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
  tileProvider:
      provider ??
      NetworkTileProvider(
        // Must be a mutable map: flutter_map adds its own headers to it.
        headers: {
          'User-Agent': 'com.nordicmobility.rider_app (Nordic Ride POC)',
        },
      ),
);

/// Builds the base-map tile layer. Tests override this with a static Stitch map crop (or a
/// blank placeholder) so no network tiles are requested.
final mapTileLayerProvider = Provider<Widget Function(BuildContext)>((ref) {
  return (context) => buildTileLayer();
});

/// Shared map surface: tiles + optional polylines + markers + attribution.
class AppMap extends ConsumerWidget {
  const AppMap({
    super.key,
    required this.center,
    this.zoom = 13.5,
    this.controller,
    this.markers = const [],
    this.routePoints = const [],
    this.polylines = const [],
    this.onPositionChanged,
    this.onTap,
    this.interactive = true,
    this.fitPoints,
    this.fitPadding = const EdgeInsets.fromLTRB(48, 140, 48, 320),
    this.dashedRoute = false,
    this.backgroundColor = kMapLoadingColor,
    this.showAttribution = true,
    this.fitMaxZoom = 15.5,
  });

  final LatLng center;
  final double zoom;
  final MapController? controller;
  final List<Marker> markers;

  /// Planning route: teal line with a white casing (solid, or dashed with [dashedRoute]).
  final List<LatLng> routePoints;

  /// Extra lines, e.g. [travelledLine] + [remainingLine] on the tracking screens.
  final List<Polyline> polylines;
  final void Function(MapCamera camera, bool hasGesture)? onPositionChanged;
  final void Function(LatLng)? onTap;
  final bool interactive;

  /// When set (>= 2 points) the camera fits these points initially.
  final List<LatLng>? fitPoints;
  final EdgeInsets fitPadding;
  final bool dashedRoute;
  final Color backgroundColor;
  final bool showAttribution;

  /// Highest zoom the initial camera fit may use.
  final double fitMaxZoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = ref.watch(mapTileLayerProvider);
    final fit = fitPoints != null && fitPoints!.length >= 2;
    return RepaintBoundary(
      child: FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: center,
          initialZoom: zoom,
          minZoom: 3,
          maxZoom: 19,
          backgroundColor: backgroundColor,
          initialCameraFit: fit
              ? CameraFit.coordinates(
                  coordinates: fitPoints!,
                  padding: fitPadding,
                  maxZoom: fitMaxZoom,
                )
              : null,
          interactionOptions: InteractionOptions(
            flags: interactive
                ? InteractiveFlag.all & ~InteractiveFlag.rotate
                : InteractiveFlag.none,
          ),
          onPositionChanged: onPositionChanged,
          onTap: onTap == null ? null : (_, point) => onTap!(point),
        ),
        children: [
          tiles(context),
          if (routePoints.length >= 2 || polylines.isNotEmpty)
            PolylineLayer(
              polylines: [
                if (routePoints.length >= 2)
                  Polyline(
                    points: routePoints,
                    pattern: dashedRoute
                        ? StrokePattern.dashed(segments: const [8, 8])
                        : const StrokePattern.solid(),
                    strokeWidth: 5,
                    strokeCap: StrokeCap.round,
                    color: NordicColors.secondary,
                    borderStrokeWidth: 1.5,
                    borderColor: Colors.white,
                  ),
                ...polylines,
              ],
            ),
          MarkerLayer(markers: markers),
          if (showAttribution)
            const Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(4, 2, 6, 20),
                child: Text(
                  kMapAttribution,
                  style: TextStyle(fontSize: 8, color: Color(0x99000000)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Solid travelled route: Stitch `#006b5f`, width 5, round caps (the teal glow is drawn by the
/// white casing).
Polyline travelledLine(List<LatLng> points) => Polyline(
  points: points,
  strokeWidth: 5,
  strokeCap: StrokeCap.round,
  color: NordicColors.secondary,
  borderStrokeWidth: 2,
  borderColor: const Color(0x664FDBC8),
);

/// Dashed remaining route: Stitch `#00152f`, width 4, dash 8/8, 85 % opacity.
Polyline remainingLine(List<LatLng> points) => Polyline(
  points: points,
  pattern: StrokePattern.dashed(segments: const [8, 8]),
  strokeWidth: 4,
  strokeCap: StrokeCap.round,
  color: NordicColors.primary.withValues(alpha: 0.85),
);

/// Pickup / route origin: teal halo, `#006b5f` dot and a white centre (Stitch SVG origin marker).
Marker pickupMarker(LatLng p) => Marker(
  point: p,
  width: 30,
  height: 30,
  child: Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: NordicColors.secondaryContainer.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
      ),
      Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: NordicColors.secondary,
          shape: BoxShape.circle,
        ),
      ),
      Container(
        width: 4,
        height: 4,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    ],
  ),
);

/// Drop-off: deep navy rounded square with a white centre (Stitch SVG destination marker).
Marker dropoffMarker(LatLng p) => Marker(
  point: p,
  width: 24,
  height: 24,
  child: Center(
    child: Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: NordicColors.primary,
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  ),
);

/// Device location (blue dot).
Marker userMarker(LatLng p) => Marker(
  point: p,
  width: 22,
  height: 22,
  child: Container(
    decoration: BoxDecoration(
      color: NordicColors.info,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
    ),
  ),
);

/// Mock nearby car (Stitch home map): dark ETA pill ("2m") over a white 32 px circle with the
/// `electric_car` glyph. Demo data only: there is no nearby-cars endpoint.
Marker nearbyCarMarker(
  LatLng p,
  int etaMinutes, {
  Color iconColor = NordicColors.primary,
}) => Marker(
  point: p,
  width: 56,
  height: 58,
  alignment: Alignment.bottomCenter,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Elevated(
        shadows: Tw.md,
        radius: 9999,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: NordicColors.primary,
            borderRadius: NordicRadii.pillRadius,
          ),
          child: Text(
            '${etaMinutes}m',
            style: NordicText.labelSm.copyWith(
              color: NordicColors.secondaryFixed,
              height: 1.4,
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Elevated(
        shadows: Tw.md,
        circle: true,
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: MIcon(Symbols.electric_car, size: 18, color: iconColor),
          ),
        ),
      ),
    ],
  ),
);

/// Driver pin of the "driver found" screen: navy circle (44) with a teal ring, `directions_car`
/// glyph and a small pointer at the bottom. Position comes from the MOCK telemetry adapter.
Marker driverPinMarker(LatLng p) => Marker(
  point: p,
  width: 60,
  height: 66,
  alignment: Alignment.center,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Elevated(
        shadows: Tw.lg,
        circle: true,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: NordicColors.primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: NordicColors.secondaryContainer.withValues(alpha: 0.6),
              width: 4,
            ),
          ),
          child: const Center(
            child: MIcon(
              Symbols.directions_car,
              size: 20,
              color: NordicColors.secondaryContainer,
            ),
          ),
        ),
      ),
      Transform.translate(
        offset: const Offset(0, -6),
        child: Transform.rotate(
          angle: math.pi / 4,
          child: Container(width: 10, height: 10, color: NordicColors.primary),
        ),
      ),
    ],
  ),
);

/// Assigned driver on the tracking map (Stitch `car-marker-group`): teal pulse circle, navy
/// rounded body with a teal outline, headlight beam, roof glass and a white plate bar, rotated by
/// [bearingDegrees]. The position comes from the MOCK telemetry adapter.
Marker driverMarker(LatLng p, {double bearingDegrees = -38}) => Marker(
  point: p,
  width: 64,
  height: 64,
  rotate: false,
  child: Transform.rotate(
    angle: bearingDegrees * math.pi / 180,
    child: CustomPaint(painter: _CarPainter(), size: const Size(64, 64)),
  ),
);

class _CarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      c,
      20,
      Paint()..color = const Color(0xFF6DF5E1).withValues(alpha: 0.25),
    );
    // Headlight beam.
    final beam = ui.Path()
      ..moveTo(c.dx - 8, c.dy - 22)
      ..lineTo(c.dx + 8, c.dy - 22)
      ..lineTo(c.dx + 14, c.dy - 36)
      ..lineTo(c.dx - 14, c.dy - 36)
      ..close();
    canvas.drawPath(
      beam,
      Paint()..color = const Color(0xFF4FDBC8).withValues(alpha: 0.3),
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: 28, height: 44),
      const Radius.circular(8),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF00152F));
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFF4FDBC8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(c.dx, c.dy - 6),
      3.5,
      Paint()..color = const Color(0xFF4FDBC8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - 7, c.dy - 14, 14, 20),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF304869).withValues(alpha: 0.8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - 6, c.dy + 10, 12, 4),
        const Radius.circular(1.5),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Compass bearing in degrees (0 = north, clockwise) from [a] to [b].
double bearingBetween(LatLng a, LatLng b) {
  final lat1 = a.latitudeInRad;
  final lat2 = b.latitudeInRad;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final y = math.sin(dLng) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}
