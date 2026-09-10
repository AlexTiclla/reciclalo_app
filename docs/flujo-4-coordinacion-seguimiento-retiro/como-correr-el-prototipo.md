# Cómo correr el prototipo — Flujo 4: Coordinación y Seguimiento del Retiro

Guía práctica para levantar el backend y el frontend después de implementar este flujo, y recorrer el camino feliz de punta a punta (aceptar → coordinar franja → en camino → completar → calificar). Asume que ya se leyó `flujo-4-implementation-plan.md` — acá solo están los pasos de puesta en marcha, no las decisiones de diseño.

---

## 1. Backend (Django)

### 1.1 Entorno

```bash
cd backend
python3 -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

`requirements.txt` en este repo está en UTF-16 (lo dejó el editor de alguien en Windows). Si `pip install -r requirements.txt` falla con un error de parseo, convertilo una vez:

```bash
iconv -f UTF-16 -t UTF-8 requirements.txt > requirements_utf8.txt
pip install -r requirements_utf8.txt
```

### 1.2 Base de datos

`backend/config/settings.py` apunta a PostgreSQL local (`recicladora` / `postgres` / `postgres` / `localhost:5432` — revisá el archivo, alguien puede haber dejado su propia contraseña ahí). Esa base **tiene que existir** antes de migrar:

```bash
# con psql o pgAdmin:
createdb recicladora
```

Si no tenés PostgreSQL a mano y solo querés probar la API sin levantar la app completa, `config/settings_test.py` reemplaza la base por SQLite en memoria — sirve para correr tests, no para `runserver` (el server normal usa `config.settings`, que sí exige Postgres).

### 1.3 Migrar y sembrar datos de demo

```bash
python manage.py migrate
python manage.py createsuperuser          # opcional, para entrar a /admin/
python manage.py seed_picker_demo --lat -17.7833 --lng -63.1821
python manage.py seed_gamificacion_demo
```

`seed_picker_demo` crea (o reutiliza) dos usuarios:

| Usuario | Contraseña | Rol |
| --- | --- | --- |
| `ciudadano_demo` | `demo12345` | Ciudadano |
| `recolector_demo` | `demo12345` | Recolector |

Desde este flujo, `seed_picker_demo` también le carga a `recolector_demo` el teléfono `+59170000001` — sin esto, los botones "WhatsApp"/"Llamar" de las Screens 2 y 3 no tendrían a quién contactar. Si ya tenías la base sembrada de antes (de una corrida del Flujo 3), volvé a correr `seed_picker_demo`: es idempotente y solo completa lo que falte.

`seed_gamificacion_demo` deja un catálogo de recompensas y saldo inicial — no es necesario para este flujo en particular, pero lo vas a querer si también estás probando el modal de EcoPuntos.

### 1.4 Levantar el servidor

```bash
python manage.py runserver 0.0.0.0:8000
```

`0.0.0.0:8000` (no solo `127.0.0.1`) es necesario si vas a probar desde un celular físico en la misma red WiFi — ver §2.2.

### 1.5 Correr los tests del backend

```bash
python manage.py test solicitudes roles gamificacion --settings=config.settings_test
```

Usa SQLite en memoria, así que no depende de que PostgreSQL esté levantado. Al cierre de esta fase corren **54 tests, todos en verde** (35 preexistentes + 19 nuevos de este flujo: coordinación de franja, `en-camino`, `calificar`, `puntos_acreditados`, teléfono del recolector).

---

## 2. Frontend (Flutter)

### 2.1 Instalar dependencias

```bash
cd frontend
flutter pub get
```

No hace falta agregar ningún paquete nuevo para este flujo — `flutter_map`, `latlong2` y `url_launcher` ya estaban en `pubspec.yaml` desde el flujo del recolector.

### 2.2 Apuntar al backend

`frontend/lib/services/api_client.dart` tiene `backendBaseUrl` hardcodeado. Ajustalo según desde dónde corras la app:

| Cómo corrés la app | `backendBaseUrl` |
| --- | --- |
| Emulador Android | `http://10.0.2.2:8000` |
| Web / desktop / simulador iOS | `http://localhost:8000` |
| Celular físico en la misma WiFi que el PC | `http://<IP-LAN-del-PC>:8000` (backend con `runserver 0.0.0.0:8000`) |

Para encontrar la IP LAN: `hostname -I` (Linux) o `ipconfig` (Windows).

