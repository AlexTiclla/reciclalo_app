# Plan de Implementación — Flujo 3: Fidelización y Gamificación

Implementación end-to-end (backend Django + frontend Flutter) del flujo de EcoPuntos, recompensas, huella ambiental y racha de constancia, para **ambos roles** (Ciudadano y Recolector). Este documento asume que ya se leyó:

- `flujo_de_fidelizaci_n_y_gamificaci_n.md` (especificación funcional: pasos del flujo, reglas de racha/protectores, tablas de EcoPuntos por hito).
- `flujo-3-design-prompt.md` (prompt de diseño usado para generar las pantallas en Stitch).
- Las 4 pantallas ya generadas en `stitch_ecorecicla_ciudadano/` (`acreditaci_n_ecopuntos_equilibrado`, `mi_impacto_y_racha_equilibrado`, `recompensas_y_canje_equilibrado`, `hito_de_racha_equilibrado`) — **las pantallas Flutter deben verse igual a estos `code.html`/`screen.png`**, reutilizando los tokens de `ecoharmony/DESIGN.md`, que ya coinciden con `frontend/lib/theme/app_theme.dart` (`EcoColors`/`EcoSpacing`/`EcoRadius`).

---

## 1. Resumen y alcance

### Alcance de esta fase
- Acreditación automática de EcoPuntos al ciudadano cuando su solicitud pasa a `completada` (por peso/material).
- Bono de EcoPuntos al cruzar un hito de racha (2/4/8/12/26/52 semanas), con tabla distinta para Ciudadano y Recolector.
- Racha semanal con 2 protectores por rol, recargados cada mes, consumidos automáticamente (ver especificación).
- Catálogo de recompensas y canje de EcoPuntos, compartido por ambos roles.
- Panel "Mi Impacto y Racha": huella de carbono/agua evitada + racha + protectores.
- Cambios de navegación: la pestaña "Perfil" del navbar se reemplaza por "Recompensas" en ambos roles; el perfil pasa a un ícono en la esquina superior derecha; "Mi Impacto y Racha" se abre desde el Perfil.

### Fuera de alcance (ver especificación y `flujo-3-design-prompt.md`)
- Leaderboard/ranking entre usuarios.
- Insignias coleccionables además del bono de puntos.
- Notificaciones push (el proyecto no las usa).
- Comercios aliados con backoffice propio — el catálogo de recompensas se administra desde Django admin en esta fase.

### Supuestos de diseño que fija este plan
1. **Quién gana puntos por peso**: solo el Ciudadano/Comercio (generador), porque es quien entrega material. El Recolector no gana EcoPuntos por completar retiros — su única fuente de EcoPuntos en v1 es el bono de hitos de racha. Esto es coherente con que su tabla de hitos ya es más baja (ver especificación).
2. **Cómputo de racha**: la especificación recomienda derivarla bajo demanda desde las fechas de `completada`. En la implementación real hace falta además un **estado persistido mínimo** (`ProgresoRacha`) porque dos efectos son *stateful* y deben ocurrir una sola vez: consumir un protector automáticamente al cerrar una semana vacía, y acreditar el bono de un hito exactamente una vez. Un comando semanal (`cerrar_semana_racha`) recalcula desde el historial y aplica esos efectos de forma idempotente — no se guarda la racha como "fuente de verdad" independiente del historial, se guarda el resultado de haberlo evaluado.
3. **Peso del material**: `SolicitudRetiro` no tiene hoy un campo de peso. Se agrega `peso_kg`, capturado por el Recolector al completar (Paso 1 de la especificación).
4. **Notificación de eventos (modales)**: como el ciudadano no es quien ejecuta `completar`, y el hito de racha puede cruzarse por un job en segundo plano, ambos modales (acreditación e hito) se muestran la próxima vez que el usuario abre la pantalla raíz de su rol, consultando una cola de eventos pendientes.

---

## 2. Backend (Django)

