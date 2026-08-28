# Plan de Implementación — v0.1 "EcoRecicla Ciudadano"

Plan de implementación de la primera versión del producto, cubriendo backend y frontend. El alcance está definido por la documentación en `persona/` (`persona.V0.1.md`, `app-map-v0.1.md`, `flujo-v0.1.md`) y acotado por `brief/brief-v0.2.0.md`.

## 1. Alcance de v0.1

**Dentro de alcance** (vista Ciudadano/Generador únicamente — la vista Recolector no está definida aún en `persona/` y queda fuera de esta versión):

- Ingreso rápido / inicio de sesión.
- Home Ciudadano con "Mis Solicitudes Activas" (estado: Pendiente / Aceptada / En camino).
- Publicar una solicitud de retiro: tipo de material (Plástico / Cartón / Vidrio / Metal), foto, ubicación GPS.
- Detalle de una solicitud (foto, tipo de residuo, datos del recolector asignado si aplica).
- Pantalla de confirmación/estado tras publicar ("Buscando recolector cercano").
- Historial de retiros completados (fecha + tipo de material).

**Fuera de alcance** (según `brief/brief-v0.2.0.md`):

- Clasificación automática de material con IA.
- Pagos, billetera digital o compra-venta de material.
- Chat interno en tiempo real (se usa WhatsApp/teléfono).
- Integración con el sistema municipal de aseo.
- Vista/app del Recolector, mapa interactivo de aceptación de solicitudes, y el ciclo de vida completo de una solicitud (aceptar, marcar en camino, completar) — v0.1 solo necesita que estos estados existan como datos para que el Ciudadano los visualice; la lógica para que un recolector los cambie se implementa en una versión posterior.

## 2. Backend (Django)

Ubicación: `backend/`. Proyecto Django `config` ya scaffoldeado, sin apps propias todavía.

### 2.1 Dependencias nuevas

Añadir a `requirements.txt`:

- `djangorestframework` — API REST para el frontend Flutter.
- `django-cors-headers` — permitir requests desde la app Flutter (web/emulador) durante desarrollo.
- `Pillow` — requerido por `ImageField` para las fotos de solicitud.

### 2.2 Nueva app: `solicitudes`

```bash
python manage.py startapp solicitudes
```

Registrar en `INSTALLED_APPS` junto con `rest_framework` y `corsheaders`; añadir `CorsMiddleware` a `MIDDLEWARE`.

**Modelos** (`solicitudes/models.py`):

- `TipoMaterial` — choices o modelo simple: Plástico, Cartón, Vidrio, Metal (fijo para v0.1, según `app-map-v0.1.md`).
- `SolicitudRetiro`:
  - `usuario` (FK a `auth.User`, el ciudadano que publica).
  - `tipo_material` (choice).
  - `foto` (ImageField).
  - `latitud`, `longitud` (Decimal/Float) — ubicación GPS confirmada.
  - `direccion_referencia` (CharField, opcional — ajuste manual de la ubicación).
  - `estado` (choice: `pendiente`, `aceptada`, `en_camino`, `completada`).
  - `recolector` (FK a `auth.User`, null=True — se completa cuando exista lógica de recolector; en v0.1 puede quedar sin usar o poblarse manualmente vía admin para poder mostrar la pantalla de detalle con datos de recolector).
  - `creado_en`, `actualizado_en` (timestamps).

**API** (`solicitudes/views.py`, `solicitudes/serializers.py`, `solicitudes/urls.py`), vía DRF:

- `POST /api/solicitudes/` — crear solicitud (Formulario de Retiro → "Publicar Retiro").
- `GET /api/solicitudes/?usuario=me&estado=activas` — listar "Mis Solicitudes Activas" (estado ≠ completada).
- `GET /api/solicitudes/{id}/` — Detalle de Solicitud.
- `GET /api/solicitudes/?usuario=me&estado=completada` — Historial de Reciclaje.

**Autenticación**: usar autenticación por sesión/token simple de DRF (`TokenAuthentication` o `SessionAuthentication`) para soportar la pantalla de "Ingreso Rápido / Inicio de Sesión". No se requiere un sistema de registro complejo en v0.1; puede bastar con login contra `auth.User` existente (creado vía `createsuperuser` o un endpoint mínimo de registro).

**Media**: configurar `MEDIA_URL` / `MEDIA_ROOT` en `settings.py` y servir archivos subidos en desarrollo (`urls.py` + `static()` helper) para que las fotos de las solicitudes sean accesibles desde el frontend.

**Admin**: registrar `SolicitudRetiro` en `admin.py` para poder inspeccionar/editar solicitudes (útil para simular manualmente cambios de estado y asignación de recolector mientras no existe la app de Recolector).

### 2.3 Tareas backend (orden sugerido)

1. Agregar dependencias a `requirements.txt`, instalar en `venv`.
2. Configurar `rest_framework`, `corsheaders`, `MEDIA_URL`/`MEDIA_ROOT` en `settings.py`.
3. Crear app `solicitudes`, definir modelos, migrar (`makemigrations` / `migrate`).
4. Implementar serializers, viewsets/views y rutas bajo `/api/solicitudes/`.
5. Implementar endpoint(s) de autenticación (login) mínimos.
6. Registrar modelos en el admin; crear superusuario y datos de prueba.
7. Probar la API manualmente (DRF browsable API o `curl`) contra los 4 endpoints anteriores.

## 3. Frontend (Flutter)

Ubicación: `frontend/`. Actualmente es el scaffold por defecto de `flutter create`, sin pantallas propias.

