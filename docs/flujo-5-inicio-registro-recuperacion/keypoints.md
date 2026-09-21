# Flujo 5 — Recuperación de Contraseña: Keypoints de la implementación

Este documento resume **cómo correr y verificar** lo que ya se implementó siguiendo `recovery_password_implementation_plan.md`, y señala los puntos donde la implementación real se desvió del plan (con la razón). No repite el plan — para el diseño de endpoints/pantallas, ver ese documento.

Estado: **backend y frontend implementados, probados y verificados end-to-end contra PostgreSQL real**. `flutter analyze` en cero, `python manage.py test` en verde en ambos settings.

---

## 1. Cómo correr esto

### Backend

```bash
cd backend
source venv/bin/activate
python manage.py migrate          # ya se aplicó roles.0001_initial (CodigoRecuperacion)
python manage.py runserver 0.0.0.0:8000
```

No hace falta configurar ningún proveedor de email para probar en desarrollo: `EMAIL_BACKEND` apunta a la consola (`config/settings.py`), así que **el código OTP se imprime directamente en la terminal donde corre `runserver`**, como cualquier otro `send_mail`. Búscalo por la línea `Tu código de verificación es: NNNNNN`.

### Frontend

Sin cambios de setup — mismo `flutter run` de siempre. El link "¿Olvidaste tu contraseña?" ya está en `LoginScreen`, debajo del campo de contraseña.

### Probar el flujo manualmente (sin la app, por curl)

Útil para verificar el backend de forma aislada:

```bash
curl -X POST http://localhost:8000/api/roles/recuperacion/solicitar/ \
  -H "Content-Type: application/json" -d '{"identificador":"ciudadano_demo"}'
# Lee el código de 6 dígitos de la consola de runserver

curl -X POST http://localhost:8000/api/roles/recuperacion/verificar/ \
  -H "Content-Type: application/json" -d '{"identificador":"ciudadano_demo","codigo":"XXXXXX"}'
# -> {"token": "..."}

curl -X POST http://localhost:8000/api/roles/recuperacion/restablecer/ \
  -H "Content-Type: application/json" -d '{"token":"...","nueva_password":"nuevaClave123"}'
# -> {"mensaje": "Contraseña actualizada."}
```

Este flujo completo (solicitar → verificar → restablecer → login con la nueva contraseña → reintento del mismo token rechazado) se ejecutó contra la base de datos PostgreSQL real del proyecto durante la implementación y funcionó de punta a punta.

### Tests

```bash
# Backend — 18 tests nuevos en roles/tests.py, 53 en total en el proyecto
cd backend && python manage.py test roles --settings=config.settings_test
python manage.py test solicitudes roles gamificacion --settings=config.settings_test   # suite completa

# Frontend
cd frontend && flutter analyze     # 0 issues
flutter test                       # 26 tests, incluye los 2 archivos nuevos de este flujo
```

---

## 2. Decisiones tomadas al ejecutar el plan (desviaciones y por qué)

El plan (`recovery_password_implementation_plan.md`) dejaba algunas cosas como "a decidir" o como riesgo conocido. Esto es lo que se resolvió durante la implementación:

### 2.1 Tokens de diseño (sección 3.1 del plan) — resuelto sin agregar tokens nuevos

El plan pedía confirmar si reusar `app_theme.dart` o agregar tokens nuevos para igualar los `#F5F5F5`/`#1B4332` de Figma. Al revisar `app_theme.dart` apareció que **`EcoColors.leafDark` ya es `#1B4332`** — coincide exacto con el verde usado en las 5 pantallas de Figma, no hacía falta ninguna decisión. El resto de mapeos usados:

| Figma | Token Flutter usado |
|---|---|
| Verde `#1B4332` (bordes, botón, ícono) | `EcoColors.leafDark` (exacto) |
| Fondo `#F5F5F5` | `EcoColors.surface` (`#F8F9FA`, ya es el fondo por defecto del `Scaffold`) |
| Círculo mint `#C8EBD2` | `EcoColors.mintLight` (`#D8F3DC`, ya usado en el resto de la app) |
| Rojo de error | `EcoColors.dangerRed` |
| Texto gris secundario | `EcoColors.onSurfaceVariant` |

No se tocó `app_theme.dart`.

### 2.2 Reuso de token de reseteo (riesgo señalado en sección 5 del plan) — se corrigió, no se dejó pendiente

El plan documentaba como riesgo conocido que `restablecer_password` no invalidaba el *token* en sí (solo el código OTP), permitiendo cambiar la contraseña dos veces con el mismo token. Al escribir el test que lo cubre (`test_reusar_el_mismo_token_dos_veces_falla_la_segunda`) confirmé el bug en la práctica, así que apliqué la mitigación que el propio plan proponía: se agregó `CodigoRecuperacion.token_consumido` (`roles/models.py`), y `restablecer_password` ahora lo verifica y marca antes de cambiar la contraseña. Verificado también end-to-end por curl (segundo intento con el mismo token → `400`).

