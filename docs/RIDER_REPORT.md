# Rider App Report - Nordic Mobility POC

Verification date: 2026-10-11. Stack: Flutter 3.47 / Dart 3.13, Riverpod 3, go_router 18, Dio 5, flutter_map 8
(Esri World Street Map tiles, no key), flutter_secure_storage, local package `packages/nordic_design_kit`.
Design source of truth: `../stitch_nordic_ride_hailing_app` (read-only). Backend: `../backend` **v1.1 (JWT)** on
port 8001 using its own database `nordic_mobility_rider`. Admin and the Stitch export were not modified; the
backend code was not changed (restarted with env overrides only).

## 1. Verification results

| Check | Result |
|---|---|
| `flutter analyze` (rider_app, nordic_design_kit) | 0 issues, 0 issues |
| `dart format` (lib, test, test_live, tool, packages) | applied |
| `flutter test` (rider_app) | **204 / 204 pass** (includes 28 visual-QA render cases, 10 JWT-refresh unit tests, 6 variant tests) |
| `flutter test` (nordic_design_kit) | 6 / 6 pass |
| `flutter test test_live/backend_flow_test.dart` against the REAL backend :8001 | **18 / 18 pass** (first run in the latest pass; earlier passes needed retries, see "Backend flake" below), includes JWT refresh rotation |
| `flutter test test_live/map_render_test.dart` (real Esri tiles, needs internet) | 5 / 5 pass, images in `docs/visual-qa/live-map/` |
| `flutter build apk --debug` | **built** (`build/app/outputs/flutter-apk/app-debug.apk`, 257 MB); not installed or run by this work |
| `flutter build windows --release` | **built** (`build/windows/x64/runner/Release/rider_app.exe`); the debug exe was locked by a running process |
| iOS | **not built** (no macOS) |
| Web | not supported (backend has no CORS configuration) |
| `dart pub outdated` / dependency audit | not run |

**Backend flake (environment, not the app; the socket storm had ended by the last pass, 677 TIME_WAIT):** while the live suite ran, ~15,000 sockets were in `TIME_WAIT` on
this PC, almost all against the Dart VM service of an existing `flutter run` session (an emulator device,
`sdk gphone64`, owned by someone else, not touched). That exhausts Windows' ephemeral ports, so the PHP dev
server intermittently fails to open its MySQL connection (`Only one usage of each socket address...` in
`backend/storage/logs/laravel.log`) and answers 500. Individual live tests failed on different steps in
different runs; re-running passed. The server is now started with `CACHE_STORE=file` to reduce DB sockets.

## 2. Backend v1.1 (JWT) wiring

Read `backend/ForFrontendDoc.md` sections 1-15. Implemented in `lib/core/network/api_client.dart`,
`lib/features/auth/*`, tests in `test/core/jwt_refresh_test.dart` and `test/auth/auth_session_test.dart`:

- login / register / refresh return `{token, token_type, expires_in, expires_at, user}` at the top level;
  token + `expires_at` stored in `flutter_secure_storage`.
- **single-flight refresh**: `POST auth/refresh` with the still-valid token; parallel requests queue behind the
  one refresh (rotation kills the old token immediately); proactive when fewer than 5 minutes remain; on app
  resume (`WidgetsBindingObserver` -> `SessionController.onResume`); **refresh + one retry on 401**; a refused
  refresh (401/403/4xx except 429: expired, 14-day limit, revoked, inactive) or a second 401 clears the token
  and returns to login once per burst; a network failure during refresh does not sign the user out; an already
  expired token is not refreshed (the server rejects it).
- Old "no refresh token" assumptions, copy and tests removed. Poll interval 5 s (doc: 5-10 s).
- Live evidence (`test_live`): refresh returns a new token (`expires_in` 3600), the **old token answers 401
  immediately**, the new one 200; 4 parallel calls with < 5 min left cause one proactive refresh; a revoked token
  causes one refused refresh and the sign-out hook fires.