### 2.1 Nueva app `gamificacion`

Sigue la convención de `CLAUDE.md` ("Add backend functionality as dedicated Django apps rather than growing `config/`").

```bash
cd backend
python manage.py startapp gamificacion
```

Agregar a `INSTALLED_APPS` en `config/settings.py` (junto a `'solicitudes'`, `'roles'`):

```python
INSTALLED_APPS = [
    ...
    'solicitudes',
    'roles',
    'gamificacion',
]
```

### 2.2 Cambios en la app `solicitudes` (existente)

`SolicitudRetiro` necesita el peso capturado en el Paso 1 de la especificación:

```python
# solicitudes/models.py
class SolicitudRetiro(models.Model):
    ...
    peso_kg = models.DecimalField(
        max_digits=6, decimal_places=2, null=True, blank=True
    )  # Se completa recién al marcar `completar`; nulo mientras está pendiente/aceptada.
```

`completar` (en `solicitudes/views.py`) debe:
1. Aceptar `peso_kg` en el body (requerido, `Decimal > 0`; reusar el patrón de validación de `_coordenadas`).
2. Guardar `solicitud.peso_kg` junto al resto de campos ya actualizados.
3. Tras el `transaction.atomic()` existente, invocar `gamificacion.services.acreditar_por_completado(solicitud)` — mantiene `solicitudes` sin conocer el modelo de puntos, solo llama un servicio de la nueva app (evita import circular: `gamificacion` importa de `solicitudes`, no al revés).

```python
# solicitudes/views.py — completar()
peso_kg = request.data.get('peso_kg')
try:
    peso_kg = Decimal(str(peso_kg))
except (InvalidOperation, TypeError):
    return Response({'error': 'peso_kg es requerido y debe ser un número'}, status=400)
if peso_kg <= 0:
    return Response({'error': 'peso_kg debe ser mayor que 0'}, status=400)
...
solicitud.peso_kg = peso_kg
solicitud.estado = EstadoSolicitud.COMPLETADA
solicitud.save(update_fields=['estado', 'peso_kg', 'actualizado_en'])
...
# después del bloque atomic, ya con la asignación guardada:
from gamificacion.services import acreditar_por_completado
acreditar_por_completado(asignacion)
```

Este es el único punto de acoplamiento entre las dos apps; todo lo demás (racha, catálogo, canje) vive enteramente en `gamificacion`.

### 2.3 Modelos (`gamificacion/models.py`)