### 2.3 `OtpInput`: se quitó el salto de foco hacia atrás con Backspace

El diseño original del widget usaba `KeyboardListener` compartiendo el mismo `FocusNode` que el `TextField` de cada casilla, para detectar "Backspace en casilla vacía → volver a la anterior". Esto **rompe el árbol de foco de Flutter** (`FocusNode._reparent`: *"Tried to make a child into a parent of itself"*), reproducible incluso en el primer build. Se simplificó el widget: quedó el avance automático de foco al escribir un dígito y la distribución de un código pegado completo (los dos requisitos reales del design prompt), pero **ya no salta automáticamente a la casilla anterior al borrar en una vacía** — el usuario puede tocar la casilla anterior manualmente para corregirla, que es el comportamiento de fallback normal en la mayoría de UIs de OTP.

### 2.4 Número de WhatsApp de soporte (Screen 3B) — placeholder explícito

No existe ningún número de soporte configurado en el proyecto (el `WhatsAppService` existente siempre usa el teléfono del ciudadano de una solicitud puntual, no un número de soporte general). `contingencia_screen.dart` usa un número placeholder con un comentario `// TODO(soporte): reemplazar por el número real de soporte de EcoRecicla antes de salir a producción`. **Hay que reemplazarlo antes de shippear esta pantalla.**

### 2.5 Tests de `RecuperacionService` (Flutter) — omitidos a propósito

El plan proponía mockear `ApiClient` para testear `RecuperacionService` directamente. En la práctica, `ApiClient` es un singleton (`ApiClient.instance`) sin ningún mecanismo de inyección de dependencias ni mocks en el resto del proyecto — no hay un solo test de servicio hoy en `test/`. Meter un mock nuevo solo para este flujo habría sido una convención aislada, no un patrón reusable. En su lugar, se reforzaron los **widget tests** (que sí siguen el patrón ya establecido en `test/widgets/picker_widgets_test.dart`): `OtpInput` (3 tests) y `NuevaPasswordScreen` (4 tests, cubren exactamente las reglas de habilitación del botón que antes iban a estar en el test de servicio).

### 2.6 Test de throttling (backend) — `override_settings` no sirve para DRF

El plan sugería `override_settings(REST_FRAMEWORK=...)` para bajar la tasa de throttling en el test. Esto **no funciona**: `SimpleRateThrottle.THROTTLE_RATES` (clase base de `ScopedRateThrottle`) se congela como atributo de clase al importar `rest_framework.throttling`, y no se refresca con la señal `setting_changed` de Django. El test terminado usa `unittest.mock.patch.object(ScopedRateThrottle, 'THROTTLE_RATES', {...})` en su lugar, que sí funciona porque parchea el atributo real que el throttle consulta en tiempo de ejecución.

---

## 3. Qué falta antes de producción

Esto **no** es trabajo pendiente de este flujo en sí — son puntos que el plan ya marcaba como fuera de alcance de la implementación técnica, y siguen igual:

- **Proveedor de email real** (SendGrid/SES/SMTP propio): hoy `EMAIL_BACKEND` es la consola de Django. Cambiarlo es una sola línea en `config/settings.py` una vez elegido el proveedor.
- **Número de WhatsApp de soporte real** en `contingencia_screen.dart` (ver 2.4).
- **Unicidad de `email` a nivel de base de datos**: sigue validada solo en el serializer (`RegistroUsuarioSerializer.validate_email`), no con una constraint SQL, porque el proyecto usa el `User` nativo de Django. Cerrar esto del todo requeriría un `AUTH_USER_MODEL` propio — no se hizo, sigue siendo el mismo riesgo conocido que documentaba el plan.
- **Tasas de throttling** (`5/hour` solicitar, `20/hour` verificar en `config/settings.py`) siguen siendo un punto de partida, sin validar con uso real.

## 4. Archivos tocados

**Backend** (`backend/roles/` salvo que se indique): `serializers.py` (email requerido/único + 3 serializers nuevos), `models.py` (`CodigoRecuperacion`), `services.py` (nuevo), `views.py` (+3 vistas), `urls.py`, `admin.py`, `tests.py` (+18 tests), `migrations/0001_initial.py` (nuevo, ya aplicada); `config/settings.py` (email, throttling).

**Frontend** (`frontend/lib/`): `services/recuperacion_service.dart` (nuevo), `widgets/otp_input.dart` (nuevo), `screens/recuperacion/` (5 pantallas nuevas), `screens/auth/login_screen.dart` (link agregado). Tests: `test/widgets/otp_input_test.dart`, `test/screens/nueva_password_screen_test.dart` (nuevos).
