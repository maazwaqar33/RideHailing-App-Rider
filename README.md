# Nordic Ride - Rider App (POC)

Flutter Rider app for the Nordic Mobility ride-hailing proof of concept. It talks to the Laravel 13 /
backend in `../backend` (v1.1, JWT auth, API prefix `/api/v1`) and uses the Stitch export in
`../stitch_nordic_ride_hailing_app` as its visual source of truth.

Supported targets: **Android** (debug APK builds) and **Windows desktop** (builds). **iOS** projects exist
but cannot be built on this Windows machine. **Web is not supported**: the backend has no CORS
configuration.

> Honesty summary (details in [`docs/RIDER_REPORT.md`](docs/RIDER_REPORT.md)):
> real = auth (JWT with refresh rotation), fare estimate, ride request, status polling, cancel, history,
> timeline, default payment method.
> Mock / local only = place search data, route (straight line), nearby cars, driver map position,
> rating, tip, report-a-problem, payment confirmation, saved places, the **security PIN** (generated on the
> device), **driver rating / trip count / languages** and all **photos** (section 6). They are labelled in
> the UI or in code and are **not** stored by the backend or visible in Admin.
> Not built = Google/Apple/Vipps/BankID/phone-OTP sign-in, wallet balance, cards, chat, share, SOS, push. These are
> **removed from the UI** (no disabled buttons, "Soon" badges or "not available" messages); see section 10.

## 1. Prerequisites

- Flutter 3.47.x (Dart 3.13), Android SDK for Android builds.
- The backend running on **port 8001 before you launch the app** (see section 3: `php -S 0.0.0.0:8001 ...`).
  If it is down the splash shows a friendly error card with "Try again" and "Sign in again" (section 11).

## 2. Run the app

```powershell
cd C:\Users\syedp\Desktop\POC\rider_app
flutter pub get

# Windows desktop (talks to http://127.0.0.1:8001 by default)
flutter run -d windows

# Android emulator: nothing to configure (the app finds the backend at http://10.0.2.2:8001)
flutter run -d emulator-5554

# Real Android phone over USB or wireless adb: forward the port once, nothing else to configure
adb reverse tcp:8001 tcp:8001      # re-run it if the phone reconnects
flutter run --release -d <device-id>

# Real phone WITHOUT adb: LAN IP (needs a Windows firewall inbound rule for TCP 8001 on the
# network profile in use, e.g. a Public profile blocks it by default)
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8001
```

### Build-time configuration (`--dart-define`)

| Define | Default | Meaning |
|---|---|---|
| `API_BASE_URL` | desktop/web: `http://127.0.0.1:8001`; Android: probed (see below) | Backend origin (no `/api/v1` suffix). When set it wins and nothing is probed |
| `POLL_INTERVAL_MS` | `5000` | How often an active ride is re-fetched (no websocket exists) |
| `MOCK_ESTIMATE_FALLBACK` | `true` | Allow the labelled MOCK fare only when the backend is unreachable |
| `MOCK_DRIVER_LEG_SECONDS` | `90` | Speed of the simulated driver journey on the map |
| `SPLASH_MIN_MS` | `1400` | Minimum splash time |
| `DEVICE_NAME` | `nordic-rider-app` | Device label sent on login/register (audit log only) |
| `UI_VARIANT` | `classic` | `hub` makes the single-page intro (`splash_onboarding`) and the combined `login_sign_up` screen the logged-out entry. Both are always reachable at `/intro` and `/auth` |

**Android base URL without `--dart-define`:** the app probes `http://127.0.0.1:8001` (a real phone with
`adb reverse tcp:8001 tcp:8001`) and then `http://10.0.2.2:8001` (the emulator) with a 1.5 s timeout each (any HTTP
answer, even 401, counts as reachable), caches the first that answers for the session and re-probes once after a
connection error or timeout (`lib/core/network/base_url_resolver.dart`, tests in
`test/core/base_url_resolver_test.dart`). Sign-in, register and forgot-password use the normal 8 s connect timeout,
so a wrong URL fails fast with the friendly "server took too long" message.

The Android manifest allows cleartext HTTP (POC demo backend is plain HTTP); use HTTPS in production.

## 3. Backend on :8001 (own database, no changes to the backend code)

The Rider work uses its own database so it never touches the Admin work. From a PowerShell prompt:

```powershell
cd C:\Users\syedp\Desktop\POC\backend
$env:Path += ";C:\Users\syedp\.config\herd\bin"
$env:DB_DATABASE = 'nordic_mobility_rider'
$env:API_LOGIN_ATTEMPTS_PER_MINUTE = '100'   # default is 5/min per e-mail+IP; raised for repeated demos
$env:MAIL_MAILER = 'log'
$env:QUEUE_CONNECTION = 'sync'
$env:CACHE_STORE = 'file'                     # optional: fewer DB sockets for the JWT deny-list on Windows
php artisan migrate --seed --force            # first time only
cd public
php -S 0.0.0.0:8001 ../vendor/laravel/framework/src/Illuminate/Foundation/resources/server.php
```