### 3.1 Diseño de pantallas vía Stitch MCP

El servidor MCP `stitch` ya está conectado. Las pantallas de v0.1 se generan en Stitch usando como base el prompt documentado en `docs/design-prompt.md`, dentro de un proyecto Stitch llamado **"ecorecicla ciudadano"**.

Flujo de trabajo con Stitch:

1. Crear el proyecto en Stitch con `mcp__stitch__create_project` (nombre: `ecorecicla ciudadano`).
2. Generar las pantallas descritas en `docs/design-prompt.md` (Ingreso, Home, Detalle de Solicitud, Formulario de Retiro, Confirmación/Estado, Historial) con `mcp__stitch__generate_screen_from_text`, usando el prompt de esa doc como contexto/estilo compartido para mantener consistencia visual entre pantallas.
3. Revisar con `mcp__stitch__list_screens` / `mcp__stitch__get_screen`, e iterar con `mcp__stitch__edit_screens` o `mcp__stitch__generate_variants` según feedback.
4. (Opcional) Definir un design system consistente con `mcp__stitch__create_design_system` (o `create_design_system_from_design_md` a partir de `docs/design-prompt.md`) y aplicarlo a las pantallas con `mcp__stitch__apply_design_system`, para que los 6 flujos compartan paleta, tipografía y componentes.
5. Usar las pantallas de Stitch como referencia visual (layout, jerarquía, componentes) para implementar los widgets Flutter reales — Stitch entrega el diseño/prototipo navegable, no el código final de producción; la implementación Flutter se hace a mano siguiendo esa referencia.

### 3.2 Estructura de proyecto

Establecer estructura bajo `frontend/lib/`, reemplazando el scaffold de contador por defecto:

```
lib/
  main.dart
  screens/
    login_screen.dart
    home_screen.dart
    solicitud_detalle_screen.dart
    solicitud_form_screen.dart
    confirmacion_screen.dart
    historial_screen.dart
  widgets/
    solicitud_card.dart
    material_selector.dart
  models/
    solicitud.dart
    usuario.dart
  services/
    api_client.dart
    solicitudes_service.dart
    auth_service.dart
    location_service.dart
```

### 3.3 Dependencias nuevas (`pubspec.yaml`)

- `http` (o `dio`) — consumo de la API Django.
- `image_picker` — tomar/subir foto del paquete.
- `geolocator` (+ `permission_handler` si hace falta) — confirmación de ubicación GPS.
- Estado/navegación: elegir una opción simple para v0.1 (p. ej. `go_router` para navegación + `provider` o `riverpod` para estado); no hay decisión previa tomada, se define al iniciar esta fase.

### 3.4 Pantallas y su mapeo a `app-map-v0.1.md` / `flujo-v0.1.md`

1. **Login** (`login_screen.dart`) — ingreso rápido, navega a Home.
2. **Home** (`home_screen.dart`) — lista "Mis Solicitudes Activas" (`SolicitudCard` por estado), botón "+ Publicar Reciclaje", acceso a Historial.
3. **Detalle de Solicitud** (`solicitud_detalle_screen.dart`) — abre desde una `SolicitudCard`.
4. **Formulario de Retiro** (`solicitud_form_screen.dart`) — 3 pasos (material, foto, ubicación) + botón "Publicar Retiro", según el happy path de `flujo-v0.1.md`.
5. **Confirmación/Estado** (`confirmacion_screen.dart`) — mensaje "Buscando recolector cercano" tras publicar.
6. **Historial** (`historial_screen.dart`) — lista de retiros completados.

### 3.5 Tareas frontend (orden sugerido)

1. Generar y validar las 6 pantallas en Stitch (proyecto "ecorecicla ciudadano"), usando `docs/design-prompt.md`.
2. Definir dependencias de navegación/estado y agregarlas a `pubspec.yaml`.
3. Implementar `models/` y `services/api_client.dart` apuntando a la API Django (`/api/solicitudes/`, login).
4. Implementar pantallas en el orden del flujo: Login → Home → Formulario de Retiro → Confirmación → Detalle → Historial, usando los diseños de Stitch como referencia.
5. Integrar `image_picker` y `geolocator` en el Formulario de Retiro.
6. Conectar cada pantalla a los endpoints reales del backend (reemplazar datos mock).
7. `flutter analyze` y `flutter test` antes de dar por cerrada la fase.

## 4. Integración y flujo end-to-end

Una vez backend y frontend tengan sus piezas base, validar el camino feliz completo de `persona/flujo-v0.1.md`:

Login → Home → tocar "+ Publicar Reciclaje" → seleccionar material → tomar/subir foto → confirmar GPS → tocar "Publicar Retiro" → Pantalla de Confirmación ("Buscando recolector cercano") → la solicitud aparece en "Mis Solicitudes Activas" en Home.

Adicionalmente, verificar:

- Detalle de Solicitud muestra correctamente los datos de una solicitud creada.
- Historial muestra las solicitudes marcadas como `completada` (se puede marcar manualmente desde el admin de Django para pruebas, ya que el flujo de recolector no existe todavía).

## 5. Fuera de esta fase (siguientes versiones)

- Vista y app del Recolector (mapa interactivo, aceptar solicitudes, marcar en camino/completado).
- Notificaciones push al ciudadano cuando cambia el estado de su solicitud.
- Registro de usuario completo (más allá de login básico).
- Despliegue a producción (hosting backend, build de Flutter para stores/web, `DEBUG=False`, `SECRET_KEY` y credenciales de base de datos fuera del código).
