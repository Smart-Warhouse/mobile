# SW Floor (`sw_floor`)

Flutter app (Android + iOS) for the **people on the warehouse floor** of the Smart Warehouse graduation
project («المخزن الذكي» / SW·Fleet). It talks to the central FastAPI server (`code/backend`) over REST and the
`/ws/live` WebSocket exactly as specified in [`docs/02-api-contract.md`](../../docs/02-api-contract.md). The web
dashboard (`code/dashboard`) is for the control room; this app is for a phone or tablet in the aisle.

Use cases ↔ requirement ids and the architecture: [`docs/09-mobile.md`](../../docs/09-mobile.md).

## Run

Requirements: Flutter **3.44** (Dart 3.12) on PATH. On this machine a stray Dart 3.7 sits first on PATH, so
format with `C:\flutter\bin\dart`, not bare `dart`.

```powershell
cd code\mobile
flutter pub get                 # also generates lib/l10n/generated (ARB → Dart)
flutter run                     # a connected phone, or an emulator you started yourself
```

Quality gate (all must pass before a change is done):

```powershell
flutter pub get
C:\flutter\bin\dart format lib test
flutter analyze                 # No issues found!
flutter test                    # models, envelope/errors, map transform, hold-to-stop, RTL smoke, teleop
```

## Configure the server URL

There is no build-time configuration. On the sign-in screen enter:

| Where the server runs | Server address |
|---|---|
| Warehouse LAN (default) | `http://192.168.50.2:8000` (the server's LAN IP) |
| Android emulator, server on the same PC | `http://10.0.2.2:8000` |
| iOS simulator, server on the same Mac | `http://localhost:8000` |
| Physical phone, server on your laptop | `http://<laptop LAN IP>:8000` (same Wi-Fi) |

`http://` is added when missing and a trailing `/` or `/api` is dropped. The plug icon in the field calls
`GET /api/health` to test the address before signing in. Development accounts (`admin`, `operator`, `viewer`) are
seeded by the backend; their passwords are in `code/backend/.env.example`.

What is remembered: the server address, the last username and the UI language (shared_preferences); the JWT
(flutter_secure_storage: Android Keystore / iOS Keychain). The password is never stored. A 401 `unauthorized` on
any call, an expired token, or WebSocket close code `4401` signs out back to this screen.

Plain HTTP/WS on the LAN is allowed: Android `usesCleartextTraffic="true"`, iOS ATS `NSAllowsArbitraryLoads` +
`NSAllowsLocalNetworking` (with a local-network usage string). Tighten both if the server ever moves to HTTPS.

## Structure

```
lib/
  main.dart, app.dart           ProviderScope (no auto-retry), MaterialApp.router, ar (default) / en, light/dark
  core/
    json/json_reader.dart       typed, non-throwing JSON reader (absent keys normal, int|double, UTC times)
    network/                    createApiDio + AuthInterceptor (Bearer, Accept-Language, 401 → sign out),
                                ApiEnvelope ({data, meta}), ApiFailure + ErrorCode (error envelope),
                                Result/Ok/Err + callApi/guardApi, server_url (normalise, ws://…/ws/live?token=)
    realtime/                   LiveSocket (backoff 1/2/5/10 s, ping, 4401), LiveFrame parser, LiveController
                                (snapshot state) + liveFrameBus (task/event/inventory frames)
    router/                     Routes constants, GoRouter with the single auth redirect
    storage/app_storage.dart    AppPrefs (shared_preferences) + SecretStore (secure storage / memory)
    theme/                      SwTokens (docs/05 semantic tokens, light/dark), AppTheme, spacing
    l10n/labels.dart            enum → label, ErrorCode → message, number/time formatting
    widgets/                    HoldToStopButton, StatusBadge + tones, ConnectionChip, states, confirmAction
  features/<feature>/
    data/                       models (hand-written over JsonReader) + repository (Result-returning)
    domain/                     pure logic (map_transform, teleop_loop)
    presentation/               screens, widgets, Riverpod providers
    auth  fleet  alerts  map  tasks  pallets  drive  settings
  shared/
    providers/repository_providers.dart
    widgets/floor_frame.dart    STOP ALL bar + E-stop takeover + alert banner around every signed-in screen
    widgets/tab_shell.dart      bottom navigation (Fleet, Map, Tasks, Inventory, Alerts)
  l10n/app_ar.arb (template), app_en.arb, generated/ (gitignored)
assets/fonts/                   Thmanyah Sans / Serif Text, Lexend (TTF converted from docs/brand/fonts)
test/                           support/ (FakeAdapter, FakeWebSocketChannel, contract fixtures) + suites
```

Layering: widget → Riverpod provider → repository (`Result<T>`, never throws) → `callApi` → Dio. No widget touches
Dio. Every user-visible string is in both ARB files; layouts use directional insets/alignments; the map, joystick
and telemetry numbers are pinned LTR.

## Dependencies

`flutter_riverpod` 3, `go_router` 18, `dio` 5, `web_socket_channel` 3, `shared_preferences`,
`flutter_secure_storage`, `phosphoricons_flutter`, `intl`, `flutter_localizations`. Nothing else at runtime; no
code generation except `flutter gen-l10n`.

`phosphoricons_flutter` is used instead of `phosphor_flutter`: `phosphor_flutter` 2.1.0 extends `IconData`, which is
a `final` class on Flutter 3.44, so it does not compile (same Phosphor glyphs and `PhosphorIconsRegular.x` API).

## Fonts

`assets/fonts/*.ttf` were converted locally (fontTools) from the self-hosted WOFF2 files in `docs/brand/fonts/`
(Flutter cannot load WOFF2): Thmanyah Sans 300–900, Thmanyah Serif Text 700 (Arabic headings), Lexend 300–900
(static instances of the variable Latin subset; licence in `assets/fonts/Lexend-OFL.txt`). Nothing was downloaded.