- Endpoints used: `POST auth/register|login|refresh|logout|password/forgot|password/reset`, `GET auth/me`,
  `GET/PATCH me/rider`, `POST fares/estimate`, `POST rides` (+ `Idempotency-Key`), `GET rides`,
  `GET rides/{id}`, `GET rides/{id}/timeline`, `POST rides/{id}/cancel`. Passwords: min 10 chars with
  upper/lower/number (validators updated). Login limit 5/min per e-mail+IP (`API_LOGIN_ATTEMPTS_PER_MINUTE`
  override for local demos).

## 3. Honesty notes (what is real, mocked, or unavailable)

- **Real (backend)**: everything listed under "Endpoints used".
- **Polling only**: ride status every 5 s. No websocket, no push. Arrival alert = in-app banner + haptic.
- **Mock / device-local (never sent to the backend, never visible in Admin)**: place search data, route
  (straight line), nearby cars + ETAs, **driver map position** ("MOCK POSITION" badge), rating + tags + note, tip,
  report-a-problem, payment confirmation (`payment.status` stays `not_charged`), saved Home/Work places, the mock
  fare (only when the server is unreachable; booking disabled then).
- **Static DEMO content reinstated from Stitch** (documented in code in `lib/mock/demo_content.dart` and
  `DemoPhotos` in `lib/shared/stitch.dart`; README mock inventory): all photos (rider avatar, driver portraits,
  vehicle pictures), the **security PIN** (generated from the ride id, shown 4821 for ride #42; the backend has
  no PIN and nothing verifies it), driver rating 4.9 / trip counts / "Fluent in Norsk, Engelsk" / "100% Hybrid" /
  seat-trunk-temperature chips, vehicle class descriptions and bag counts, "100% EV Zero Emission" brand chips,
  CO2-saved figures (an estimate at 120 g/km), the ride-selection "Oslo Metro" chip. The names, plate, car
  model/colour, addresses, fare, payment method (cash/card), distances, durations and statuses next to them are
  always real data.
- **Not built, therefore removed from the UI (client demo rule; nothing is disabled, badged or answered with a
  "not available" message)**: Google / Apple / Vipps / BankID sign-in, phone-OTP verification (sign-up has 2 steps),
  biometric unlock, wallet balance and top-up, saved cards, Vipps, in-app chat, share trip, SOS, edit pickup after
  request, PDF receipts, scheduled rides, dark theme, Norwegian language, GDPR export, delete account, map layer
  buttons. Guarded by `test/app/no_unbuilt_controls_test.dart`; per-screen list in README section 10.
- The scripted driver (`tool/scripted_driver.dart`) is a script, **not the Driver App**. Two-phone acceptance
  (Rider + real Driver app) is **not verified**.

## 4. Tasks and acceptance (re-verified)

| Task | Status | Evidence |
|---|---|---|
| R1 design system / setup | done | `packages/nordic_design_kit` (tokens, widgets, `NordicLogoMark/Full`, 6 tests); `lib/shared/*` Stitch helpers, `GlassPill`, `RoundMapButton`, `PhotoCircle`; launcher icons generated |
| R2 splash, onboarding, signup, login, session | done | widget tests (first run flow, login, signup 3 steps, 422 mapping, forgot/reset, logout, restore, expired/refresh paths); live tests 01-05, 15 |
| R3 maps, search, pick on map, permission fallback | done (mock places/route/cars) | widget + mock tests (denied location -> Oslo S fallback banner); live-tile renders |
| R4 booking, idempotency, duplicate guard, cancel with reason | done | widget tests (one POST on double tap, 409 banner, Idempotency-Key, cancel reason sheet) + live tests 06-08, 13 |
| R5 tracking by polling, completion, receipt, mock payment, tip, rating, report, history | done (mock driver position/payment/rating) | widget tests (polling to accepted/arrived/completed, arrival alert once, trip complete, rate screen, history drawer) + live tests 09-12, 14 (7-step lifecycle with the scripted driver) |

## 5. Visual QA (all screens, Stitch screenshot vs Flutter render)

