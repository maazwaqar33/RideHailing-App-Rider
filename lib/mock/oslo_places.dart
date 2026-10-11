import 'package:latlong2/latlong.dart';

import '../features/map/domain/map_models.dart';

/// MOCK DATA: local Oslo place dataset used for suggestions (there is no places API).
/// Coordinates are real-world approximations of the named landmarks.
const List<Place> kOsloPlaces = [
  Place(
    id: 'oslo-s',
    name: 'Oslo S (Jernbanetorget)',
    address: 'Jernbanetorget, 0154 Oslo',
    position: LatLng(59.9110, 10.7528),
    kind: PlaceKind.transit,
  ),
  Place(
    id: 'osl-airport',
    name: 'Oslo Airport Gardermoen (OSL)',
    address: 'Edvard Munchs veg, Gardermoen',
    position: LatLng(60.1939, 11.1004),
    kind: PlaceKind.airport,
  ),
  Place(
    id: 'aker-brygge',
    name: 'Aker Brygge',
    address: 'Stranden 1, 0250 Oslo',
    position: LatLng(59.9106, 10.7298),
    kind: PlaceKind.business,
  ),
  Place(
    id: 'nationaltheatret',
    name: 'Nationaltheatret Stasjon',
    address: 'Johanne Dybwads plass 1',
    position: LatLng(59.9146, 10.7340),
    kind: PlaceKind.transit,
  ),
  Place(
    id: 'opera',
    name: 'Den Norske Opera & Ballett',
    address: 'Kirsten Flagstads plass 1, Bjørvika',
    position: LatLng(59.9075, 10.7531),
    kind: PlaceKind.landmark,
  ),
  Place(
    id: 'munch',
    name: 'MUNCH Museum',
    address: 'Edvard Munchs plass 1, 0194 Oslo',
    position: LatLng(59.9059, 10.7550),
    kind: PlaceKind.museum,
  ),
  Place(
    id: 'holmenkollen',
    name: 'Holmenkollen Ski Museum',
    address: 'Kongeveien 5, 0787 Oslo',
    position: LatLng(59.9637, 10.6676),
    kind: PlaceKind.museum,
  ),
  Place(
    id: 'vigeland',
    name: 'Vigeland Park (Frognerparken)',
    address: 'Nobels gate 32, 0268 Oslo',
    position: LatLng(59.9270, 10.7005),
    kind: PlaceKind.landmark,
  ),
  Place(
    id: 'karl-johan',
    name: 'Karl Johans gate 22',
    address: 'Karl Johans gate, 0159 Oslo',
    position: LatLng(59.9139, 10.7392),
    kind: PlaceKind.address,
  ),
  Place(
    id: 'majorstuen',
    name: 'Majorstuen',
    address: 'Bogstadveien, 0366 Oslo',
    position: LatLng(59.9297, 10.7140),
    kind: PlaceKind.transit,
  ),
  Place(
    id: 'grunerlokka',
    name: 'Grünerløkka',
    address: 'Thorvald Meyers gate, 0555 Oslo',
    position: LatLng(59.9226, 10.7580),
    kind: PlaceKind.address,
  ),
  Place(
    id: 'bjorvika',
    name: 'Bjørvika (Barcode)',
    address: 'Dronning Eufemias gate, 0191 Oslo',
    position: LatLng(59.9078, 10.7585),
    kind: PlaceKind.business,
  ),
  Place(
    id: 'slottet',
    name: 'Royal Palace (Slottet)',
    address: 'Slottsplassen 1, 0010 Oslo',
    position: LatLng(59.9168, 10.7274),
    kind: PlaceKind.landmark,
  ),
  Place(
    id: 'radhuset',
    name: 'Oslo City Hall (Rådhuset)',
    address: 'Rådhusplassen 1, 0037 Oslo',
    position: LatLng(59.9120, 10.7337),
    kind: PlaceKind.landmark,
  ),
  Place(
    id: 'ullevaal',
    name: 'Ullevål Stadion',
    address: 'Sognsveien 75, 0855 Oslo',
    position: LatLng(59.9486, 10.7340),
    kind: PlaceKind.landmark,
  ),
  Place(
    id: 'storo',
    name: 'Storo Storsenter',
    address: 'Vitaminveien 7, 0485 Oslo',
    position: LatLng(59.9484, 10.7743),
    kind: PlaceKind.business,
  ),
  Place(
    id: 'fornebu',
    name: 'Fornebu',
    address: 'Snarøyveien, 1360 Fornebu',
    position: LatLng(59.8999, 10.6240),
    kind: PlaceKind.business,
  ),
  Place(
    id: 'frogner-plass',
    name: 'Frogner plass',
    address: 'Frognerveien, 0266 Oslo',
    position: LatLng(59.9230, 10.7081),
    kind: PlaceKind.address,
  ),
];
