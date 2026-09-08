# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Reciclalo App (branded "EcoRecicla" in the UI) — a SaaS platform for geolocated coordination of recyclable waste pickup. It connects two user roles:

- **Ciudadano / Comercio (Generador)**: reports available recyclable material (type, photo, GPS location), tracks its pickup, and earns EcoPuntos/racha for recycling.
- **Recolector / Operador**: views nearby pickup requests on an interactive map, accepts them, navigates to the pickup point, and marks them as completed (capturing the weight collected).

Both roles also share a fidelización/gamification flow: EcoPuntos earned from completed pickups and racha milestones, redeemable for rewards. Out of scope for now: AI-based material classification, payments/wallet beyond EcoPuntos, in-app chat (WhatsApp deep links are used instead), push notifications, ratings, and integration with municipal waste systems.

Product/design context lives in `brief/` (problem framing), `persona/` (personas, app map, user flow), `research/`, and `docs/` (design prompts and implementation plans: `docs/picker-flow-implementation-plan.md` for the collector flow, `docs/flujo-3-fidelizacion-gamificacion/` for the EcoPuntos/racha/rewards flow — spec, design prompt, and implementation plan). Read these before making product/UX decisions.

## Repository structure

- `backend/` — Django REST backend (project `config`), PostgreSQL, token auth.
  - `solicitudes/` — pickup requests, collector profiles, assignments. The core domain app.
  - `roles/` — registration, role (Django `Group`) checks, and `/api/auth/me/`.
  - `gamificacion/` — EcoPuntos, rewards catalog/redemption, and the weekly racha (streak) engine.
- `frontend/` — Flutter app. `lib/` is organized as `models/`, `services/`, `screens/`, `widgets/`, `theme/`.

Add backend functionality as dedicated Django apps rather than growing `config/`. Collector-specific Flutter code lives under the `picker/` subfolders of `screens/` and `widgets/`.

## Backend (Django)

Run from `backend/`:

```bash
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver                  # add 0.0.0.0:8000 to reach it from a phone
python manage.py test solicitudes            # needs PostgreSQL
python manage.py createsuperuser
python manage.py seed_picker_demo            # demo users + nearby pending requests
python manage.py seed_gamificacion_demo      # sample rewards + starter balance for the demo users
python manage.py cerrar_semana_racha         # closes last week's racha for every user with activity
```

- Settings: `backend/config/settings.py`. `DATABASES` is hardcoded to a local PostgreSQL instance (`recicladora` db, `postgres` user, `localhost:5432`) — that database must exist for the backend to run. `DEBUG = True`, the `SECRET_KEY`, and `CORS_ALLOW_ALL_ORIGINS` are dev-only.
- `config/settings_test.py` overrides the database with in-memory SQLite so the suite runs without PostgreSQL: `python manage.py test solicitudes roles gamificacion --settings=config.settings_test`. Prefer this when you only need to verify logic.
- `seed_picker_demo` creates `ciudadano_demo` / `recolector_demo` (password `demo12345`) plus pending requests around `--lat`/`--lng`, so the collector map has pins to work with.
- `venv/`, `__pycache__/`, and `media/` are local/untracked — don't commit them.

### Domain model (`solicitudes/models.py`)

- `SolicitudRetiro` — a pickup request: material, photo, coordinates, optional `precio` (null = free) and `telefono_contacto`, `estado`, and a nullable FK to `Recolector`.
- `Recolector` — a 1-to-1 profile on `User` holding availability, last reported location, and the completed count. Created on demand via `Recolector.para_usuario(user)`, so users registered before the collector flow existed still work. Don't assume the row exists.
- `AsignacionRetiro` — the accept/complete/reject history. **A rejection never changes `SolicitudRetiro.estado`**; it only records that this collector passed, so `cercanas` stops offering it to them.

Request states: `pendiente → aceptada → completada` (`en_camino` exists but is unused so far). `completar` requires `peso_kg` in the body — the collector captures it there — and, once the row is saved, calls `gamificacion.services.acreditar_por_completado` to credit the citizen's EcoPuntos. That's the only coupling point between the two apps; `solicitudes` otherwise knows nothing about points/racha.

