# Plan de Despliegue — EcoRecicla

Objetivo: dejar el backend y la base de datos en producción, y la app móvil descargable
sin pasar por Play Store. Stack elegido:

- **Base de datos:** Supabase (PostgreSQL gestionado)
- **Backend:** Render (Django REST, Web Service)
- **Media (fotos de las solicitudes):** Supabase Storage — bucket S3-compatible
- **App móvil:** APK de release, alojado como descarga directa en Supabase Storage
  (sin Play Store, sin cuenta de desarrollador)

Todo el repo es un monorepo (`backend/` + `frontend/` en el mismo repositorio), así que
Render se configura con **Root Directory = `backend/`** y el resto del repo se ignora al
desplegar el backend.

Este plan asume que ejecutas los pasos de Supabase y Render manualmente desde su
dashboard, o a través de los servidores MCP de Supabase/Render conectados a Claude
Code (crear proyecto, correr migraciones, crear el Web Service, setear variables de
entorno, disparar el deploy) — los pasos son los mismos en ambos casos.

## Orden recomendado

No te saltes el orden: cada fase depende de la anterior.

0. **Preparar el código** para leer configuración de producción desde variables de
   entorno (hoy está hardcodeada — ver Fase 0).
1. **Supabase** — crear la base de datos y los buckets de Storage.
2. **Render** — desplegar el backend apuntando a Supabase.
3. **Flutter** — apuntar la app al backend ya desplegado.
4. **Publicar el APK** — generar el release y subirlo a un link de descarga.
5. **Verificación end-to-end.**

---

## Fase 0 — Preparar el código para producción

`backend/config/settings.py` hoy tiene todo hardcodeado a propósito para desarrollo
local (ver `CLAUDE.md`): `SECRET_KEY`, `DEBUG=True`, `DATABASES` apuntando a un
Postgres local, y `MEDIA_ROOT` en disco local. Nada de eso sirve tal cual en Render, así
que esto se resuelve **antes** de la Fase 2, con variables de entorno que sólo existen en
producción (en local, si no están seteadas, todo debe seguir funcionando como hoy).

- [ ] **`SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS` desde variables de entorno**, con los
      valores actuales como default de desarrollo. `ALLOWED_HOSTS` en producción debe
      incluir el dominio de Render (`.onrender.com` — Django soporta wildcards con punto
      inicial).
- [ ] **`DATABASES` desde `DATABASE_URL`** cuando esa variable exista (usar
      `dj-database-url`), y mantener el diccionario hardcodeado actual como fallback si
      no existe — así el flujo de desarrollo local con Postgres no cambia.
- [ ] **Media en Supabase Storage en vez de disco local.** Render no ofrece disco
      persistente en los planes gratuitos/estándar (el filesystem se reinicia en cada
      deploy y cada vez que el servicio se "duerme" y despierta), así que las fotos de
      `SolicitudRetiro` se perderían. Usar `django-storages` con el backend S3
      (`storages.backends.s3.S3Storage`) apuntando al endpoint S3-compatible de Supabase
      Storage, condicionado a que las variables `SUPABASE_S3_*` existan; si no existen,
      cae al `MEDIA_ROOT` local de siempre.
- [ ] **Servir estáticos con WhiteNoise.** Con `DEBUG=False`, Django deja de servir
      `/static/` (CSS del admin). Agregar `whitenoise.middleware.WhiteNoiseMiddleware`
      justo después de `SecurityMiddleware`, y `STATIC_ROOT`.
- [ ] **`CORS_ALLOW_ALL_ORIGINS = DEBUG` ya está bien así** — la app Flutter en
      producción no es un origen de navegador (mobile), así que no necesita CORS. Dejarlo
      como está; sólo revisar si en algún momento se sirve una versión web de Flutter.

Dependencias nuevas en `backend/requirements.txt`:

```text
gunicorn>=22.0
dj-database-url>=2.2
whitenoise>=6.7
django-storages[s3]>=1.14
```

Comandos que Render va a ejecutar (ver Fase 2):