```python
from django.conf import settings
from django.db import models


class TipoTransaccion(models.TextChoices):
    ACREDITACION = 'acreditacion', 'Acreditación por reciclaje'
    BONO_RACHA = 'bono_racha', 'Bono de racha'
    CANJE = 'canje', 'Canje de recompensa'


class SaldoEcoPuntos(models.Model):
    """Saldo vigente de un usuario. Se crea bajo demanda, igual que `Recolector.para_usuario`."""
    usuario = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='saldo_ecopuntos'
    )
    saldo = models.PositiveIntegerField(default=0)
    actualizado_en = models.DateTimeField(auto_now=True)

    @classmethod
    def para_usuario(cls, usuario):
        saldo, _ = cls.objects.get_or_create(usuario=usuario)
        return saldo


class TransaccionEcoPuntos(models.Model):
    """Historial (ledger) de movimientos de puntos — nunca se edita, solo se agrega."""
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='transacciones_ecopuntos'
    )
    tipo = models.CharField(max_length=20, choices=TipoTransaccion.choices)
    puntos = models.IntegerField()  # Positivo (acreditación/bono) o negativo (canje).
    solicitud = models.ForeignKey(
        'solicitudes.SolicitudRetiro', on_delete=models.SET_NULL, null=True, blank=True
    )
    racha_semanas = models.PositiveIntegerField(null=True, blank=True)  # Hito alcanzado, si aplica.
    canje = models.ForeignKey('Canje', on_delete=models.SET_NULL, null=True, blank=True)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-creado_en']


class Recompensa(models.Model):
    nombre = models.CharField(max_length=120)
    descripcion = models.TextField(blank=True)
    imagen = models.ImageField(upload_to='recompensas/')
    costo_puntos = models.PositiveIntegerField()
    categoria = models.CharField(max_length=20, blank=True)  # 'descuentos' | 'productos' | ...
    comercio_nombre = models.CharField(max_length=120, blank=True)
    activa = models.BooleanField(default=True)
    creado_en = models.DateTimeField(auto_now_add=True)


class Canje(models.Model):
    usuario = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='canjes')
    recompensa = models.ForeignKey(Recompensa, on_delete=models.PROTECT, related_name='canjes')
    puntos_gastados = models.PositiveIntegerField()
    codigo = models.CharField(max_length=20, unique=True)
    creado_en = models.DateTimeField(auto_now_add=True)


class RolRacha(models.TextChoices):
    CIUDADANO = 'ciudadano', 'Ciudadano'
    RECOLECTOR = 'recolector', 'Recolector'


class ProgresoRacha(models.Model):
    """
    Resultado persistido de evaluar la racha semana a semana para un rol.
    No es la "fuente de verdad" de qué semanas se cumplieron (eso vive en
    `SolicitudRetiro`/`AsignacionRetiro`); es el resultado idempotente de
    haber cerrado cada semana: cuántos protectores quedan, si ya se acreditó
    el bono de tal hito, y si hay un hito pendiente de mostrar en un modal.
    """
    usuario = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='progresos_racha')
    rol = models.CharField(max_length=20, choices=RolRacha.choices)
    racha_actual = models.PositiveIntegerField(default=0)
    racha_maxima = models.PositiveIntegerField(default=0)
    protectores_disponibles = models.PositiveSmallIntegerField(default=2)
    mes_protectores = models.DateField()  # Primer día del mes de la última recarga.
    semana_evaluada_hasta = models.DateField(null=True, blank=True)  # Lunes de la última semana ya cerrada.
    ultimo_hito_acreditado = models.PositiveIntegerField(default=0)
    hito_pendiente_de_mostrar = models.PositiveIntegerField(null=True, blank=True)

    class Meta:
        unique_together = [('usuario', 'rol')]


class EventoPendiente(models.Model):
    """
    Cola simple de eventos in-app que un rol aún no vio: acreditación de
    puntos tras un retiro (para el Ciudadano) o hito de racha (para
    cualquiera). El frontend la consulta al abrir la pantalla raíz del rol.
    """
    class Tipo(models.TextChoices):
        ACREDITACION = 'acreditacion', 'Acreditación de EcoPuntos'
        HITO_RACHA = 'hito_racha', 'Hito de racha'

    usuario = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='eventos_pendientes')
    tipo = models.CharField(max_length=20, choices=Tipo.choices)
    payload = models.JSONField()  # Datos ya resueltos para pintar el modal (puntos, saldo, racha, etc.)
    creado_en = models.DateTimeField(auto_now_add=True)
    visto_en = models.DateTimeField(null=True, blank=True)
```

`HITOS_PUNTOS` (tabla de la especificación) vive como constante en `gamificacion/services.py`, no en la base de datos — son reglas de producto, no datos administrables por ahora:

```python
HITOS_PUNTOS = {
    RolRacha.CIUDADANO: {2: 10, 4: 25, 8: 50, 12: 75, 26: 150, 52: 300},
    RolRacha.RECOLECTOR: {2: 5, 4: 12, 8: 25, 12: 40, 26: 75, 52: 150},
}
PROTECTORES_POR_MES = 2
```

### 2.4 Lógica de negocio (`gamificacion/services.py`)

**Acreditación por completado** (Paso 1-2 de la especificación), llamada desde `solicitudes/views.py`:

