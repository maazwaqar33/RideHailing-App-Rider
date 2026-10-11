/// DEMO CONTENT. Everything in this file is static placeholder copy that exists only because the
/// Stitch designs show it and the backend has no such data. None of it comes from, or is sent to,
/// the API. Anywhere it is used the surrounding text (driver name, plate, vehicle, fare, payment
/// method) is the real data from the ride resource.
abstract final class DemoDriverProfile {
  /// Driver rating line (the ride resource has no rating).
  static const rating = '4.9';

  /// Trip counters as printed on the three tracking designs.
  static const tripsFound = '1,840+ trips'; // driver_found_erik_larsen
  static const tripsLive = '2,410 trips'; // live_tracking_3_states
  static const ridesArrived =
      '2,410+ rides'; // live_trip_driver_arrived_pin_4821
  static const languages = 'Fluent in Norsk, Engelsk';
  static const subtitle = 'Top Rated Oslo Fleet Partner';
  static const receiptRating = '4.98';

  /// Vehicle chips (the ride resource has make/model/colour/plate only).
  static const powertrain = 'Hybrid';
  static const seatsChip = '4 seats';
  static const trunkChip = 'Large trunk';
  static const cabinTemp = '21.5°C';
}

/// DEMO security PIN (the backend has no ride-PIN feature). Generated locally from the ride id and
/// shown on the tracking screens exactly like the design; it is never verified by anything.
/// The offset makes ride #42 show the Stitch value 4821.
String demoSecurityPin(int rideId) {
  final n = (4821 - 1000 + (rideId - 42) * 1237) % 9000;
  return '${1000 + (n < 0 ? n + 9000 : n)}';
}

/// Static climate / brand figures from the designs (no emissions data exists in the API).
abstract final class DemoClimate {
  static const co2Saved = '7.4 kg CO₂ Saved';
  static const co2Subtitle =
      'Hydro-powered electric transit on E6 express highway.';
  static const walletCo2 = '18.4 kg';
  static const summaryTitle = 'Climate Impact Summary';
  static const summaryBody = 'Saved 14.8 kg CO₂ via all-electric rides';
  static const summaryBadge = '100% EV';
}

/// DEMO estimate: CO₂ avoided versus a 120 g/km petrol car for [meters] driven. The backend has
/// no emissions data; this is a labelled estimate, not a measurement.
String co2SavedKg(int meters) => (meters / 1000 * 0.12).toStringAsFixed(1);