```bash
# build
pip install -r requirements.txt
python manage.py collectstatic --noinput
python manage.py migrate

# start
gunicorn config.wsgi:application --bind 0.0.0.0:$PORT
```

> Nota: correr `migrate` en el build command es cómodo para este proyecto (un solo
> servicio, sin múltiples instancias desplegando a la vez). Si eso llegara a ser un
> problema, migrar manualmente desde el Shell de Render en su lugar.

---

## Fase 1 — Supabase (base de datos + storage)

1. **Crear el proyecto** en [supabase.com](https://supabase.com) (o vía MCP). Elegí una
   región cercana a la región de Render que vayas a usar en la Fase 2, para minimizar
   latencia entre backend y base de datos.
2. **Obtener el connection string:** *Project Settings → Database → Connection string*.
   Usar el modo **Transaction pooler** (puerto `6543`), no la conexión directa —
   funciona mejor con los workers de `gunicorn`. Ese string es tu `DATABASE_URL`.
3. **Bucket de Storage para media** (fotos de `SolicitudRetiro`):
   - *Storage → New bucket* → nombre `media`, público (las fotos se muestran en la app
     sin necesitar auth extra, igual que hoy vía `MEDIA_URL`).
   - *Storage → Settings → S3 Access Keys* → generar credenciales S3. De ahí salen:
     endpoint, `access key id`, `secret access key`, y el nombre del bucket — son las
     variables `SUPABASE_S3_*` que preparaste en la Fase 0.
4. **Bucket para publicar el APK** (Fase 4): otro bucket público, por ejemplo
   `app-releases`.
5. **Migrar el esquema:** con `DATABASE_URL` apuntando a Supabase (localmente o desde el
   Shell de Render una vez desplegado), correr `python manage.py migrate`. Opcionalmente
   `seed_picker_demo` / `seed_gamificacion_demo` para tener datos de demo en producción.

Al terminar esta fase tenés: `DATABASE_URL`, y las 4 variables `SUPABASE_S3_*`.

---

## Fase 2 — Backend en Render

1. **Repo en GitHub** — Render despliega desde un repo conectado; el código con los
   cambios de la Fase 0 debe estar pusheado.
2. **New → Web Service**, conectar el repo. Como es un monorepo:
   - **Root Directory:** `backend`
   - **Runtime:** Python 3
   - **Build Command:**
     `pip install -r requirements.txt && python manage.py collectstatic --noinput && python manage.py migrate`
   - **Start Command:** `gunicorn config.wsgi:application --bind 0.0.0.0:$PORT`
3. **Variables de entorno** (Render → Environment):

   | Variable | Valor |
   | --- | --- |
   | `SECRET_KEY` | una clave nueva generada para producción (no la de dev) |
   | `DEBUG` | `False` |
   | `ALLOWED_HOSTS` | `tu-servicio.onrender.com` |
   | `DATABASE_URL` | connection string del pooler de Supabase (Fase 1.2) |
   | `SUPABASE_S3_ENDPOINT` | endpoint S3 del bucket `media` (Fase 1.3) |
   | `SUPABASE_S3_ACCESS_KEY_ID` | access key del bucket `media` |
   | `SUPABASE_S3_SECRET_ACCESS_KEY` | secret key del bucket `media` |
   | `SUPABASE_S3_BUCKET` | `media` |
   | `RESEND_API_KEY` | key de Resend (recuperación de contraseña por email) |
   | `DEFAULT_FROM_EMAIL` | `EcoRecicla <no-reply@tu-dominio>` |

   Sin `RESEND_API_KEY`, el backend cae al backend de consola de email (los OTP se
   "envían" a los logs de Render en vez de a un correo real) — poné la key si querés que
   la recuperación de contraseña funcione de verdad en producción.
4. **Deploy.** Render construye la imagen, corre el build command (incluye `migrate`) y
   arranca `gunicorn`.
5. **Crear un superusuario** desde el Shell de Render:
   `python manage.py createsuperuser`.
6. **Verificar:** `https://tu-servicio.onrender.com/api/auth/login/` debe responder (405
   a un GET está bien, confirma que el servicio está vivo).

> Render free tier no tiene disco persistente y el servicio "duerme" tras ~15 min sin
> tráfico (el primer request después de eso tarda ~30-50s en responder mientras
> arranca). Es aceptable para un demo/tesis; si en algún momento se necesita disponibilidad
> constante, pasar a un plan pago de Render.

---

## Fase 3 — Apuntar Flutter al backend real

1. En [`frontend/lib/services/api_client.dart`](frontend/lib/services/api_client.dart),
   cambiar `backendBaseUrl` de la IP local/`10.0.2.2` a
   `https://tu-servicio.onrender.com`.
2. Verificar que todo siga en verde antes de generar el build de release:

   ```bash
   cd frontend
   flutter analyze
   flutter test
   ```

---

## Fase 4 — Publicar la app móvil (sin Play Store)

La forma más simple de distribuir un APK sin pasar por Play Store es alojarlo como un
archivo descargable — no requiere cuenta de desarrollador ni proceso de revisión. Como
ya tenés Supabase para la base de datos, reutilizamos el mismo proyecto para esto.

1. **Generar el APK de release:**

   ```bash
   cd frontend
   flutter build apk --release
   ```

   El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`.
2. **Subirlo al bucket `app-releases`** de Supabase Storage (dashboard → Storage → subir
   archivo, o vía MCP). Al ser un bucket público, Supabase te da una URL pública directa
   al `.apk`.
3. **Compartir el link de descarga** (el mismo link sirve para actualizaciones: subís un
   nuevo APK con el mismo nombre y el link no cambia).
4. **Instalación en Android:** el usuario abre el link desde el celular, descarga el
   `.apk`, y Android le va a pedir habilitar "Instalar apps de orígenes desconocidos"
   para esa descarga la primera vez — es esperable al no venir de Play Store, no es un
   error.
5. **Si más adelante hace falta algo más (opcional, no cubierto en este plan):**
   [Firebase App Distribution](https://firebase.google.com/docs/app-distribution) da
   testers invitados por email, notificación de nuevas versiones y sin exponer un link
   público — es la alternativa estándar cuando "un link a un archivo" se queda corto,
   pero agrega un proyecto de Firebase a configurar.
6. **iOS queda fuera de alcance** de este plan: sideload sin Play Store en Android es
   directo, pero el equivalente en iOS (TestFlight) requiere cuenta de Apple Developer
   Program de pago — no es "más simple", así que no se cubre acá salvo que lo pidas
   explícitamente.

---

## Fase 5 — Checklist final de verificación end-to-end

- [ ] `flutter analyze` y `flutter test` en verde antes del build de release.
- [ ] Backend responde en `https://tu-servicio.onrender.com`.
- [ ] Login (`/api/auth/login/`) funciona con un usuario creado en la Supabase de
      producción.
- [ ] Publicar una solicitud con foto desde la app instalada — la foto se ve (confirma
      que Supabase Storage para media quedó bien conectado, no sólo la DB).
- [ ] Flujo recolector: `cercanas`, `aceptar`, `completar` funcionan contra el backend
      desplegado.
- [ ] EcoPuntos se acreditan tras `completar` (vía `EventoPendiente`, se ve el modal al
      volver a abrir la app del lado del ciudadano).
- [ ] Recuperación de contraseña: llega el email real (si configuraste
      `RESEND_API_KEY`) o aparece en los logs de Render (si no).
- [ ] El APK descargado desde el link de Supabase instala y abre bien en un dispositivo
      que no participó del desarrollo.

---

## Pendientes / fuera de alcance de este plan

- **`cerrar_semana_racha` no corre solo en producción.** Es un management command
  pensado para un cron semanal; Render Cron Jobs (o un GitHub Action programado que
  pegue contra un endpoint protegido) son las opciones típicas, pero no está definido
  todavía qué mecanismo usar — resolverlo aparte cuando la racha en producción importe.
- **Dominio propio** para el backend y `DEFAULT_FROM_EMAIL`: opcional, Render da un
  subdominio `.onrender.com` gratis que alcanza para este plan.
- **Monitoreo/logs:** Render tiene logs básicos incluidos; no se cubre nada adicional
  (Sentry, etc.) acá.