```python
def acreditar_por_completado(asignacion):
    solicitud = asignacion.solicitud
    puntos, co2_kg, agua_l = calcular_impacto(solicitud.tipo_material, solicitud.peso_kg)

    saldo = SaldoEcoPuntos.para_usuario(solicitud.usuario)
    with transaction.atomic():
        saldo = SaldoEcoPuntos.objects.select_for_update().get(pk=saldo.pk)
        saldo.saldo += puntos
        saldo.save(update_fields=['saldo', 'actualizado_en'])
        TransaccionEcoPuntos.objects.create(
            usuario=solicitud.usuario, tipo=TipoTransaccion.ACREDITACION,
            puntos=puntos, solicitud=solicitud,
        )
        EventoPendiente.objects.create(
            usuario=solicitud.usuario, tipo=EventoPendiente.Tipo.ACREDITACION,
            payload={'puntos': puntos, 'saldo_total': saldo.saldo},
        )
```

`calcular_impacto(tipo_material, peso_kg)` vive en `gamificacion/utils.py` con una tabla de factores por kg (placeholder que el producto debe validar, ej. plástico: 15 pts/kg, 1.5 kg CO₂/kg, 3 L agua/kg — mismo patrón que `solicitudes/utils.py` para distancia).

**Cierre semanal de racha** — `gamificacion/management/commands/cerrar_semana_racha.py`, corrido por cron/Celery beat cada lunes 00:05 (documentar en README de despliegue, no hay scheduler todavía en el proyecto):

```python
class Command(BaseCommand):
    def handle(self, *args, **options):
        for progreso in _progresos_a_evaluar():
            _cerrar_semana(progreso)


def _cerrar_semana(progreso: ProgresoRacha):
    semana_cumplida = _hubo_actividad_en_semana(progreso.usuario, progreso.rol, semana=...)
    _recargar_protectores_si_toca(progreso)

    if semana_cumplida:
        progreso.racha_actual += 1
        progreso.racha_maxima = max(progreso.racha_maxima, progreso.racha_actual)
    elif progreso.protectores_disponibles > 0:
        progreso.protectores_disponibles -= 1  # Racha no se rompe.
    else:
        progreso.racha_actual = 0

    _evaluar_hito(progreso)
    progreso.semana_evaluada_hasta = ...
    progreso.save()
```

`_hubo_actividad_en_semana` consulta, según `rol`:
- Ciudadano: `SolicitudRetiro.objects.filter(usuario=..., estado=COMPLETADA, actualizado_en__range=semana).exists()`.
- Recolector: `AsignacionRetiro.objects.filter(recolector=..., estado=COMPLETADA, completada_en__range=semana).exists()`.

`_evaluar_hito` compara `racha_actual` contra `HITOS_PUNTOS[rol]`; si cruza uno nuevo (mayor que `ultimo_hito_acreditado`), crea la `TransaccionEcoPuntos` de tipo `bono_racha`, suma el saldo, marca `ultimo_hito_acreditado` y `hito_pendiente_de_mostrar`, y crea un `EventoPendiente` tipo `hito_racha`.

`_progresos_a_evaluar` incluye de oficio un `ProgresoRacha.get_or_create` para todo usuario Ciudadano/Recolector con al menos una `SolicitudRetiro`/`AsignacionRetiro` histórica, igual que `Recolector.para_usuario` se crea bajo demanda.

### 2.5 Serializers (`gamificacion/serializers.py`)

- `SaldoEcoPuntosSerializer`: `{saldo}`.
- `TransaccionEcoPuntosSerializer`: `{id, tipo, tipo_display, puntos, creado_en, referencia}` (`referencia` = descripción corta según `tipo`, ej. "Papel y Cartón — 3.2 kg" o "Racha de 8 semanas").
- `RecompensaSerializer`: `{id, nombre, descripcion, imagen, costo_puntos, categoria, comercio_nombre}`.
- `CanjeSerializer`: `{id, recompensa (nested), puntos_gastados, codigo, creado_en}`.
- `ProgresoRachaSerializer`: `{racha_actual, racha_maxima, protectores_disponibles, protectores_totales=2, proximo_hito, puntos_proximo_hito}` (`proximo_hito`/`puntos_proximo_hito` calculados en el serializer a partir de `HITOS_PUNTOS[rol]`, no almacenados).
- `EventoPendienteSerializer`: `{id, tipo, payload, creado_en}`.
- `ImpactoSerializer` (no ligado a un modelo, se arma en la vista): `{co2_kg, agua_l, total_reciclado_kg, retiros_completados}`.