Use `php -S` directly: `php artisan serve` drops env vars that override `.env`, so it would silently use the
main database. Secrets in `.env` are never printed or copied by the app. Password rules (backend v1.1): at
least 10 characters with upper and lower case letters and a number; `POST auth/login` is limited to 5 per
minute per e-mail+IP unless `API_LOGIN_ATTEMPTS_PER_MINUTE` is raised.

### Demo accounts (seeded)

| Role | Email | Password |
|---|---|---|
| Rider | `rider1@example.com` (Kari Hansen) | `Password123!` (seeder default) |
| Rider | `rider2@example.com` (Lars Johansen) | `Password123!` |
| Manager (for Admin parity checks) | `manager@example.com` | `Password123!` |

New riders can also register from the sign-up screen (`POST auth/register`).

## 4. Tests and checks

```powershell
flutter analyze                          # 0 issues
flutter test                             # unit + widget + visual-QA renders (all green)
cd packages\nordic_design_kit; flutter test; cd ..\..   # design-kit tests
flutter test test_live/backend_flow_test.dart            # REAL backend at :8001 (18 checks incl. JWT refresh rotation), backend must be up
flutter test test_live/map_render_test.dart              # real Esri tiles + cars/route markers -> docs/visual-qa/live-map (needs internet)
flutter build apk --debug                # Android debug build
```

### Scripted driver (NOT the Driver App)

`tool/scripted_driver.dart` moves a ride through accepted -> en route -> arrived -> in progress -> completed
using the dispatcher/manager and `driver1@example.com` API calls so the Rider tracking screen can be demonstrated alone:

```powershell
dart run tool/scripted_driver.dart --ride <ride_id> [--delay 5] [--base http://127.0.0.1:8001]
```

It is a script. **Two-phone acceptance (Rider app + real Driver app) has not been verified.**

### Visual QA against Stitch

```powershell
flutter test test/visual                 # renders every screen at the Stitch screenshot size
python tool/visual_compare.py            # writes docs/visual-qa/<screen>_compare.png (Stitch | Flutter)
```

## 5. Architecture

```
lib/
  app/            router (go_router, pure redirect), app shell, theme wiring
  core/           env, Dio client (Bearer + JWT refresh + 401 handling), error mapping, token store, validators, formatters, geo
  shared/         Stitch building blocks (Tw shadows, MIcon, Elevated, StitchButton/TextField, nav chrome, AppMap)
  mock/           ALL mock adapters (places, route, nearby cars, fare fallback, driver telemetry, local stores)
  features/<x>/   domain (models, repository interfaces) / data (HTTP) / application (Riverpod) / presentation
packages/nordic_design_kit   reusable tokens + widgets (Inter fonts, Stitch colours/typography), for the Driver app
```

- State: Riverpod 3 notifiers. Navigation: go_router `StatefulShellRoute.indexedStack` (Ride, Trips, Wallet, Profile).
- Auth (backend v1.1 JWT, `lib/core/network/api_client.dart`): token + `expires_at` in `flutter_secure_storage`.
  The Dio client refreshes **single-flight** (concurrent calls wait for one `POST auth/refresh`, because
  rotation kills the old token at once): proactively when fewer than 5 minutes remain, on app resume, and
  once plus one retry on a 401. A refused refresh (expired / 14-day limit / revoked) or a second 401 clears
  the session and returns to login. A network failure during refresh never logs the user out.
- Realtime: **polling only** (`GET rides/{id}` every 5 s), no websocket/push. Arrival alert = in-app banner + haptic.
- Repositories are interfaces selected by providers, so every mock can be replaced without touching UI.

## 6. Mock inventory and how to replace each