### Gamificación: EcoPuntos, rewards, and racha (`gamificacion/`)

- `SaldoEcoPuntos` (one per user) and `TransaccionEcoPuntos` (append-only ledger: `acreditacion` for material completions, `bono_racha` for streak milestones, `canje` for redemptions) — see `gamificacion/services.py` for all point math. `Recompensa`/`Canje` are the rewards catalog and redemption record; `canjear_recompensa` uses `select_for_update` the same way `aceptar`/`completar` do in `solicitudes`.
- Racha (streak) is **weekly**, tracked per `(usuario, rol)` in `ProgresoRacha`, and evaluated by the management command `cerrar_semana_racha`, not in real time. **`cerrar_semana_racha` (with or without `--fecha`) always closes the week *before* the given/current date** — like a Monday cron evaluating the week that just ended. To see the effect of something completed today, you must pass `--fecha` at least 7 days in the future; passing today's date evaluates last week and no-ops on today's activity. This is idempotent (`ProgresoRacha.semana_evaluada_hasta` guards re-evaluation).
- Hitos (2/4/8/12/26/52 weeks) award a one-time `bono_racha` from `HITOS_PUNTOS` in `services.py` — Ciudadano and Recolector have separate (Recolector is lower, since completing pickups is more frequent than generating them).
- `EventoPendiente` is a per-user notification queue (`acreditacion` / `hito_racha`) consumed by the Flutter app's root screens on open, so the citizen (who isn't the one calling `completar`) still sees the EcoPuntos/hito modals. Don't assume points/racha are visible immediately after an API call — they show up via this queue.
- `seed_gamificacion_demo` seeds a sample rewards catalog and a starting balance for `ciudadano_demo`/`recolector_demo`.

### Roles and permissions

Roles are plain Django `Group`s named `Ciudadano` and `Recolector`, assigned at registration. Check them with `roles.permissions.EsCiudadano` / `EsRecolector` — reuse these rather than writing new group checks. `solicitudes/permissions.py` adds `PuedeVerSolicitud`, which lets a citizen see only their own requests and a collector see unassigned ones or their own.

`SolicitudRetiroViewSet` serves both roles from one endpoint: `get_queryset`, `get_permissions`, and `get_serializer_class` all branch on the action and the caller's role. When adding an action for collectors, add it to `ACCIONES_RECOLECTOR` in `solicitudes/views.py` — otherwise it inherits the citizen's "only my own requests" queryset and will 404.

### API

Auth is DRF `TokenAuthentication` (`Authorization: Token <key>`).

```
POST /api/auth/login/                          token only
GET  /api/auth/me/                             user + rol; the app needs this to route by role
POST /api/roles/registro/                      register with rol=Ciudadano|Recolector

GET  /api/solicitudes/?estado=activas|completada    citizen: own requests
POST /api/solicitudes/                              citizen: publish (multipart, photo)
GET  /api/solicitudes/{id}/

GET  /api/solicitudes/cercanas/?latitud=&longitud=&radio_km=
POST /api/solicitudes/{id}/aceptar/             409 if another collector won it
POST /api/solicitudes/{id}/rechazar/
POST /api/solicitudes/{id}/completar/
GET  /api/recolector/perfil/
POST /api/recolector/ubicacion/
POST /api/recolector/disponibilidad/
GET  /api/recolector/solicitudes-aceptadas/
GET  /api/recolector/solicitudes-completadas/

GET  /api/gamificacion/saldo/                        EcoPuntos balance
GET  /api/gamificacion/transacciones/?tipo=          ledger history
GET  /api/gamificacion/recompensas/?categoria=       rewards catalog
POST /api/gamificacion/recompensas/{id}/canjear/     409 if balance is insufficient
GET  /api/gamificacion/racha/                        current streak/protectors for the caller's role
GET  /api/gamificacion/impacto/                      CO2/water/kg recycled (citizen) or completions (collector)
GET  /api/gamificacion/eventos-pendientes/           unseen acreditación/hito modals
POST /api/gamificacion/eventos-pendientes/{id}/marcar-visto/
```