### 2.6 Endpoints (`gamificacion/views.py` + `gamificacion/urls.py`)

Todos requieren `IsAuthenticated`; el rol se infiere del usuario autenticado (grupo `Ciudadano`/`Recolector`) igual que el resto de la app — reusar `roles.permissions.EsCiudadano`/`EsRecolector` donde el endpoint deba distinguir tabla de hitos, no crear checks nuevos.

```
GET  /api/gamificacion/saldo/
  → SaldoEcoPuntosSerializer del usuario autenticado.

GET  /api/gamificacion/transacciones/?tipo=&page=
  → Historial paginado (usar el paginador por defecto de DRF), más reciente primero.

GET  /api/gamificacion/recompensas/?categoria=
  → Catálogo activo (Recompensa.objects.filter(activa=True)).

GET  /api/gamificacion/recompensas/{id}/
  → Detalle de una recompensa.

POST /api/gamificacion/recompensas/{id}/canjear/
  → Crea el Canje si el saldo alcanza; usa select_for_update sobre SaldoEcoPuntos
    (mismo patrón que `aceptar`/`completar` en solicitudes) para que dos canjes
    concurrentes no dejen el saldo negativo. 409 si el saldo es insuficiente.
  ← { canje: CanjeSerializer, saldo_restante }

GET  /api/gamificacion/racha/
  → ProgresoRachaSerializer para el rol del usuario autenticado.

GET  /api/gamificacion/impacto/
  → ImpactoSerializer agregado desde SolicitudRetiro/TransaccionEcoPuntos del usuario.
    Ciudadano: suma de peso_kg/co2/agua de sus solicitudes completadas.
    Recolector: total de AsignacionRetiro completadas (no huella personal — ver
    diferencia de rol en flujo-3-design-prompt.md, Screen 4).

GET  /api/gamificacion/eventos-pendientes/
  → Lista de EventoPendiente no vistos del usuario (acreditación + hito), orden FIFO.

POST /api/gamificacion/eventos-pendientes/{id}/marcar-visto/
  → Setea visto_en=now(). El frontend la llama justo después de cerrar cada modal.
```

Registrar en `config/urls.py`:

```python
path('api/', include('gamificacion.urls')),
```

### 2.7 Admin (`gamificacion/admin.py`)

Registrar `Recompensa` (para que el equipo cargue el catálogo sin tocar código: `nombre`, `costo_puntos`, `imagen`, `categoria`, `activa` editables), y `TransaccionEcoPuntos`/`Canje` como solo-lectura para soporte/depuración — mismo criterio que `AsignacionRetiroAdmin` en `solicitudes/admin.py`.

### 2.8 Migraciones y datos de prueba

```bash
python manage.py makemigrations solicitudes gamificacion
python manage.py migrate
```

Agregar `gamificacion/management/commands/seed_gamificacion_demo.py`, siguiendo el patrón de `seed_picker_demo`: crea 3-4 `Recompensa` de ejemplo y, opcionalmente, otorga saldo/racha de partida a `ciudadano_demo`/`recolector_demo` para poder ver las pantallas de Recompensas/Impacto pobladas sin tener que completar retiros reales primero.

### 2.9 Tests (`gamificacion/tests.py`, correr con `--settings=config.settings_test`)

