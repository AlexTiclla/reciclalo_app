# Plan de Implementación — Flujo 5: Recuperación de Contraseña (OTP por correo)

Implementación end-to-end (backend Django + frontend Flutter) de la recuperación de contraseña vía código OTP enviado por correo, para **ambos roles** (Ciudadano y Recolector). Este documento asume que ya se leyó:

- `recovery_password_design_prompt.md` (prompt de diseño: 5 pantallas, reglas de UX — no enumeración de usuarios, rate limiting, token de sesión entre verificación y cambio de contraseña).
- Las 5 pantallas ya generadas en Figma (archivo `Juan`, `fileKey=vusjYMtSBDffcp66MpuBwC`), que este plan mapea 1:1 a pantallas Flutter:

| # | Pantalla | Nodo Figma |
|---|---|---|
| 1 | Solicitar Código | [119:139](https://www.figma.com/design/vusjYMtSBDffcp66MpuBwC/Juan?node-id=119-139&m=dev) |
| 2 | Verificar Código (OTP) | [119:159](https://www.figma.com/design/vusjYMtSBDffcp66MpuBwC/Juan?node-id=119-159&m=dev) |
| 3A | Nueva Contraseña | [120:139](https://www.figma.com/design/vusjYMtSBDffcp66MpuBwC/Juan?node-id=120-139&m=dev) |
| 3B | Contingencia (WhatsApp) | [121:139](https://www.figma.com/design/vusjYMtSBDffcp66MpuBwC/Juan?node-id=121-139&m=dev) |
| 4 | Confirmación de Éxito | [118:139](https://www.figma.com/design/vusjYMtSBDffcp66MpuBwC/Juan?node-id=118-139&m=dev) |

Las 5 pantallas reutilizan tokens ya presentes en el archivo de Figma (fondo `#F5F5F5`, verde marca `#1B4332`, tipografía Inter) en vez de los definidos originalmente en `frontend/lib/theme/app_theme.dart` (`EcoColors.primary = #0F5238`, fondo `EcoColors.surface = #F8F9FA`) — ver sección 3.1 sobre cómo resolver esa diferencia de tokens antes de construir los widgets.

---

## 1. Resumen y alcance

### Alcance de esta fase

- Link "¿Olvidaste tu contraseña?" en `LoginScreen`, que abre el flujo de recuperación.
- Solicitud de código OTP de 6 dígitos enviado por correo al usuario (Paso 1).
- Verificación del código con expiración (10 min) y reenvío con cooldown (30 s) (Paso 2).
- Cambio de contraseña autorizado únicamente tras verificar el código (Paso 3A).
- Contingencia por WhatsApp para quien no tiene acceso a su correo (Paso 3B), reutilizando el mecanismo de deep link ya usado en el flujo del recolector.
- Pantalla de confirmación de éxito (Paso 4).
- Endurecer el campo `email` del registro (`RegistroUsuarioSerializer`) a requerido y único — prerrequisito señalado en el design prompt para que el Paso 1 nunca caiga en "no tengo correo registrado".

### Fuera de alcance (ver `recovery_password_design_prompt.md`)

- Proveedor de email transaccional real en producción (SendGrid/SES/SMTP con dominio propio) — en esta fase se implementa con el backend de consola de Django (dev) y se deja el punto de extensión documentado.
- 2FA / OTP también para el login normal (mencionado como *Future Enhancement* en el design prompt).
- Notificación de seguridad al correo cuando la contraseña cambia exitosamente.
- Verificación de correo obligatoria en el registro (confirmar email antes de poder usarlo).

### Supuestos de diseño que fija este plan

1. **Dónde vive el código**: se extiende la app `roles` (no se crea una app nueva). Recuperación de contraseña es parte del mismo dominio de autenticación que ya cubre `roles` (`registro/`, y — vía `config/urls.py` — `login/`/`me/`), a diferencia de `gamificacion`, que sí es un dominio de negocio separado. Si este flujo creciera mucho (2FA, verificación de email, etc.) valdría la pena separarlo; por ahora no se justifica una app nueva.
2. **Modelo de usuario**: el proyecto usa el `User` nativo de Django (`django.contrib.auth.models.User`), sin `AUTH_USER_MODEL` propio. Su campo `email` no tiene restricción de unicidad a nivel de base de datos — no se puede agregar `unique=True` sin migrar a un modelo de usuario propio, fuera de alcance de este plan. La unicidad se valida a nivel de aplicación (en el serializer de registro) y el flujo de recuperación asume que, en la práctica, el proyecto no tiene emails duplicados porque el registro los rechaza desde que se aplique este cambio; si un email quedó duplicado por datos previos a este cambio, el sistema usará el primer `User` que matchee (documentar como riesgo conocido, no bloqueante).
3. **Código de un solo uso, no enumeración**: el endpoint de solicitud (`Paso 1`) siempre responde `200` con el mismo mensaje, exista o no la cuenta/el correo. Si no existe, simplemente no se envía email ni se crea código.
4. **Token intermedio entre verificación y cambio de contraseña**: verificar el código no cambia la contraseña directamente — emite un token de corta duración (firmado con `django.core.signing`, sin dependencias nuevas) que el Paso 3A debe enviar para poder cambiar la contraseña. Esto evita que alguien salte directo al endpoint de cambio de contraseña sin haber verificado el código.
5. **Rate limiting sin dependencias nuevas**: se usa el sistema de *throttling* nativo de Django REST Framework (`AnonRateThrottle`/scoped throttle), no una librería externa. Cubre tanto el envío (Paso 1) como el reenvío/verificación (Paso 2).
6. **Envío de email**: el bloque `MAILERS` actual en `config/settings.py` (líneas ~164-171) no es una setting real de Django — no tiene efecto. Este plan lo reemplaza por `EMAIL_BACKEND` real, apuntando a la consola en desarrollo (`django.core.mail.backends.console.EmailBackend`, imprime el email en la terminal del `runserver`, útil para probar sin proveedor real) y deja documentado dónde apuntar un backend SMTP/SES/SendGrid real en producción.

---

## 2. Backend (Django)

### 2.1 Endurecer el campo `email` en el registro

`roles/serializers.py` — `RegistroUsuarioSerializer` pasa `email` de campo implícito (heredado del `ModelSerializer`, opcional) a explícito, requerido y validado como único:

```python
class RegistroUsuarioSerializer(serializers.ModelSerializer):
    rol = serializers.ChoiceField(choices=['Ciudadano', 'Recolector'], write_only=True, required=True)
    password = serializers.CharField(write_only=True, min_length=6)
    email = serializers.EmailField(required=True)

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'first_name', 'last_name', 'rol']

    def validate_email(self, value):
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError('Ya existe una cuenta con este correo.')
        return value

    def create(self, validated_data):
        ...  # sin cambios
```

Esto es el prerrequisito señalado en el design prompt — sin él, Screen 1 del flujo de recuperación podría no tener a dónde enviar el código para cuentas nuevas.

### 2.2 Configuración de email (`config/settings.py`)

Reemplazar el bloque `MAILERS` (no es una setting real) por settings estándar de Django:

```python
# Desarrollo: imprime el email en la consola de `runserver` en vez de enviarlo.
# Producción: apuntar EMAIL_BACKEND a smtp.EmailBackend (o el backend del
# proveedor elegido, ej. django-anymail para SendGrid/SES) y completar
# EMAIL_HOST/EMAIL_HOST_USER/EMAIL_HOST_PASSWORD/EMAIL_USE_TLS vía variables
# de entorno — el proyecto hoy no usa python-decouple/django-environ, así
# que por ahora estos valores quedan hardcodeados igual que el resto de
# settings.py (SECRET_KEY, DATABASES), y se documentan aquí como el punto
# a externalizar antes de salir a producción.
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
DEFAULT_FROM_EMAIL = 'EcoRecicla <no-reply@ecorecicla.local>'

# Ventana de expiración y reenvío del código OTP de recuperación.
RECUPERACION_OTP_EXPIRA_MINUTOS = 10
RECUPERACION_OTP_REENVIO_COOLDOWN_SEGUNDOS = 30
RECUPERACION_OTP_MAX_INTENTOS = 5
```

### 2.3 Throttling (`config/settings.py`)

Agregar scopes de throttling dedicados, reusando el framework nativo de DRF (`REST_FRAMEWORK` ya existe en `config/settings.py`):

```python
REST_FRAMEWORK = {
    ...
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.ScopedRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'recuperacion-solicitar': '5/hour',
        'recuperacion-verificar': '20/hour',
    },
}
```

Estas tasas son un punto de partida razonable para v1 (5 solicitudes de código por hora por IP, 20 intentos de verificación) — ajustar con datos reales de uso.

### 2.4 Modelo (`roles/models.py`)

```python
import secrets
from django.conf import settings
from django.db import models
from django.utils import timezone


class CodigoRecuperacion(models.Model):
    """Código OTP de un solo uso para recuperación de contraseña por correo."""
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='codigos_recuperacion'
    )
    codigo_hash = models.CharField(max_length=128)  # hash del código de 6 dígitos, nunca texto plano
    creado_en = models.DateTimeField(auto_now_add=True)
    expira_en = models.DateTimeField()
    intentos_fallidos = models.PositiveSmallIntegerField(default=0)
    usado_en = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-creado_en']

    @property
    def expirado(self):
        return timezone.now() >= self.expira_en

    @property
    def bloqueado(self):
        from django.conf import settings as s
        return self.intentos_fallidos >= s.RECUPERACION_OTP_MAX_INTENTOS

    @property
    def vigente(self):
        return self.usado_en is None and not self.expirado and not self.bloqueado
```

`codigo_hash` usa `django.contrib.auth.hashers.make_password`/`check_password` — mismo mecanismo que ya hashea contraseñas, sin dependencias nuevas. El código en texto plano (los 6 dígitos que ve el usuario) solo existe en memoria al generarlo y en el cuerpo del email; nunca se persiste.

### 2.5 Servicios (`roles/services.py`, nuevo)

```python
import secrets
from django.conf import settings
from django.contrib.auth.hashers import check_password, make_password
from django.contrib.auth.models import User
from django.core import signing
from django.core.mail import send_mail
from django.utils import timezone

from .models import CodigoRecuperacion

TOKEN_SALT = 'roles.recuperacion-password'
TOKEN_MAX_EDAD_SEGUNDOS = 10 * 60  # vigencia del token intermedio Paso 2 -> Paso 3A


def solicitar_codigo(identificador: str) -> None:
    """No revela si el usuario/correo existe: siempre retorna sin error."""
    usuario = _buscar_usuario(identificador)
    if usuario is None or not usuario.email:
        return
    codigo = f'{secrets.randbelow(1_000_000):06d}'
    CodigoRecuperacion.objects.create(
        usuario=usuario,
        codigo_hash=make_password(codigo),
        expira_en=timezone.now() + timezone.timedelta(minutes=settings.RECUPERACION_OTP_EXPIRA_MINUTOS),
    )
    send_mail(
        subject='Tu código de recuperación de EcoRecicla',
        message=f'Tu código es: {codigo}\nVence en {settings.RECUPERACION_OTP_EXPIRA_MINUTOS} minutos.',
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[usuario.email],
    )


def verificar_codigo(identificador: str, codigo: str) -> str | None:
    """Retorna un token de reseteo firmado si el código es válido; None si no."""
    usuario = _buscar_usuario(identificador)
    if usuario is None:
        return None
    intento = CodigoRecuperacion.objects.filter(usuario=usuario, usado_en__isnull=True).order_by('-creado_en').first()
    if intento is None or not intento.vigente:
        return None
    if not check_password(codigo, intento.codigo_hash):
        intento.intentos_fallidos += 1
        intento.save(update_fields=['intentos_fallidos'])
        return None
    intento.usado_en = timezone.now()
    intento.save(update_fields=['usado_en'])
    return signing.dumps({'usuario_id': usuario.id, 'codigo_id': intento.id}, salt=TOKEN_SALT)


def restablecer_password(token: str, nueva_password: str) -> bool:
    try:
        datos = signing.loads(token, salt=TOKEN_SALT, max_age=TOKEN_MAX_EDAD_SEGUNDOS)
    except signing.BadSignature:
        return False
    try:
        usuario = User.objects.get(pk=datos['usuario_id'])
    except User.DoesNotExist:
        return False
    # El código referenciado debe seguir marcado como usado por ESTE flujo
    # (evita reusar un token viejo si el usuario pidió un código nuevo después).
    if not CodigoRecuperacion.objects.filter(pk=datos['codigo_id'], usuario=usuario, usado_en__isnull=False).exists():
        return False
    usuario.set_password(nueva_password)
    usuario.save(update_fields=['password'])
    return True


def _buscar_usuario(identificador: str) -> User | None:
    return User.objects.filter(username__iexact=identificador).first() \
        or User.objects.filter(email__iexact=identificador).first()
```

### 2.6 Serializers (`roles/serializers.py`)

```python
class SolicitarCodigoSerializer(serializers.Serializer):
    identificador = serializers.CharField()  # usuario o correo


class VerificarCodigoSerializer(serializers.Serializer):
    identificador = serializers.CharField()
    codigo = serializers.RegexField(r'^\d{6}$')


class RestablecerPasswordSerializer(serializers.Serializer):
    token = serializers.CharField()
    nueva_password = serializers.CharField(min_length=8)
```

### 2.7 Vistas (`roles/views.py`)

```python
from rest_framework.throttling import ScopedRateThrottle

class SolicitarCodigoView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'recuperacion-solicitar'

    def post(self, request):
        serializer = SolicitarCodigoSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        solicitar_codigo(serializer.validated_data['identificador'])
        return Response({'mensaje': 'Si el usuario existe, enviamos un código a su correo.'})


class VerificarCodigoView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'recuperacion-verificar'

    def post(self, request):
        serializer = VerificarCodigoSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        token = verificar_codigo(**serializer.validated_data)
        if token is None:
            return Response({'error': 'Código incorrecto o expirado.'}, status=400)
        return Response({'token': token})


class RestablecerPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RestablecerPasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        ok = restablecer_password(**serializer.validated_data)
        if not ok:
            return Response({'error': 'Token inválido o expirado. Vuelve a solicitar un código.'}, status=400)
        return Response({'mensaje': 'Contraseña actualizada.'})
```

`VerificarCodigoView` responde siempre `400` genérico ante código incorrecto **o** expirado **o** bloqueado por intentos — mismo principio de no dar pistas de más que ya aplica en Screen 1 (ver design prompt).

### 2.8 URLs (`roles/urls.py`)

```python
urlpatterns = [
    path('registro/', RegistroView.as_view(), name='registro-usuario'),
    path('recuperacion/solicitar/', SolicitarCodigoView.as_view(), name='recuperacion-solicitar'),
    path('recuperacion/verificar/', VerificarCodigoView.as_view(), name='recuperacion-verificar'),
    path('recuperacion/restablecer/', RestablecerPasswordView.as_view(), name='recuperacion-restablecer'),
    path('', include(router.urls)),
]
```

Quedan montadas, vía `config/urls.py:31`, en:

```
POST /api/roles/recuperacion/solicitar/
POST /api/roles/recuperacion/verificar/
POST /api/roles/recuperacion/restablecer/
```

### 2.9 Admin (`roles/admin.py`)

Registrar `CodigoRecuperacion` como solo-lectura (`intentos_fallidos`, `usado_en`, `expira_en` visibles; sin `codigo_hash` en el listado) — mismo criterio que `TransaccionEcoPuntos` en `gamificacion/admin.py`: sirve para depurar/soporte, no se edita a mano.

### 2.10 Migraciones

```bash
python manage.py makemigrations roles
python manage.py migrate
```

### 2.11 Tests (`roles/tests.py`, correr con `--settings=config.settings_test`)

- `RegistroUsuarioSerializer` rechaza un segundo registro con el mismo email (case-insensitive).
- `solicitar_codigo`: usuario inexistente no crea `CodigoRecuperacion` ni intenta enviar email (usar `django.core.mail.outbox` en `django.test.TestCase` con `EMAIL_BACKEND` de test, o mockear `send_mail`); usuario válido sí, y el código nunca queda en texto plano en el modelo.
- `verificar_codigo`: código correcto y vigente retorna un token válido y marca `usado_en`; código incorrecto incrementa `intentos_fallidos` y no retorna token; código tras `RECUPERACION_OTP_MAX_INTENTOS` intentos fallidos queda bloqueado aunque el código correcto se ingrese después; código expirado (`expira_en` en el pasado) falla aunque sea el correcto.
- `restablecer_password`: token válido cambia la contraseña (verificar con `usuario.check_password`); token corrupto/con salt equivocado falla; token vencido (`max_age`) falla; reusar el mismo token dos veces falla la segunda vez (porque exige que exista un `CodigoRecuperacion.usado_en` para ese `codigo_id`, pero no invalida el token en sí — ver nota de riesgo en sección 5 sobre reemplazar esto por un flag `token_consumido` si se detecta reuso en pruebas).
- Endpoints (`APITestCase`): `SolicitarCodigoView` responde `200` igual exista o no el usuario (no debe poder distinguirse por status code ni por tiempo de respuesta de forma trivial); `VerificarCodigoView`/`RestablecerPasswordView` con throttling simulando exceso de intentos (usar `override_settings` para bajar las tasas en el test y no esperar una hora real).

---

## 3. Frontend (Flutter)

### 3.1 Resolución de tokens de diseño

Las 5 pantallas en Figma usan un fondo `#F5F5F5` y un verde `#1B4332`/inputs con borde 1.5px que **no coinciden exactamente** con `EcoColors.surface` (`#F8F9FA`) ni `EcoColors.primary` (`#0F5238`) de `app_theme.dart`. Siguiendo la regla del `CLAUDE.md` de `figma-sync` ("si un valor de Figma no matchea limpio con un token existente, avisar en vez de inventar uno nuevo o forzarlo al más cercano"): antes de construir los widgets, decidir con el usuario una de estas dos opciones —

1. **Usar los tokens existentes de `app_theme.dart`** (`EcoColors.primary`, `EcoColors.surface`, `EcoColors.outlineVariant` para bordes) y aceptar que el Flutter resultante se vea ligeramente distinto al mockup de Figma pero 100% consistente con el resto de la app ya implementada (Login, Registro, flujo de recolector).
2. **Agregar los valores exactos de Figma como tokens nuevos** (ej. `EcoColors.surfaceAlt = #F5F5F5`) si el equipo de diseño confirma que este flujo introduce una paleta ligeramente distinta a propósito.

Este plan asume la **opción 1** (reusar tokens existentes) por default, ya que ninguna otra pantalla implementada en Flutter usa `#F5F5F5`/`#1B4332` — son valores que aparecieron en iteraciones más nuevas del archivo de Figma pero nunca se sincronizaron de vuelta a `app_theme.dart`. Si se prefiere la opción 2, confirmar antes de escribir los widgets.

### 3.2 Modelos nuevos (`lib/models/`)

No se requiere un modelo de datos persistente nuevo — las 3 llamadas del flujo son *fire-and-forget* con respuestas simples (`{mensaje}`, `{token}`, `{error}`). Se maneja como valores primitivos/`Map` en el servicio, sin agregar `lib/models/*.dart` nuevos.

### 3.3 Servicio (`lib/services/recuperacion_service.dart`, nuevo)

Mismo estilo que `AuthService`/`GamificacionService` (usa `ApiClient.instance`, un método por endpoint):

```dart
class RecuperacionService {
  RecuperacionService(this._client);
  final ApiClient _client;

  Future<void> solicitarCodigo(String identificador) => ...
    // POST /api/roles/recuperacion/solicitar/  { identificador }

  Future<String> verificarCodigo(String identificador, String codigo) => ...
    // POST /api/roles/recuperacion/verificar/  { identificador, codigo } -> token
    // Lanza CodigoInvalidoException en 400.

  Future<void> restablecerPassword(String token, String nuevaPassword) => ...
    // POST /api/roles/recuperacion/restablecer/  { token, nueva_password }
    // Lanza TokenExpiradoException en 400.
}
```

`CodigoInvalidoException`/`TokenExpiradoException` siguen el mismo patrón que `SolicitudYaTomadaException` en `solicitudes_service.dart` (excepción específica capturable por la pantalla para mostrar el mensaje adecuado, sin exponer el texto crudo del backend).

### 3.4 Pantallas nuevas (mapeo a los 5 nodos de Figma)

Carpeta: `lib/screens/recuperacion/` (compartida por ambos roles, ya que el flujo es idéntico — sigue el mismo criterio que `screens/picker/` para lo específico de un rol, pero este flujo no lo es).

| # | Nodo Figma | Archivo Flutter | Notas de implementación |
|---|---|---|---|
| 1 | [119:139](https://www.figma.com/design/vusjYMtSBDffcp66MpuBwC/Juan?node-id=119-139&m=dev) | `recuperacion/solicitar_codigo_screen.dart` | Campo único "Usuario o correo" + botón "Enviar código". Al enviar, llama `solicitarCodigo` y navega **siempre** a la pantalla 2 (nunca muestra "usuario no encontrado" — ver design prompt, no enumeración). Ícono de sobre en círculo mint: `Icon(Icons.mail_outline)` sobre un `Container` circular con `EcoColors.mintLight`. |
| 2 | [119:159](https://www.figma.com/design/vusjYMtSBDffcp66MpuBwC/Juan?node-id=119-159&m=dev) | `recuperacion/verificar_codigo_screen.dart` | Widget nuevo `widgets/otp_input.dart` (6 casillas, avance automático, `TextInputType.number`, soporta pegar el código completo desde portapapeles — ver Accessibility Notes del design prompt). Temporizador de expiración (`Timer.periodic`, 10 min) y de reenvío (30 s) como estado local del `StatefulWidget`, no en el backend. Botón "Verificar" deshabilitado hasta llenar las 6 casillas. Al verificar OK, navega a la pantalla 3A pasando el `token` recibido. Link "¿No te llegó el código?" navega a la pantalla 3B. |
| 3A | [120:139](https://www.figma.com/design/vusjYMtSBDffcp66MpuBwC/Juan?node-id=120-139&m=dev) | `recuperacion/nueva_password_screen.dart` | Recibe el `token` de la pantalla 2 (parámetro del constructor, no se vuelve a pedir el código). Dos campos de contraseña con `EcoColors`-consistent eye-toggle (mismo patrón ya usado en `registro_screen.dart` para mostrar/ocultar). Checklist de validación en vivo (mínimo 8 caracteres, coinciden) como texto de estado, no como widget nuevo reusable. Botón "Guardar contraseña" deshabilitado hasta que ambas validaciones pasen; al confirmar, llama `restablecerPassword` y navega a la pantalla 4. |
| 3B | [121:139](https://www.figma.com/design/vusjYMtSBDffcp66MpuBwC/Juan?node-id=121-139&m=dev) | `recuperacion/contingencia_screen.dart` | Sin llamadas al backend. Botón "Contactar por WhatsApp" reusa `MapsService`/`services/maps_service.dart` (mismo mecanismo de deep link ya usado en el flujo del recolector) con el mensaje prellenado indicado en el design prompt. Link "Volver a Login" hace `Navigator.popUntil` hasta `LoginScreen`. |
| 4 | [118:139](https://www.figma.com/design/vusjYMtSBDffcp66MpuBwC/Juan?node-id=118-139&m=dev) | `recuperacion/confirmacion_screen.dart` | Pantalla estática (check verde + texto + botón). Botón "Ir a iniciar sesión" hace `Navigator.popUntil` hasta `LoginScreen` (o `pushAndRemoveUntil` si la pila de navegación del flujo se armó con `push` simple, para no dejar las 4 pantallas anteriores en el stack de vuelta). |

### 3.5 Navegación desde Login

`lib/screens/login_screen.dart` (o equivalente): agregar un `TextButton` "¿Olvidaste tu contraseña?" debajo del campo de contraseña (o junto al botón "Ingresar", según quede mejor visualmente — el node 5:14 original no lo contemplaba), que hace:

```dart
Navigator.push(context, MaterialPageRoute(builder: (_) => const SolicitarCodigoScreen()));
```

Las pantallas 1→2→3A→4 se encadenan con `Navigator.push` simple (cada una recibe de la anterior lo que necesita vía constructor: pantalla 2 no necesita nada de la 1 más que haber disparado el envío; pantalla 3A recibe el `token` de la 2). Pantalla 4 termina con `pushAndRemoveUntil(..., (route) => route.isFirst)` para volver a Login limpiando todo el flujo intermedio del stack.

### 3.6 Widget nuevo: `widgets/otp_input.dart`

Único componente genuinamente nuevo de este flujo (no existe nada parecido en el resto de la app):

```dart
class OtpInput extends StatefulWidget {
  const OtpInput({super.key, required this.length, required this.onCompleted});
  final int length; // 6
  final ValueChanged<String> onCompleted;
}
```

- Internamente: `List<TextEditingController>` + `List<FocusNode>`, uno por casilla.
- Al escribir un dígito, mueve el foco a la siguiente casilla automáticamente; al borrar en una casilla vacía, retrocede el foco.
- Escucha el portapapeles: si el usuario pega un string de 6 dígitos en la primera casilla, distribuye un dígito por casilla (soporta autofill de código copiado desde el email).
- Expone `onCompleted` cuando las 6 casillas están llenas, para habilitar el botón "Verificar" sin que la pantalla tenga que sondear el estado directamente.

### 3.7 Tests

- `test/services/recuperacion_service_test.dart`: mockea `ApiClient` (mismo patrón que los tests existentes de servicios) y verifica que `verificarCodigo`/`restablecerPassword` lanzan la excepción correcta en `400`.
- Widget test de `OtpInput`: escribir 6 dígitos dispara `onCompleted` con el string concatenado; pegar un código de 6 dígitos distribuye uno por casilla.
- Widget test de `NuevaPasswordScreen`: botón "Guardar contraseña" permanece deshabilitado si las contraseñas no coinciden o no llegan a 8 caracteres.
- `flutter analyze` en cero antes de cerrar la fase (regla del proyecto).

---

## 4. Orden de implementación sugerido

1. **Backend — email y throttling**: corregir `MAILERS` → `EMAIL_BACKEND` real (consola en dev), agregar `RECUPERACION_OTP_*` settings y `DEFAULT_THROTTLE_RATES`.
2. **Backend — endurecer registro**: `email` requerido + único en `RegistroUsuarioSerializer`. Correr los tests existentes de `roles` para confirmar que no rompe el registro actual.
3. **Backend — modelo y servicios**: `CodigoRecuperacion`, `roles/services.py` completo, migraciones.
4. **Backend — endpoints**: `SolicitarCodigoView`/`VerificarCodigoView`/`RestablecerPasswordView`, `roles/urls.py`. Probar con `curl`/DRF browsable API, revisando el email impreso en la consola de `runserver`.
5. **Backend — tests**: cubrir los casos de la sección 2.11 antes de tocar Flutter.
6. **Frontend — decisión de tokens**: resolver la sección 3.1 (reusar `app_theme.dart` o agregar tokens nuevos) antes de escribir cualquier widget.
7. **Frontend — servicio**: `RecuperacionService` + excepciones, contra el backend ya funcionando.
8. **Frontend — `OtpInput`**: construir y probar el widget de forma aislada (widget test) antes de integrarlo en la pantalla 2.
9. **Frontend — pantallas**: 1 → 2 → 3A → 3B → 4, en ese orden (cada una depende de que la anterior navegue correctamente), verificando contra las capturas de Figma referenciadas en la tabla de la sección 3.4.
10. **Frontend — enganchar a Login**: agregar el link "¿Olvidaste tu contraseña?" en `login_screen.dart`.
11. **Testing end-to-end manual**: flujo completo con `ciudadano_demo`/`recolector_demo` — pedir código, leerlo de la consola del backend (no hay proveedor real todavía), verificarlo, cambiar la contraseña, volver a iniciar sesión con la nueva.
12. **`flutter analyze` + `python manage.py test roles` (y el resto de la suite) en verde** antes de dar por cerrada la fase, según la regla del proyecto.

---

## 5. Riesgos y preguntas abiertas

- **Unicidad de `email` no forzada en base de datos**: como el proyecto usa el `User` nativo de Django, la unicidad de `email` solo se valida en el serializer de registro, no con una constraint de base de datos. Si dos usuarios ya comparten el mismo email por datos previos a este cambio, `_buscar_usuario` en `roles/services.py` tomará el primero que encuentre — riesgo conocido, aceptable para v1, pero requeriría un `AUTH_USER_MODEL` propio o una migración de datos para cerrarlo del todo.
- **Reuso de un token de reseteo ya usado**: `restablecer_password` valida que exista un `CodigoRecuperacion.usado_en` para el `codigo_id` embebido en el token, pero no marca el *token* en sí como consumido — si `restablecer_password` se llama dos veces con el mismo token válido antes de que expire (`max_age`), ambas veces tendrán éxito y sobrescribirán la contraseña. Mitigación simple si se detecta como problema real en pruebas: agregar un campo `token_consumido` a `CodigoRecuperacion` y verificarlo/setearlo dentro de `restablecer_password`.
- **Proveedor de email en producción**: este plan resuelve el envío con el backend de consola de Django (`EMAIL_BACKEND` de dev). Elegir y configurar un proveedor real (SendGrid, Amazon SES, SMTP propio) queda pendiente y no bloquea la implementación técnica del flujo — es un cambio de una sola línea (`EMAIL_BACKEND` + credenciales) una vez decidido.
- **Tasas de throttling** (`5/hour` solicitar, `20/hour` verificar) son un punto de partida — deben validarse con uso real antes de asumirlas como definitivas.
- **Diferencia de tokens visuales Figma vs. `app_theme.dart`** (sección 3.1): decisión pendiente de confirmar con el usuario antes de implementar los widgets — no se resuelve arbitrariamente en este plan.