Two serializers cover the same model: `SolicitudRetiroSerializer` (citizen) and `SolicitudRetiroPickerSerializer` (collector — adds `distancia_km`, `ciudadano_nombre`, display labels). The Flutter `Solicitud.fromJson` reads both shapes.

Distance uses `geopy` (`solicitudes/utils.py`), not PostGIS: `cercanas` prefilters with a bounding box in SQL, then discards and sorts by real geodesic distance. `aceptar` and `completar` take a row lock (`select_for_update`) so two collectors racing on the same request produce a 409 rather than a silent overwrite.

## Frontend (Flutter)

Run from `frontend/`:

```bash
flutter pub get
flutter run
flutter analyze                      # keep this at zero issues
flutter test
flutter test test/models/solicitud_test.dart
```

- Set `backendBaseUrl` in `lib/services/api_client.dart` to match where the backend runs (`10.0.2.2` for the Android emulator, the PC's LAN IP for a physical phone).
- `lib/theme/app_theme.dart` holds the design system exported from Stitch: `EcoColors`, `EcoSpacing`, `EcoRadius`, `EcoShadows`, and the text scale. **Use these tokens instead of literal colors or spacing numbers** — the Stitch designs are the source of truth for the visual language.
- Maps use `flutter_map` with OpenStreetMap tiles (`openStreetMapTiles()` in `widgets/picker/eco_map.dart`) — deliberately **not** `google_maps_flutter`, so no API key is needed. Google Maps is still used for turn-by-turn navigation, launched externally via `url_launcher` in `services/maps_service.dart`.
- Navigation is plain `Navigator`/`MaterialPageRoute` plus the named routes in `main.dart`; there is no router package. `lib/routing.dart` maps a role to its root screen: citizens land on `HomeScreen`, collectors on `PickerShell` (the 4-tab bottom nav).
- Neither root shell has a "Perfil" tab: the 4th tab is `RecompensasScreen` (shared by both roles) instead. Profile (account info, sign out, and the entry point to `MiImpactoScreen`) is reached via an account icon — `EcoAppBar` on most screens, a floating button on `PickerMapScreen` since that one is full-bleed with no `AppBar`. Follow this pattern (`EcoAppBar` + `onAbrirPerfil` callback) for any new top-level tab rather than reintroducing a Perfil tab.
- `HomeScreen` and `PickerShell` each poll `GamificacionService.eventosPendientes()` on first frame and show `EcoPuntosModal`/`HitoRachaModal` sequentially for anything unseen (see the `gamificacion/` backend section above for why this queue exists instead of a direct response).
- Lints come from `package:flutter_lints/flutter.yaml` via `analysis_options.yaml`. Platform build directories and `build/` are excluded from analysis.
- `buildEcoTheme()` in `app_theme.dart` sets `FilledButtonThemeData.minimumSize` to `Size.fromHeight(EcoSpacing.touchTarget)` — width `double.infinity` by default, meant for full-width CTAs. A bare `FilledButton` inside a `Row` (or `AlertDialog.actions`, which lays out the same way) will crash with "BoxConstraints forces an infinite width." Override `style: FilledButton.styleFrom(minimumSize: Size(0, EcoSpacing.touchTarget))` for any `FilledButton` that isn't the sole/full-width child of a `Column`.
- Platform config that the collector flow depends on: location permissions in `AndroidManifest.xml` / `Info.plist`, and the `<queries>` VIEW/https intent in `AndroidManifest.xml` that lets `url_launcher` resolve Google Maps and WhatsApp on Android 11+.

## Skills

Custom skills for this repo live under `.claude/skills/` (the directory Claude Code scans for invocable skills).

- `flutter-ui-ux` — Flutter UI/UX development workflow (widget composition, responsive layouts, animations, theming, accessibility). Invoke for Flutter screen/component/animation work.

## Conventions

- Domain names, comments, and user-facing strings are in Spanish; framework and language keywords stay in English. Match this in new code.
- Comments explain *why* a decision was made, not what the line does. Keep them sparse.
- Both suites should stay green and `flutter analyze` should report no issues before wrapping up a change.