| Mock | Where | Shown as | Replace with |
|---|---|---|---|
| Place search (Oslo dataset) | `lib/mock/oslo_places.dart`, `mock_place_search.dart` | design data | A geocoding/places endpoint; implement `PlaceSearchRepository`, override `placeSearchRepositoryProvider` |
| Route / distance / duration | `mock_route_service.dart` (haversine, straight line) | "Straight line" label | Routing service; implement `RouteRepository` |
| Nearby cars + ETAs | `mock_nearby_cars.dart` | "Demo car" pills | Availability endpoint; implement `NearbyCarsRepository` |
| Fare fallback (only if server unreachable) | `mock_fare_estimator.dart` | MOCK banner, booking disabled | Remove `MOCK_ESTIMATE_FALLBACK` |
| Driver map position | `mock_driver_telemetry.dart` | "MOCK POSITION" badge | Driver live-location endpoint; implement `DriverTelemetrySource` |
| Rating, tags, note, tip | `local_trip_stores.dart` (`LocalFeedbackRepository`) | "Saved on this device only (demo)" | A ratings/tips API; implement `FeedbackRepository` |
| Report a problem / lost item | `LocalProblemReportRepository` | "not sent to support" banner | A support-ticket API |
| Payment confirmation | `MockPaymentService` (backend `payment.status` stays `not_charged`) | "Demo payment" | A payment provider |
| Saved places (Home/Work) | `local_places_store.dart` | device-local | A saved-places API |
| **Photos** (rider avatar, driver portrait, vehicle pictures) | `assets/images/stitch/*` via `DemoPhotos` in `lib/shared/stitch.dart` | Stitch demo placeholders; names, plate and car model next to them are real | Driver / vehicle / rider photo URLs in the API; swap `PhotoCircle` / `Image.asset` for network images |
| **Security PIN** (4821 style) | `demoSecurityPin()` in `lib/mock/demo_content.dart` | Generated from the ride id, never verified | A ride-PIN endpoint |
| **Driver rating, trips, languages, "100% Hybrid" chips** | `DemoDriverProfile` in `lib/mock/demo_content.dart` | Static design copy | Driver stats in the ride resource |
| CO2 saved estimates, "100% EV" brand chips | `co2SavedKg()` (120 g/km estimate), `DemoClimate` | "estimate" / brand copy | An emissions source |
| Vehicle class descriptions, bag counts, Wi-Fi/Silent EV highlights | `choose_ride_screen.dart`, `fleets_screen.dart` | Static design copy (fare is one real price for all classes) | Vehicle-class pricing in the fare API |

## 7. Images, logo and icons

- Every photo referenced by the Stitch `code.html` files was downloaded (25 of 26 URLs; the 26th, a
  `trip_complete_receipt` driver portrait, returns HTTP 400 and is rendered broken in the Stitch screenshot
  itself, so the other Erik portrait is used) into `assets/images/stitch/` (declared in `pubspec.yaml`):
  cars (`car_*`), driver portraits (`driver_erik_1..6`), rider avatar (`avatar_sara.jpg`), map backdrops
  used only by the visual-QA harness, Oslo skyline, cabin photo, Google/Apple SVGs. They are static demo
  placeholders (`DemoPhotos`), not data from the backend.
- Brand: `stitch_nordic_ride_hailing_app/logo.jpg/screen.png` (512x512 emblem + wordmark on white) was made
  transparent with PIL (`assets/brand/logo_mark.png`, `logo_full.png`, copies in the design kit as
  `NordicLogoMark` / `NordicLogoFull`). Launcher icons (Android adaptive + legacy, iOS, Windows) are generated
  with `flutter_launcher_icons` from `assets/brand/app_icon*.png`:
  `dart run flutter_launcher_icons`.
- Icons are Material Symbols Outlined (`material_symbols_icons`), weight 400, like the Stitch export.

## 8. Maps

`AppMap` (flutter_map) has ONE shared tile-layer factory (`buildTileLayer` in `lib/shared/app_map.dart`):
**Esri "World Street Map"** raster tiles
(`https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}`, note
y before x), `maxNativeZoom 19`, a User-Agent header, small attribution text "Esri, HERE, Garmin,
OpenStreetMap contributors", and a light desaturate/brighten colour filter (`kMapSaturation`,
`kMapLightScale`) so it sits close to the Stitch maps (pale land, green parks, blue water, few labels). While
tiles load the map shows the pale Stitch colour (never black).

**Terms / production note:** Esri's public tile service needs no key and is fine for a POC / demo with the
attribution shown. A production app needs a licensed provider or key (Google Maps, MapTiler, Mapbox or an Esri
subscription); change only `kMapTileUrl` / `buildTileLayer`. Keyless alternatives were checked: CARTO (now
"API KEY REQUIRED" watermark), Stadia and MapTiler (keys), plain OpenStreetMap (works but busy and grey, and
its policy discourages heavy app use).

