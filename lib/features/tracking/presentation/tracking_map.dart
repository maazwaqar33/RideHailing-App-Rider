import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../mock/mock_driver_telemetry.dart';
import '../../../shared/app_map.dart';
import '../../rides/domain/ride_models.dart';
import '../domain/driver_telemetry.dart';

enum TrackingMapMode { found, live, arrived }

/// The map of the live-ride screens: real tiles, pickup/drop-off markers, the route and the
/// assigned driver. The driver position and the route line come from the MOCK telemetry adapter
/// (straight line, no live-location endpoint exists); nothing here is sent to the API.
class TrackingMap extends StatelessWidget {
  const TrackingMap({
    super.key,
    required this.ride,
    required this.telemetry,
    required this.mode,
    this.fitPadding = const EdgeInsets.fromLTRB(56, 96, 56, 72),
  });

  final Ride ride;
  final DriverPosition? telemetry;
  final TrackingMapMode mode;
  final EdgeInsets fitPadding;

  @override
  Widget build(BuildContext context) {
    final pickup = ride.pickup.latLng;
    final dropoff = ride.dropoff.latLng;
    final driver = telemetry?.position;
    final inTrip = ride.status == RideStatus.inProgress;
    final target = inTrip ? dropoff : pickup;
    final start = driver == null
        ? null
        : (inTrip ? pickup : MockDriverTelemetry.startPointFor(ride));

    final polylines = <Polyline>[];
    final markers = <Marker>[];
    switch (mode) {
      case TrackingMapMode.found:
        final route = [?start, ?driver, target];
        polylines
          ..add(
            Polyline(
              points: route,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              color: NordicColors.secondary.withValues(alpha: 0.2),
            ),
          )
          ..add(
            Polyline(
              points: route,
              pattern: StrokePattern.dashed(segments: const [6, 6]),
              strokeWidth: 4,
              strokeCap: StrokeCap.round,
              color: NordicColors.secondary,
            ),
          );
        markers.add(_navyDot(target));
        if (driver != null) markers.add(driverPinMarker(driver));
      case TrackingMapMode.live:
        if (start != null && driver != null) {
          polylines.add(travelledLine([start, driver]));
        }
        polylines.add(remainingLine([driver ?? pickup, target]));
        markers.add(dropoffMarker(target));
        if (start != null) markers.add(pickupMarker(start));
        if (driver != null) {
          markers.add(
            driverMarker(driver, bearingDegrees: telemetry!.headingDegrees),
          );
        }
      case TrackingMapMode.arrived:
        markers.add(pickupMarker(pickup));
        if (driver != null) {
          markers.add(
            driverMarker(driver, bearingDegrees: telemetry!.headingDegrees),
          );
        }
    }

    return ColoredBox(
      color: NordicColors.surfaceContainer,
      child: AppMap(
        center: driver ?? pickup,
        zoom: 14.5,
        interactive: mode != TrackingMapMode.arrived,
        fitPoints: mode == TrackingMapMode.arrived
            ? null
            : [?start, ?driver, target],
        fitPadding: fitPadding,
        fitMaxZoom: 14,
        polylines: polylines,
        markers: markers,
      ),
    );
  }

  Marker _navyDot(LatLng p) => Marker(
    point: p,
    width: 18,
    height: 18,
    child: Container(
      decoration: const BoxDecoration(
        color: NordicColors.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  );
}