- `calcular_impacto` con distintos materiales/pesos.
- `acreditar_por_completado` incrementa saldo y crea transacción + evento pendiente.
- `completar` en `solicitudes` exige `peso_kg` válido y dispara la acreditación (test de integración cruzando ambas apps).
- `cerrar_semana_racha`: semana cumplida incrementa racha; semana vacía con protector disponible no la rompe y descuenta protector; semana vacía sin protector la resetea a 0 sin tocar `racha_maxima`; cruce de hito acredita el bono exactamente una vez aunque el comando corra dos veces sobre la misma semana (idempotencia).
- `canjear`: rechaza con 409 si el saldo es insuficiente; dos canjes concurrentes con `select_for_update` no dejan saldo negativo (mismo estilo que el test de doble-aceptación en `solicitudes/tests.py`).

---

## 3. Frontend (Flutter)

### 3.1 Modelos nuevos (`lib/models/`)

- `saldo_ecopuntos.dart` → `{saldo}`.
- `transaccion_ecopuntos.dart` → `{id, tipo, tipoDisplay, puntos, creadoEn, referencia}`.
- `recompensa.dart` → `{id, nombre, descripcion, imagenUrl, costoPuntos, categoria, comercioNombre}`.
- `canje.dart` → `{id, recompensa, puntosGastados, codigo, creadoEn}`.
- `progreso_racha.dart` → `{rachaActual, rachaMaxima, protectoresDisponibles, protectoresTotales, proximoHito, puntosProximoHito}`.
- `impacto.dart` → `{co2Kg, aguaL, totalRecicladoKg, retirosCompletados}`.
- `evento_pendiente.dart` → `{id, tipo, payload}` (`payload` como `Map<String, dynamic>` crudo; cada modal lee las claves que necesita).

Seguir el patrón dual de `Solicitud.fromJson` solo si hace falta: aquí no hay dos formas del mismo recurso, así que un solo `fromJson` por modelo basta.

### 3.2 Servicio (`lib/services/gamificacion_service.dart`)

Mismo estilo que `PickerService`/`SolicitudesService` (usa `ApiClient.instance`, un método por endpoint, lanza `ApiException` tal cual):

```dart
class GamificacionService {
  GamificacionService(this._client);
  final ApiClient _client;

  Future<SaldoEcoPuntos> obtenerSaldo() => ...
  Future<List<TransaccionEcoPuntos>> historialTransacciones({String? tipo}) => ...
  Future<List<Recompensa>> catalogoRecompensas({String? categoria}) => ...
  Future<Recompensa> obtenerRecompensa(int id) => ...
  Future<Canje> canjear(int recompensaId) => ...  // 409 -> lanzar excepción específica, como SolicitudYaTomadaException
  Future<ProgresoRacha> obtenerRacha() => ...
  Future<Impacto> obtenerImpacto() => ...
  Future<List<EventoPendiente>> eventosPendientes() => ...
  Future<void> marcarEventoVisto(int id) => ...
}
```

`completar` en `PickerService` gana un parámetro `pesoKg` (`Future<AsignacionRetiro> completar(int solicitudId, {required double pesoKg})`), ya que el Recolector lo captura en el mismo paso de "Marcar como completado" (`post_accept_screen.dart`) — agregar ahí un campo numérico antes de confirmar.

### 3.3 Pantallas nuevas (mapeo directo a `stitch_ecorecicla_ciudadano/`)