**OpenFreeMap vector basemap (tried, not adopted):** a keyless vector style (OpenFreeMap liberty/bright/positron, tiles
`https://tiles.openfreemap.org/planet`; free public instance, attribution "OpenFreeMap (c) OpenMapTiles Data from
OpenStreetMap" required, self-host or a paid provider for production) was tried through `vector_map_tiles` +
`vector_tile_renderer`. Reverted because (1) the only `vector_map_tiles` releases that support flutter_map 8 are betas
(9.0.0-beta.x / 10.0.0-beta.x; stable 8.0.0 needs flutter_map ^7); (2) the style loads (106 layers) but the vector layer
paints nothing under `flutter test`, so the visual QA could not be run; (3) a real Windows release build of the demo
showed only the raster fallback and the debug run exited, so a working vector render was not verified. No vector code or
dependency remains. Revisit with a stable flutter_map-8-compatible release or `flutter_map_vector_tiles` successor.

Markers follow the design: nearby cars (white circle + dark ETA pill, mock,
`lib/mock/mock_nearby_cars.dart`), pickup halo, navy drop-off square, the driver pin / rotated driver car, solid
teal travelled line + dashed navy remaining line. Live-tile renders for review:
`flutter test test_live/map_render_test.dart` writes `docs/visual-qa/live-map/*.png` (tiles are fetched with
`dart:io` and cached in `.dart_tool/qa_tiles_esri` because `flutter test` cannot complete NetworkImage loads).

## 9. Stitch fidelity

Every Stitch screen folder was rebuilt as real Flutter widgets (no webviews) and compared with its
`screen.png`. Side-by-side images are in [`docs/visual-qa/`](docs/visual-qa/) and the per-screen result
(matched / residual differences) is in the report. Design tokens live in `packages/nordic_design_kit`.

## 10. Only built controls are shown (client demo rule)

Anything that is not built is **removed**, never disabled, badged "Soon"/"Unavailable" or answered with a
"not available" message. A control stays only if it navigates to a built screen, calls the real backend or
drives a working local feature (mock rating/tip/report/payment pickers, saved places). A unit test
(`test/app/no_unbuilt_controls_test.dart`) fails if `lib/` contains `showUnavailable`, "coming soon", "not
available yet" or an empty `onTap`. Removed, per screen (and therefore intentionally absent from the Stitch layouts):

| Screen | Removed |
|---|---|
| welcome | EN/NO language toggle, "BankID & Vipps sign-in" line |
| login_sign_up (`/auth`) | EN language chip, Google + Vipps buttons ("Soon"), "or continue with email" divider, "Fast Pass" label, fingerprint button, footer links (Rider Support / Drive with Us / Oslo City Guide) |
| log_in_screen | fingerprint button, OR divider, Vipps / Google / Apple tiles; the returning-rider "Unlock" (Face ID) became "Use" which pre-fills the e-mail |
| sign-up | Stitch step 2 (SMS code + Vipps card): the flow is **2 steps** (details incl. optional phone, then terms); BankID & Vipps card, biometric row, telemetry + marketing consents |
| onboarding_3 / splash_onboarding | Vipps tile and badge ("Coming soon"); the payment tiles are labels, not selectable |
| ride_selection / pick on map / driver found / live / arrived / searching | no-op locate and layers buttons, traffic and eco layer buttons, "Edit pickup", Chat, Share, SOS/Safety; **Call driver** stays (real `tel:` via `url_launcher` when the ride carries a driver phone; the number is shown if the device cannot dial; hidden without a phone) |
| confirm_and_pay | Vipps row, "+ Add payment method" |
| trips | "Scheduled" tab (and with it the one-tab segmented control) |
| profile_wallet / profile | wallet balance + "Add Money / Top Up" + tune button (card now shows real completed trips and the CO2 estimate), Vipps row, "Add Payment Method", "Add New Place", Preferences (Eco priority, Language, Dark theme), GDPR export, Delete account, "Design kit" row |

## 11. Session restore on the splash

The stored session is validated with `GET auth/me` using an 8 s timeout (plus a 10 s safety net). A 401 clears the
session and goes to onboarding/welcome as before. On a timeout or network error the token is **kept** and the splash
shows a friendly card with two actions: **Try again** (restore again) and **Sign in again** (clears the session and
opens the welcome/login flow). Start the backend first (section 3) for a normal launch.

## 12. Client demos: use a release build

The login screen has a "Fill demo rider (debug builds only)" link that pre-fills the seeded rider credentials. It is
guarded by `kDebugMode`, so it is compiled out of release and profile builds. For a client demo build a release APK
(the main manifest allows cleartext HTTP so the release APK can reach the local demo backend; a production app must use HTTPS and remove `usesCleartextTraffic`):

```powershell
flutter build apk --release                      # no dart-define needed
adb reverse tcp:8001 tcp:8001                    # real phone: the app then reaches the PC backend on 127.0.0.1:8001
adb install -r build\app\outputs\flutter-apk\app-release.apk
# emulator: nothing to do (10.0.2.2:8001 is probed automatically)
# LAN IP instead of adb: flutter build apk --release --dart-define=API_BASE_URL=http://<pc-lan-ip>:8001
#   (needs an inbound Windows firewall rule for TCP 8001)
```

Start the backend on :8001 first (section 3). The splash error card (section 11) is laid out as a scrollable column
(brand block, then the card and the two buttons), so it never overlaps the logo or tagline, also at 360x640 and with
large text; renders: `docs/visual-qa/splash_screen@restore_failed_compare.png` and
`docs/visual-qa/flutter/splash_screen@restore_failed_360x640*.png`.
