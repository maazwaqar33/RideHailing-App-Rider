import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

enum PlaceKind {
  transit,
  landmark,
  airport,
  address,
  museum,
  business,
  home,
  work,
  pin,
}

class Place extends Equatable {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.position,
    this.kind = PlaceKind.address,
  });

  factory Place.fromJson(Map<String, dynamic> json) => Place(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String,
    position: LatLng(
      (json['lat'] as num).toDouble(),
      (json['lng'] as num).toDouble(),
    ),
    kind: PlaceKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => PlaceKind.address,
    ),
  );

  /// A free map pin (drag-the-map selection). No geocoder exists, so the label is the coordinates.
  factory Place.pin(LatLng position, {String? name}) => Place(
    id: 'pin:${position.latitude.toStringAsFixed(5)},${position.longitude.toStringAsFixed(5)}',
    name: name ?? 'Dropped pin',
    address:
        '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
    position: position,
    kind: PlaceKind.pin,
  );

  final String id;
  final String name;
  final String address;
  final LatLng position;
  final PlaceKind kind;

  /// String sent to the API as `address` (max 255 chars).
  String get apiAddress {
    final s = address.isEmpty || address == name ? name : '$name, $address';
    return s.length > 255 ? s.substring(0, 255) : s;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'lat': position.latitude,
    'lng': position.longitude,
    'kind': kind.name,
  };

  @override
  List<Object?> get props => [id, name, address, position, kind];
}

/// Client-computed route. [isEstimate] is always true: no routing backend exists, so
/// distance is haversine and duration assumes an average urban speed.
class RouteInfo extends Equatable {
  const RouteInfo({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.isEstimate = true,
  });

  final List<LatLng> points;
  final int distanceMeters;
  final int durationSeconds;
  final bool isEstimate;

  @override
  List<Object?> get props => [
    points,
    distanceMeters,
    durationSeconds,
    isEstimate,
  ];
}

/// Mock nearby car marker (demo only: there is no nearby-cars endpoint).
class NearbyCar extends Equatable {
  const NearbyCar({
    required this.id,
    required this.position,
    required this.etaMinutes,
  });

  final String id;
  final LatLng position;
  final int etaMinutes;

  @override
  List<Object?> get props => [id, position, etaMinutes];
}

/// Backend `VehicleType` enum (sedan|estate|suv|van|minibus) with presentation metadata.
/// The fare API and ride request do NOT take a vehicle type: the choice is a UI preference only.
enum VehicleChoice {
  sedan('sedan', 'Standard', 'Sedan', 4, 2),
  estate('estate', 'Comfort', 'Estate, extra legroom', 4, 3),
  van('van', 'XL Van', 'Van, large luggage', 6, 6);

  const VehicleChoice(
    this.apiType,
    this.title,
    this.subtitle,
    this.seats,
    this.bags,
  );

  final String apiType;
  final String title;
  final String subtitle;
  final int seats;
  final int bags;
}