| Pantalla Stitch | Archivo Flutter | Notas de implementación |
|---|---|---|
| `acreditaci_n_ecopuntos_equilibrado` | `widgets/ecopuntos_modal.dart` (widget de modal reutilizable, no una pantalla propia) | Se muestra con `showDialog`/`showGeneralDialog` sobre la pantalla raíz vigente cuando llega un `EventoPendiente` tipo `acreditacion`. Botón "Ver recompensas" navega a `RecompensasScreen`; "Cerrar" solo llama `marcarEventoVisto`. |
| `mi_impacto_y_racha_equilibrado` | `screens/mi_impacto_screen.dart` | Combina `ProgresoRacha` + `Impacto`; el botón "Compartir" usa `share_plus` (agregar a `pubspec.yaml`) o, si no se agrega la dependencia, `Share` nativo vía `url_launcher` como fallback simple. Diferenciar contenido por rol (`AuthService.usuarioActual().rol`) tal como describe `flujo-3-design-prompt.md` Screen 4. |
| `recompensas_y_canje_equilibrado` | `screens/recompensas_screen.dart` | Pantalla de tab (reemplaza a Perfil en el navbar). El detalle+confirmación de canje del Stitch está resuelto como modal in-page (no una pantalla aparte); replicar igual con `showModalBottomSheet`/`AlertDialog` en vez de una navegación nueva, para no desviarse del diseño. |
| `hito_de_racha_equilibrado` | `widgets/hito_racha_modal.dart` | Igual patrón que el modal de acreditación; usa la tabla de puntos ya resuelta por el backend en el `payload` del evento (no hardcodear los montos en Flutter). |

### 3.4 Navegación y pestañas (cambio en ambos roles)

**Ciudadano — `screens/home_screen.dart`**: reemplazar la pestaña `_destinoPerfil` por `_destinoRecompensas`, apuntando a `RecompensasScreen`. `NavigationDestination` cambia de `Icons.person_outline` a `Icons.card_giftcard`/`Icons.workspace_premium` (icono usado en el Stitch), label `"Recompensas"`.

**Recolector — `screens/picker/picker_shell.dart`**: mismo cambio en `_BarraRecolector`: la cuarta pestaña pasa de `PerfilRecolectorScreen` a `RecompensasScreen` (la misma pantalla que el ciudadano — el catálogo y el saldo son compartidos, ver especificación).

**Ícono de perfil (nuevo, ambos roles)**: cada pantalla de tab de nivel superior (Inicio/`_HomeTab`, Historial, Recompensas, y Mapa/Mis Rutas/Historial para el Recolector) necesita el mismo header con ícono de perfil arriba a la derecha que muestran todos los `code.html` de Stitch. Como hoy cada pantalla arma su propio `AppBar` (no hay un header compartido a nivel de shell), crear un widget común:

```dart
// lib/widgets/eco_app_bar.dart
class EcoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EcoAppBar({super.key, required this.titulo, required this.onAbrirPerfil});
  final String titulo;
  final VoidCallback onAbrirPerfil;
  // AppBar con ícono de notificaciones (deshabilitado/decorativo por ahora,
  // fuera de alcance) + IconButton(Icons.account_circle) -> onAbrirPerfil.
}
```

Usarlo en `_HomeTab`, `HistorialScreen`, `RecompensasScreen`, `MiImpactoScreen`, y en `PickerMapScreen`, `MisRutasScreen`, `HistorialRecolectorScreen`. `onAbrirPerfil` navega con `Navigator.push` a `PerfilCiudadanoScreen`/`PerfilRecolectorScreen` según el rol (cada shell ya sabe cuál es el suyo).

**Perfil deja de ser pestaña, gana una entrada a Impacto**: en `PerfilCiudadanoScreen` y `PerfilRecolectorScreen`, agregar un `ListTile`/`Card` "Mi Impacto y Racha" (ícono `Icons.eco`) entre la cabecera y el botón de cerrar sesión, que navega a `MiImpactoScreen`. Ninguna de las dos pantallas de perfil pierde su contenido actual (datos de cuenta, disponibilidad del recolector, cerrar sesión) — solo se accede desde el ícono en vez de una pestaña.

### 3.5 Modales al abrir la app (cola de eventos pendientes)

En el `initState` de `HomeScreen` y de `PickerShell`, tras el primer build, llamar `GamificacionService.eventosPendientes()`; si hay resultados, mostrarlos secuencialmente (`await showDialog(...)` uno por uno, llamando `marcarEventoVisto` al cerrar cada uno antes de mostrar el siguiente) para no apilar modales. Reusar el mismo mecanismo para ambos tipos de evento, distinguiendo por `evento.tipo` cuál widget de modal instanciar (`EcoPuntosModal` vs `HitoRachaModal`).

