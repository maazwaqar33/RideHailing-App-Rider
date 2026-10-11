# Svea Mobility — Rider Application

The official Flutter-based Rider application for the **Svea Mobility** electric & hybrid ride-hailing platform.

Designed and engineered with Scandinavian minimalism, smooth micro-interactions, responsive maps, and real-time ride tracking.

---

## Features

- **Onboarding & Authentication**: Seamless sign-in and registration flow.
- **Interactive Map & Destination Search**: Fast geocoding, recent destinations, and pickup pin selection.
- **Fleet Selection & Live Fare Estimation**: Dynamic vehicle class options (Standard, Comfort, Van) with transparent fare breakdowns.
- **Booking & Secure Payments**: Flexible payment choices including Card and Direct Pay.
- **Real-Time Ride Tracking**: 
  - Driver dispatch radar
  - Driver assigned with vehicle details, verified ratings, and arrival ETA
  - Live vehicle movement telemetry on interactive map
  - In-trip navigation and safety PIN verification
- **Trip History & Receipts**: Comprehensive timeline of past journeys with downloadable receipts and driver ratings.
- **Digital Wallet & Profile**: Eco-impact stats (CO₂ emissions saved), saved preferences, and account management.

---

## Technology Stack

- **Framework**: Flutter (Dart 3.x)
- **State Management**: Flutter Riverpod
- **Routing**: GoRouter
- **Design System**: Nordic Design Kit (Tailored Scandinavian design language, fluid typography, dark/light surface tokens)
- **Mapping & Geolocation**: Flutter Map with OpenStreetMap / Vector tiles and Geolocator
- **Networking**: Dio with JWT session handling and proactive token refresh

---

## Getting Started

### Prerequisites

- Flutter SDK (>= 3.24.0)
- Android Studio / Android SDK (for Android deployment)
- Xcode (for iOS deployment, macOS required)

### Setup & Run

1. **Clone repository**:
   ```bash
   git clone https://github.com/maazwaqar33/RideHailing-App-Rider.git
   cd RideHailing-App-Rider
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run on connected device / emulator**:
   ```bash
   flutter run
   ```

---

## Building Release APK

To generate a standalone production Release APK for Android:

```bash
flutter build apk --release
```

The compiled APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## Testing & Quality Assurance

Run the test suite and code analysis:

```bash
flutter analyze
flutter test
```

---

## License

Proprietary and confidential. All rights reserved by Svea Mobility.
