# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Reciclalo App — a SaaS platform for geolocated coordination of recyclable waste pickup. It connects two user roles:

- **Ciudadano / Comercio (Generador)**: reports available recyclable material (type, volume, photo, GPS location) and views nearby drop-off points.
- **Recolector / Operador**: views active pickup requests near them on an interactive map, and marks pickups as completed.

Current scope (see `brief/brief-v0.2.0.md`): simple listing creation with photo/material type/GPS location, an interactive map for collectors to view and accept requests, and pickup confirmation. Out of scope for now: AI-based material classification, payments/wallet, in-app chat (WhatsApp/phone is used instead), and integration with municipal waste systems.

Design/product context docs live in `brief/` (problem framing) and `persona/` (target personas, app map, user flow) — read these before making product/UX decisions.

## Repository structure

- `backend/` — Django REST backend (project name `config`), PostgreSQL database.
- `frontend/` — Flutter app (Dart), currently the default `flutter create` scaffold with no custom screens yet.

Both are freshly scaffolded: the backend has no apps beyond Django's built-ins yet, and the frontend has no custom widgets beyond the default counter demo. When adding backend functionality, create dedicated Django apps rather than growing `config/`. When adding frontend functionality, establish a `lib/` structure (e.g. `screens/`, `widgets/`, `services/`, `models/`) as real screens are added.

## Backend (Django)

Setup and common commands, run from `backend/`:

```bash
python -m venv venv && source venv/bin/activate   # create/activate virtualenv
pip install -r requirements.txt                    # install deps (Django, psycopg2-binary)
python manage.py migrate                            # apply migrations
python manage.py runserver                          # run dev server
python manage.py startapp <name>                    # create a new Django app
python manage.py makemigrations                     # generate migrations after model changes
python manage.py test                                # run tests
python manage.py createsuperuser                    # create an admin user
```

- Settings: `backend/config/settings.py`. `DATABASES` is hardcoded to a local PostgreSQL instance (`recicladora` db, `postgres`/`postgres` credentials, `localhost:5432`) — a local Postgres server with that database must exist for the backend to run. `DEBUG = True` and the `SECRET_KEY` are dev-only placeholders; do not treat them as production-ready.
- `venv/` and `__pycache__/` under `backend/` are local/untracked — don't commit them.

## Frontend (Flutter)

Common commands, run from `frontend/`:

```bash
flutter pub get       # install dependencies
flutter run            # run the app (device/emulator/web)
flutter analyze        # static analysis (uses analysis_options.yaml, flutter_lints)
flutter test            # run tests (test/widget_test.dart)
flutter test test/widget_test.dart   # run a single test file
```

- Lints come from `package:flutter_lints/flutter.yaml`, configured in `frontend/analysis_options.yaml`. Platform build directories (`android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`) and `build/` are excluded from analysis.
- No backend integration, routing, or state management library is set up yet — these will need to be chosen when real features are built.