### 3.6 Dependencias (`pubspec.yaml`)

Ninguna dependencia nueva es estrictamente necesaria (`http`, `flutter_map`, etc. ya cubren todo). Si se implementa "Compartir mi impacto" con la hoja de compartir nativa en vez de copiar un enlace, agregar `share_plus` — evaluar contra el alcance antes de sumar una dependencia.

### 3.7 Tests

- `test/models/`: `fromJson` de cada modelo nuevo (mismo patrón que `test/models/solicitud_test.dart`).
- Widget test de `RecompensasScreen`: catálogo se pinta, botón "Canjear" deshabilitado si el saldo no alcanza.
- Widget test de `EcoPuntosModal`/`HitoRachaModal`: texto y montos vienen del `payload`, no hardcodeados.
- `flutter analyze` en cero antes de cerrar la fase (regla del proyecto).

---

## 4. Orden de implementación sugerido

1. **Backend — modelos y migraciones**: `peso_kg` en `SolicitudRetiro`; app `gamificacion` completa (modelos, admin, migraciones).
2. **Backend — acreditación por completado**: extender `completar`, `gamificacion/services.acreditar_por_completado`, `calcular_impacto`. Probar con `curl`/DRF browsable API antes de tocar Flutter.
3. **Backend — racha**: `ProgresoRacha`, comando `cerrar_semana_racha`, endpoint `GET /racha/`. Probar corriendo el comando manualmente contra datos de `seed_picker_demo`.
4. **Backend — recompensas y canje**: modelos `Recompensa`/`Canje`, endpoints de catálogo/canje, `seed_gamificacion_demo`.
5. **Backend — eventos pendientes**: modelo `EventoPendiente`, endpoints de lectura/marcado, disparo desde acreditación e hito.
6. **Frontend — modelos y servicio**: `GamificacionService` + modelos, contra el backend ya funcionando.
7. **Frontend — navegación**: `EcoAppBar`, cambio de pestañas en `HomeScreen`/`PickerShell`, entrada a Impacto desde ambos Perfiles.
8. **Frontend — pantallas**: `RecompensasScreen`, `MiImpactoScreen`, y los dos modales, verificando pixel a pixel contra `stitch_ecorecicla_ciudadano/*/screen.png`.
9. **Frontend — cola de eventos**: enganchar los modales al abrir `HomeScreen`/`PickerShell`.
10. **Extender `completar` en el Recolector**: capturar `peso_kg` en `post_accept_screen.dart` antes de confirmar.
11. **Testing end-to-end**: completar un retiro real con `ciudadano_demo`/`recolector_demo`, verificar acreditación, forzar semanas vía `cerrar_semana_racha --fecha=...` (agregar flag de fecha simulada al comando para poder probar sin esperar semanas reales), verificar hito y canje.
12. **`flutter analyze` + `python manage.py test` (ambas apps) en verde** antes de dar por cerrada la fase, según la regla del proyecto.

---

## 5. Riesgos y preguntas abiertas

- **Factores de impacto ambiental y de puntos por kg** (`calcular_impacto`) son placeholders de este plan — deben validarse con el equipo de producto antes de salir a producción; no bloquean la implementación técnica.
- **Scheduler para `cerrar_semana_racha`**: el proyecto no tiene hoy Celery ni un scheduler configurado; para desarrollo alcanza con correrlo manualmente o via `cron` del sistema apuntando a `manage.py cerrar_semana_racha`. Definir la solución de producción está fuera del alcance de este plan.
- **Compartir impacto en redes**: el Stitch usa `navigator.share` (Web Share API); en Flutter esto requiere una dependencia nueva (`share_plus`) — confirmar si vale la pena para v1 o si un botón "Copiar enlace" simple (sin dependencia) es suficiente.