### 2.3 Correr la app

```bash
flutter run
```

### 2.4 Analyze y tests del frontend

```bash
flutter analyze     # 0 issues al cierre de esta fase
flutter test         # todos verdes (incluye los tests nuevos de este flujo)
```

---

## 3. Recorrer el Flujo 4 de punta a punta

Como el flujo involucra **dos roles al mismo tiempo** (Ciudadano coordinando, Recolector ejecutando), la forma más simple de probarlo es con **dos sesiones simultáneas**: dos instancias de la app (dos emuladores, o un emulador + un celular físico, o dos pestañas si estás probando contra la API directamente), una logueada como `ciudadano_demo` y otra como `recolector_demo`.

1. **Publicar una solicitud** (`ciudadano_demo`): desde Inicio, "Publicar Reciclaje" — o simplemente usar una de las que ya dejó `seed_picker_demo` alrededor del punto indicado.
2. **Aceptarla** (`recolector_demo`): desde el mapa del recolector, tocar un pin y "Aceptar".
3. **Coordinar franja** — cualquiera de los dos puede empezar:
   - Ciudadano: al abrir la solicitud desde "Mis Solicitudes Activas" cae en la Screen 1 (`ElegirFranjaScreen`) — elegir un día/franja y "Confirmar".
   - Recolector: en `PostAcceptScreen` aparece un banner "Proponer horario" si todavía no hay franja, o "Aceptar" / "Proponer otro" si el ciudadano ya propuso una.
   - Quien no propuso la última franja es quien la confirma (`aceptar-franja`) — ese es el único lado habilitado para aceptar, a propósito (no te podés auto-confirmar).
4. **En camino** (`recolector_demo`): una vez confirmada la franja, aparece el botón "Voy en camino" en `PostAcceptScreen`. Al tocarlo, arranca un ping de ubicación cada ~45 s (`PickerService.actualizarUbicacion`) mientras la app del recolector siga abierta — es lo que alimenta el mapa de seguimiento del ciudadano.
5. **Seguimiento** (`ciudadano_demo`): reabrir la solicitud desde Inicio — ahora cae en la Screen 3 (`SeguimientoRetiroScreen`): timeline de 4 pasos, mapa con la última posición conocida del recolector, y botones de contacto.
6. **Completar** (`recolector_demo`): "Marcar como completado", cargar el peso (`peso_kg`). Esto acredita los EcoPuntos **en este mismo paso** — es la decisión de este flujo, ver `flujo-4-implementation-plan.md` §1.
7. **Ver EcoPuntos y calificar** (`ciudadano_demo`): al volver a Inicio, el modal de EcoPuntos del Flujo 3 aparece solo (cola de `EventoPendiente`, sin cambios). Reabrir la solicitud desde Historial cae en la Screen 4 (`RetiroCompletadoScreen`): resumen + calificación opcional del recolector.

### Atajos para no repetir todo el flujo cada vez

- El backend admin (`/admin/`) permite editar `SolicitudRetiro.estado`/`estado_coordinacion` y `AsignacionRetiro` directamente si solo querés ver una pantalla puntual sin jugar el flujo entero — útil para comparar visualmente contra `stitch_ecorecicla_ciudadano/*/screen.png`.
- `seed_picker_demo` es idempotente: podés volver a correrlo si necesitás solicitudes `pendiente` frescas para repetir la prueba.

---

## 4. Notas y problemas conocidos

- **Teléfono del recolector**: si probás con un usuario Recolector que no pasó por `seed_picker_demo` (por ejemplo, uno que te registraste a mano), los botones de contacto del Ciudadano se ocultan hasta que ese recolector cargue su teléfono desde Perfil → "Teléfono de contacto".
- **`tel:` en Android**: el botón "Llamar" abre el marcador nativo (`AndroidManifest.xml` ya declara el intent `tel:` necesario en Android 11+). En un emulador sin la app de Teléfono puede no responder — es una limitación del emulador, no de la app.
- **ETA / ruta en el mapa**: el mapa de seguimiento muestra la última posición conocida del recolector y una línea recta (no una ruta real ni un tiempo estimado) — es una decisión de diseño explícita, no algo pendiente de implementar (ver `design-prompt.md` y §6 del plan).
- **`flutter analyze` / tests**: si agregás código nuevo a este flujo, mantené ambas suites en verde antes de cerrar — es la regla del proyecto (`CLAUDE.md`).