Method: every screen is a real widget tree rendered by `flutter test test/visual` at the logical size of its
`screen.png` (390 px wide, devicePixelRatio = png width / 390, real Inter + Material Symbols fonts). **The map
in these renders is a static crop taken from the Stitch export (`assets/images/stitch/map_oslo_*.png`) swapped
in through `mapTileLayerProvider`, so the comparison is fair and offline; the real app uses Esri tiles** (see
`docs/visual-qa/live-map/*.png` for renders with the real tile style). "Similarity" is a coarse pixel metric
(1.0 = identical) dominated by photos/copy; each row lists what differs after looking at the image
(`docs/visual-qa/<screen>_compare.png`, Stitch left, Flutter right).

Common residuals: copy and currency (NOK/Vipps/BankID/Norwegian) replaced by real EUR fare / cash-or-card /
truthful English; the Stitch export's own broken portrait on `trip_complete_receipt` is shown with the working
Erik photo; text is Inter in both, but the Flutter render was not compared on a physical device; the
"MOCK POSITION" badge is an intentional extra on tracking screens.

| Stitch folder | Similarity | Result | Residual differences |
|---|---|---|---|
| splash_screen | 0.996 | matched | none visible (brand emblem now the real logo on white tile) |
| splash_onboarding (`/intro`) | 0.955 | built | Norwegian chip/copy and NOK/BankID lines replaced by English truthful text; sample fare EUR 17.44 |
| onboarding_1 / 2 / 3 | 0.979 / 0.935 / 0.975 | matched | Vipps tile/badge removed (Card demo + Cash only); prices replaced by estimate / "Demo"; slide 2 chip reads "Live status updates" and the body says the map position is a demo |
| welcome_screen | 0.978 | matched | EN/NO toggle and the "Instant sign-in with BankID & Vipps" line removed (not built) |
| login_sign_up (`/auth`) | 0.951 | built | language chip, Google/Vipps buttons, divider, "Fast Pass", fingerprint button and footer links removed; "Forgot password?" instead of "Forgot code?"; logo tile shows the new emblem |
| log_in_screen | 0.973 | matched | "Secure sign-in" instead of "BankID Ready"; fingerprint button, OR divider and Vipps/Google/Apple tiles removed; returning-rider card shows the remembered e-mail with a "Use" button |
| create_account_step_1 of 2 | 0.853 | matched | Stitch step 2 (SMS code) removed: **stepper is 2 steps**; optional phone field moved to step 1; BankID & Vipps card removed |
| create_account_step 2 of 2 (Stitch step 3) | 0.854 | matched layout | biometric row and the telemetry/marketing consents removed (only the Terms consent remains); "Step 2 of 2" |
| home_oslo_map | 0.970 | matched | 4 mock cars, 0g CO2 chip, locate button; "Pay with cash or card" card instead of "Vipps Quick-Pay" |
| search_destination | 0.935 | matched | results come from the Oslo mock dataset |
| confirm_pickup | 0.958 | matched | pickup note is local |
| **ride_selection_oslo_s_to_osl** | 0.921 | **rebuilt exactly** (map 320 px + pill + EV chip + legend + sheet + 3 photo cards + Best Choice + payment row + notice row + Request button + nav) | one real fare for all classes (EUR) with "Estimated fare"/"Incl. fees & tax"; "Estimated arrival HH:mm" instead of "Guaranteed arrival"; payment row shows real cash/card with a working "Change" picker; flight note replaced by "One fare for every vehicle"; footer "Cancel until the trip starts - Demo payment" |
| choose_your_ride_oslo_s_to_osl ("Confirm And Pay" layout, Available Fleets list) | 0.920 | built as `/fleets` (reached from the layers button on ride selection) | header text is "Choose Your Ride" (design calls it "Confirm And Pay" but shows the fleet list); NOK -> EUR; "Straight line" chip instead of "Live GPS"; Winter Ready blurb replaced by the one-fare note |
| confirm_and_pay | 0.931 | matched layout | Vipps row and "+ Add payment method" removed; Visa row replaced by Card (demo); "Book ride" button |
| searching_for_driver | 0.925 | matched | "Searching for a driver..." English copy; elapsed timer instead of "< 45s"; beacon pill "Demo car"; Norwegian route labels in English |
| driver_found_erik_larsen | 0.962 | matched | **photos, rating 4.9, 1,840+ trips, languages, 100% Hybrid, vehicle photo are demo**; chat, share, SOS and pickup "Edit" removed, Call driver kept (real `tel:`); driver first name only (API) |
| live_tracking_3_states (driver_en_route; in_progress rendered from the same layout) | 0.948 / 0.884 | matched | **PIN 4821 card is a demo** generated locally; plate/car/colour/fare real; map line is a mock; in-trip state has no separate Stitch screenshot (it is the design's third segment) |
| live_trip_driver_arrived_pin_4821 | 0.937 | matched | pill shows the real route and duration; "Hybrid"/"Midnight Slate Blue" replaced by real make/model/colour; payment line real |
| rate_and_tip_driver | 0.873 | matched | tip chips in EUR ("+EUR 5.00"), Vipps note replaced by cash/card demo line; "63/300" counter reflects the typed text |
| trip_complete_receipt | 0.904 | matched | portrait is the working Erik photo (Stitch's own is broken), 4.98 badge demo; airport toll row absent; payment row is the demo-payment confirmation |
| trip_receipt | 0.919 | matched | real route map; driver rating chip demo; CO2 stamp is an estimate; extra Rate / Re-book / timeline rows |
| trip_history_receipts | 0.907 | matched ("Scheduled" tab and the segmented control removed) | cards from real history; vehicle-class text replaced by payment method; summary card uses the CO2 estimate |
| profile_wallet | 0.937 | matched | balance card replaced by real completed-trips + CO2 estimate (no balance/top-up); payment list shows only the real Cash/Card default; Vipps, Add Payment Method, Add New Place, preferences, GDPR export and Delete account removed |
| profile tab (no Stitch screen) | n/a | built from the same blocks | not compared |

Forgot / reset password, legal pages, cancel sheet, report sheet, error/empty/skeleton states: no Stitch screens;
built with the same header, fields and buttons, not visually compared. **Not visually verified on a real
device or emulator.**

## 6. Map

One shared tile-layer factory (`buildTileLayer`): **Esri World Street Map** (`.../World_Street_Map/MapServer/tile/{z}/{y}/{x}`,
keyless), maxNativeZoom 19, User-Agent header, small attribution "Esri, HERE, Garmin, OpenStreetMap contributors",
a mild desaturate/brighten colour filter, and the pale Stitch colour as loading placeholder (never black).
Compared by viewing `docs/visual-qa/live-map/{home,ride_selection,tracking_*}.png` against the Stitch maps:
pale land, green parks, blue water and few labels now match in character; Esri's main roads are orange/brown
where Google's are white/grey, which is the one visible difference. CARTO needs a key now (watermark), plain OSM
was busy and grey. Cars (4 mock cars with ETA pills on home, ride selection and the fleets list), the driver
pin / rotated driver car, pickup halo, navy drop-off square, solid teal + dashed navy route are visible on every
map screen.

**Tile terms (blocker for production):** Esri's public tile service needs no key and is acceptable for a POC /
demo with attribution. A production release needs a licensed provider or key (Google Maps, MapTiler, Mapbox or an
Esri subscription); only `kMapTileUrl` / `buildTileLayer` change.

**OpenFreeMap vector basemap (tried, reverted):** liberty/bright/positron via `vector_map_tiles` + `vector_tile_renderer`
were tried to get Google-like white roads. Reverted to Esri because: the package supports flutter_map 8 only in beta
(9.0.0-beta.13 / 10.0.0-beta.x; stable 8.0.0 needs flutter_map ^7, and a beta was ruled out); the style loads but the
vector layer paints nothing in `flutter test` (no renders to compare); and a real Windows release build showed only the
fallback raster (not verified to render vectors). OpenFreeMap terms if tried again: free public instance, attribution
"OpenFreeMap (c) OpenMapTiles Data from OpenStreetMap" required, self-host or paid provider for production.
The Esri orange/brown main roads remain the one visible map difference from Stitch.

The live renders fetch tiles with `dart:io` (cached) because `flutter test` cannot complete NetworkImage loads;
the offline visual-QA renders use a static map crop from the Stitch export instead. The old shared "global map"
layer was removed (it rendered black behind screens).

## 7. Backend contracts that are still missing

No websocket / push; no driver live-location; no rating, review, tip or support-report endpoint; no payment
provider; no Google / phone-OTP / Vipps / BankID auth; no nearby-cars, geocoding, routing or saved-places
endpoints; no wallet or saved cards; no PIN, photos, driver rating / trip count in the ride resource; fare
independent of vehicle class; no scheduled rides; no CORS (web unsupported); no receipt/PDF or GDPR endpoints.

## 8. Builds, blockers and unmet criteria

- APK (debug) and Windows (release) builds succeed.
- A `flutter run` session on an Android emulator and a running `rider_app.exe` (locks the Windows debug build
  output, LNK1168) exist outside this work and were not touched; the Windows build was therefore done in release
  mode.
- **Rating / tip / report in Admin: BLOCKED** (no backend support; device-local only).
- **Two-phone acceptance (Rider + Driver app): NOT verified.**
- **iOS: not built.** Not run on a physical device by this work.
- Notifications are an in-app banner + haptic, not OS notifications.
- Map tiles: Esri public tile service is fine for a demo with attribution; production needs a licensed provider or key.
- Chat, share and SOS tiles (and their unread dot) are removed: they do not exist.
- Session restore (splash): 8 s timeout; timeout/network keeps the token and shows "Try again" + "Sign in again"; 401 goes to login (tests: `test/auth/auth_session_test.dart`, `test/widgets/auth_screens_test.dart`; render: `docs/visual-qa/splash_screen@restore_failed_compare.png`).
- Start the backend on :8001 before launching the app (`php -S 0.0.0.0:8001 ...`, README section 3).
- Android emulator reaches the backend at `http://10.0.2.2:8001` (default on Android); a physical phone needs
  `--dart-define=API_BASE_URL=http://<pc-ip>:8001`.

## 9. Integration table (real backend at :8001, `test_live/backend_flow_test.dart`)

| # | Step | Status | Evidence |
|---|---|---|---|
| 1 | Register (JWT payload at top level), duplicate e-mail -> 422 field error | verified | live 02, 03 |
| 2 | Login, `auth/me`, `me/rider`; default payment method PATCH | verified | live 04 |
| 3 | **JWT refresh rotation: old token 401, new token 200** | verified | live 04b |
| 4 | **Proactive single-flight refresh (< 5 min) + refused refresh -> sign-out hook** | verified | live 04c |
| 5 | Forgot password always 202 | verified | live 05 |
| 6 | Fare estimate equals the documented formula | verified | live 06 |
| 7 | Create ride, idempotent retry, second active ride 409 | verified | live 07 |
| 8 | Manager sees the ride (Admin Trips parity via API) | verified via API (not through the Admin UI) | live 08 |
| 9 | Lifecycle observed by polling: requested > offered > accepted > driver_en_route > arrived > in_progress > completed | verified, driver side **scripted** | live 09 |
| 10 | History + 7-step timeline; manager/audit parity | verified via API | live 10, 11 |
| 11 | Riders cannot see staff-only fare fields or other riders' rides | verified | live 12, 14 |
| 12 | Cancel with reason (3-char minimum, second cancel 409) | verified | live 13 |
| 13 | Logout revokes the token; next call 401 | verified | live 15 |
| 14 | Rating / tip / payment / driver position / report visible in Admin or from a real Driver app | **mocked / blocked** | section 3 and 8 |
