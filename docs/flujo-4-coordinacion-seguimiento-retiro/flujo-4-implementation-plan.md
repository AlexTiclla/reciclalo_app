# Plan de Implementación — Flujo 4: Coordinación y Seguimiento del Retiro

Implementación end-to-end (backend Django + frontend Flutter) del flujo de coordinación de franja horaria, seguimiento del estado del retiro y calificación ciudadana, para el rol **Ciudadano/Generador** (con los cambios mínimos necesarios en el flujo del Recolector para que el otro lado de la conversación exista). Este documento asume que ya se leyó:

- `flujo-4-coordinacion-seguimiento-retiro/design-prompt.md` (prompt de diseño original usado para generar las 4 pantallas en Stitch).
- `flujo-4-coordinacion-seguimiento-retiro/retiro-completado-rediseno-prompt.md` — prompt de **rediseño** de la Screen 4, que la deja como una pantalla de calificación pura (sin confirmación ni reporte de problema). Ver §1 para el porqué.
- Las pantallas ya generadas en `stitch_ecorecicla_ciudadano/` (`elegir_franja_de_retiro`, `retiro_confirmado`, `seguimiento_del_retiro`, y la nueva versión de `retiro_completado_y_calificaci_n` una vez regenerada) — **las pantallas Flutter deben verse igual a estos `code.html`/`screen.png`**, reutilizando los tokens de `ecoharmony/DESIGN.md` / `frontend/lib/theme/app_theme.dart` (`EcoColors`/`EcoSpacing`/`EcoRadius`), igual que exige `flujo-3-implementation-plan.md`.
- `docs/flujo-3-fidelizacion-gamificacion/flujo-3-implementation-plan.md`, porque este flujo se apoya en ese: los EcoPuntos se siguen acreditando exactamente donde ya lo hacen hoy.

---

## 1. Resumen y alcance

### Decisión de diseño que fija este plan

El borrador original de este plan evaluaba mover la acreditación de EcoPuntos al momento en que el Ciudadano confirma el retiro (un estado intermedio `entregado`), porque el mock original de Screen 4 decía *"tu confirmación libera la asignación de puntos"*. **Se decidió no tocar el acoplamiento actual**: `solicitudes.completar()` (acción del Recolector) sigue siendo la única acción que cierra la solicitud (`estado → completada`) y dispara `gamificacion.services.acreditar_por_completado`, exactamente como en el Flujo 3 ya implementado. Es la opción de menor riesgo: no rompe nada ya probado, y no le exige al usuario un paso extra para acceder a algo que ya es suyo.

Consecuencia directa: la Screen 4 ya no tiene ninguna acción que confirmar ni nada que "liberar" — para cuando el Ciudadano la ve, el retiro ya está cerrado y los puntos ya están en su cuenta. Por eso se regenera como **una pantalla de calificación pura** (ver `retiro-completado-rediseno-prompt.md`): resumen de lo ya registrado + calificación opcional del Recolector. Se elimina también el bloque "Necesito reportar un problema" que en el diseño original colgaba de esa confirmación — si más adelante se quiere un canal de disputa, es una función aparte que merece su propio diseño.

### Alcance de esta fase

- Coordinación de franja horaria entre Ciudadano y Recolector tras `aceptar()` (propuesta, contrapropuesta, confirmación).
- Activación real del estado `en_camino` (existe en `EstadoSolicitud` desde el flujo de recolección pero no se usa hoy — ver `CLAUDE.md`).
- Pantalla de seguimiento con timeline de 4 pasos + mapa contextual (sin ruta ni GPS en vivo reales).
- Calificación opcional del Recolector una vez que la solicitud llega a `completada` (sin gate: los EcoPuntos ya están acreditados).
- Contacto por WhatsApp/llamada **del Ciudadano hacia el Recolector** (hasta ahora el flujo del Recolector solo tenía el sentido inverso).

### Fuera de alcance (ver `design-prompt.md`, sección "Scope Boundaries")

- Chat interno, pagos, negociación de precio, soporte conversacional, múltiples recolectores por solicitud.
- Confirmación explícita del retiro y reporte de problema — existían en el diseño original de la Screen 4 y se descartan junto con la decisión de arriba (ver `retiro-completado-rediseno-prompt.md`).
- Ruta real / GPS en vivo / ETA calculada. El mapa de Screen 3 es contextual (destino + última posición conocida del recolector), no navegación ni un motor de ruteo.
- Cancelación de solicitud: el propio `design-prompt.md` la condiciona a "si la política actual lo permite" y hoy no existe tal política. **Se deja fuera de esta fase** (ver §6).
- Rediseñar EcoPuntos/Recompensas/Impacto/Racha — eso ya está resuelto por el Flujo 3; aquí no se toca.

### Otros supuestos de diseño que fija este plan

1. **`en_camino` deja de estar sin usar.** Se activa con una acción explícita del Recolector (no hay GPS que lo dispare solo).
2. **La calificación del recolector se agrega recién con este flujo.** `Recolector` no tiene hoy ninguna noción de rating ni de "verificado". Las Screens 2, 3 y 4 muestran "★ 4.8 · 126 retiros", un chip "Verificado" y (la Screen 4 regenerada) un tag "Retiro domiciliario" — el `design-prompt.md` mismo advierte *"No inventar una calificación si la app no la maneja"*. Este plan hace que el rating sea real (promedio de `AsignacionRetiro.calificacion`, que este mismo flujo empieza a poblar) y trata "Verificado"/"Recolector verificado" y "Retiro domiciliario" como **copy cosmético sin campo de modelo** — no se construye un sistema de verificación ni un tipo de retiro (`SolicitudRetiro` no distingue domiciliario/punto limpio hoy, y este flujo no lo agrega). Con cero calificaciones, el frontend debe mostrar "Sin calificaciones aún" en vez de inventar un número.
3. **El teléfono del Recolector no existe hoy.** `Recolector` no tiene campo de contacto — solo `SolicitudRetiro.telefono_contacto` (el teléfono del Ciudadano, usado por el Recolector). Los botones "WhatsApp"/"Llamar" de las Screens 2 y 3 exigen que el Recolector tenga un teléfono publicable. Se agrega `Recolector.telefono`.
4. **El mapa de Screen 3 usa datos reales, no simulados.** `Recolector.latitud_actual/longitud_actual` ya existen y se actualizan por `POST /api/recolector/ubicacion/`. Se reutiliza esa misma señal (con un ping periódico mientras el recolector está `en_camino`) en vez de inventar una posición. La "Aproximación en vivo" del Stitch es, en la práctica, la última posición conocida — igual de honesto que lo que ya hace `cercanas`.

---

## 2. Máquina de estados

`EstadoSolicitud` **no gana ningún valor nuevo** — sigue siendo el de siempre:

```text
pendiente → aceptada → en_camino → completada
```

| Transición | Quién la dispara | Acción/endpoint | Efecto |
| --- | --- | --- | --- |
| `pendiente → aceptada` | Recolector | `POST /solicitudes/{id}/aceptar/` (ya existe) | sin cambios |
| `aceptada → en_camino` | Recolector | `POST /solicitudes/{id}/en-camino/` (nuevo) | requiere franja confirmada; sella `AsignacionRetiro.en_camino_en` |
| `en_camino → completada` | Recolector | `POST /solicitudes/{id}/completar/` (ya existe) | **sin cambios**: exige `peso_kg`, acredita EcoPuntos igual que hoy |

Lo único nuevo sobre la solicitud ya `completada` es que el Ciudadano puede calificarla una vez (`POST /solicitudes/{id}/calificar/`) — no es una transición de `estado`, solo agrega datos sobre la `AsignacionRetiro` ya cerrada.

En paralelo, la **coordinación de franja** es independiente del estado principal y vive en su propio campo `estado_coordinacion` (solo aplica mientras `estado` es `aceptada` o `en_camino`):

| `estado_coordinacion` | Significado | Pantalla que corresponde |
| --- | --- | --- |
| `pendiente` | Aceptada, nadie propuso franja todavía | Screen 1 (modo selección libre) |
| `propuesta_ciudadano` | El Ciudadano eligió una franja, espera que el Recolector la confirme | Screen 2, variante "Esperando confirmación" |
| `propuesta_recolector` | El Recolector contrapropuso una franja | Screen 1 (modo "Carlos propone…", con "Aceptar horario" / "Elegir otro") |
| `confirmada` | Ambos coinciden | Screen 2 (variante confirmada) → luego Screen 3 una vez que `estado` pasa a `en_camino` |

`aceptar-franja` es la acción que cierra cualquiera de las dos ramas de propuesta hacia `confirmada`; se puede llamar solo desde el lado que **no** propuso el último cambio.

### Enrutador de pantalla (`abrirCoordinacion`, frontend)

Una sola función decide qué pantalla abrir al tocar una solicitud desde Inicio/Historial, en vez de replicar esta lógica en cada punto de entrada:

```text
estado == pendiente                                    → detalle simple existente (sin recolector aún)
estado == aceptada, coordinacion == pendiente           → Screen 1 (selección)
estado == aceptada, coordinacion == propuesta_ciudadano → Screen 2 (esperando confirmación)
estado == aceptada, coordinacion == propuesta_recolector→ Screen 1 (modo propuesta)
estado == aceptada, coordinacion == confirmada          → Screen 2 (confirmada)
estado == en_camino                                     → Screen 3
estado == completada                                    → Screen 4 (calificación) — interactiva si aún no calificó, solo lectura si ya lo hizo
```

`completada` ya no depende de si el Ciudadano "confirmó" nada — llega ahí apenas el Recolector completa, igual que hoy. Como consecuencia, deja de aparecer en `?estado=activas` en el mismo momento en que el Recolector completa (sin cambios respecto al comportamiento actual del backend).

---

## 3. Backend (Django)

### 3.1 `solicitudes/models.py`

```python
class EstadoCoordinacion(models.TextChoices):
    PENDIENTE = 'pendiente', 'Sin franja'
    PROPUESTA_CIUDADANO = 'propuesta_ciudadano', 'Propuesta por el ciudadano'
    PROPUESTA_RECOLECTOR = 'propuesta_recolector', 'Propuesta por el recolector'
    CONFIRMADA = 'confirmada', 'Confirmada'


class Recolector(models.Model):
    ...
    telefono = models.CharField(max_length=20, blank=True)   # nuevo — para que el ciudadano lo contacte
    foto = models.ImageField(upload_to='recolectores/', null=True, blank=True)  # nuevo, opcional


class SolicitudRetiro(models.Model):
    ...
    # --- Coordinación de franja (Screen 1/2) — único agregado a este modelo ---
    estado_coordinacion = models.CharField(
        max_length=25, choices=EstadoCoordinacion.choices,
        default=EstadoCoordinacion.PENDIENTE,
    )
    ventana_inicio = models.DateTimeField(null=True, blank=True)
    ventana_fin = models.DateTimeField(null=True, blank=True)
    notas_entrega = models.CharField(max_length=280, blank=True)  # "Tocar timbre del portón azul"
    franja_confirmada_en = models.DateTimeField(null=True, blank=True)
    # estado/peso_kg no cambian — completar() sigue funcionando exactamente igual que hoy.


class AsignacionRetiro(models.Model):
    ...
    en_camino_en = models.DateTimeField(null=True, blank=True)
    llego_en = models.DateTimeField(null=True, blank=True)  # opcional, ver §6

    # --- Calificación del ciudadano (Screen 4) ---
    calificacion = models.PositiveSmallIntegerField(
        null=True, blank=True,
        validators=[MinValueValidator(1), MaxValueValidator(5)],
    )
    calificacion_etiquetas = models.JSONField(default=list, blank=True)
    calificacion_comentario = models.CharField(max_length=200, blank=True)
```

`calificacion_etiquetas` guarda strings cortos elegidos de un set fijo definido **en el frontend** (igual que el mockup: "Puntual", "Amable y respetuoso", "Cuidado del material") — el backend solo valida longitud/cantidad (máx. 5 ítems, 30 caracteres c/u), no un catálogo administrable; no hace falta una tabla nueva para esto.

No hay ningún campo de "reporte de problema" — se descartó junto con la Screen 4 original (ver §1).

### 3.2 `solicitudes/views.py` — acciones nuevas en `SolicitudRetiroViewSet`

`ACCIONES_RECOLECTOR` ya distingue por acción; las de coordinación las necesitan **ambos** roles, así que no encajan en ese set binario. Se resuelve con chequeos por objeto dentro de cada acción (mismo estilo que `PuedeVerSolicitud`), no con un permiso de clase:

```python
def _es_dueno(self, solicitud):
    return solicitud.usuario_id == self.request.user.id

def _es_recolector_asignado(self, solicitud):
    perfil = getattr(self.request.user, 'perfil_recolector', None)
    return perfil is not None and solicitud.recolector_id == perfil.id
```

- **`POST /solicitudes/{id}/proponer-franja/`** — body `{ventana_inicio, ventana_fin, notas_entrega?}`. Cualquiera de las dos partes puede llamarla mientras `estado in (ACEPTADA, EN_CAMINO)`. Valida `ventana_fin > ventana_inicio` y que `ventana_inicio` no sea pasado. Efecto: guarda la ventana propuesta y setea `estado_coordinacion` a `propuesta_ciudadano` o `propuesta_recolector` según quién llamó. `notas_entrega` solo la escribe el Ciudadano (se ignora si la manda el Recolector).
- **`POST /solicitudes/{id}/aceptar-franja/`** — sin body. Solo válida si `estado_coordinacion` es una propuesta hecha por **la otra parte** (evita que alguien "acepte" su propia propuesta). Efecto: `estado_coordinacion = CONFIRMADA`, `franja_confirmada_en = now()`.
- **`POST /solicitudes/{id}/en-camino/`** — solo Recolector asignado. Exige `estado == ACEPTADA` y `estado_coordinacion == CONFIRMADA` (no se puede salir a caminar sin franja acordada). Efecto: `estado = EN_CAMINO`, `AsignacionRetiro.en_camino_en = now()`.
- **`completar`** — **sin cambios**. Sigue dejando `estado = COMPLETADA`, guardando `peso_kg` y llamando a `gamificacion.services.acreditar_por_completado` en el mismo paso, igual que hoy.
- **`POST /solicitudes/{id}/calificar/`** (nuevo, solo dueño) — exige `estado == COMPLETADA`. Body `{calificacion, etiquetas?, comentario?}`. Completamente opcional — si el ciudadano toca "Ahora no" en Screen 4, esta acción simplemente no se llama; no bloquea ni condiciona nada, porque los puntos ya se acreditaron cuando el Recolector completó.

`get_queryset` no se toca — el comportamiento de `?estado=activas` (excluye `COMPLETADA`) sigue siendo el de hoy.

### 3.3 `RecolectorViewSet` — teléfono

Sigue el mismo patrón que `disponibilidad`:

```python
@action(detail=False, methods=['post'])
def telefono(self, request):
    telefono = (request.data.get('telefono') or '').strip()
    perfil = self._perfil()
    perfil.telefono = telefono
    perfil.save(update_fields=['telefono'])
    return Response(RecolectorPerfilSerializer(perfil).data)
```

`RecolectorPerfilSerializer` gana `telefono` (editable) y `foto`.

### 3.4 Serializers (`solicitudes/serializers.py`)

- `RecolectorResumenSerializer` (lo que ve el Ciudadano) gana: `telefono`, `foto`, `calificacion_promedio` (`SerializerMethodField`, `Avg('asignaciones__calificacion')` filtrando no-nulos, `None` si no hay ninguna), y reexpone `total_completadas` (ya existe en el modelo, solo faltaba en este serializer).
- `SolicitudRetiroSerializer` (Ciudadano) gana los campos nuevos de solo lectura: `estado_coordinacion`, `estado_coordinacion_display`, `ventana_inicio`, `ventana_fin`, `notas_entrega`.
- Nuevo `SerializerMethodField` condicional en `SolicitudRetiroSerializer` que agrega `recolector_ubicacion: {latitud, longitud, actualizado_en} | null` — **solo** cuando `self.context['request'].user == solicitud.usuario` (el dueño), reutilizando `PuedeVerSolicitud` como ya hace `retrieve`. No se expone en el serializer del Recolector ni en `cercanas` (ahí ya no aplica).
- `AsignacionRetiroSerializer` gana `en_camino_en`, `llego_en`, `calificacion`, `calificacion_etiquetas`, `calificacion_comentario` (todos de solo lectura desde este serializer — se escriben por `calificar`, no por `PATCH`).

`gamificacion/services.py` **no necesita ningún cambio** — `acreditar_por_completado` sigue con la misma firma y el mismo único punto de llamada (`solicitudes.views.completar`) que documenta `CLAUDE.md`.

### 3.5 Admin (`solicitudes/admin.py`)

`SolicitudRetiroAdmin.list_display`/`list_filter` ganan `estado_coordinacion`, para poder filtrar solicitudes atascadas en coordinación desde el admin.

### 3.6 Migraciones y datos de prueba

```bash
python manage.py makemigrations solicitudes
python manage.py migrate
```

- `seed_picker_demo` (existente): agregar `telefono` al crear/actualizar el `Recolector` de `recolector_demo`, para que el flujo de contacto funcione de punta a punta sin pasos manuales.
- Opcional: parámetro o comando auxiliar que deje una solicitud demo en cada estado de coordinación (`pendiente`/`propuesta`/`confirmada`) para poder abrir cada pantalla sin tener que jugar la app entera cada vez — útil para QA visual contra los `screen.png`. No bloquea el resto del plan si no se hace.

### 3.7 Tests (`solicitudes/tests.py`, con `--settings=config.settings_test`)

- `proponer_franja`: el dueño y el recolector asignado pueden llamarla; un tercero no. Rechaza `ventana_fin <= ventana_inicio`.
- `aceptar_franja`: falla si la última propuesta la hizo el mismo usuario que intenta aceptarla ("no puedes aceptarte a ti mismo").
- `en_camino`: 409/400 si `estado_coordinacion != CONFIRMADA`; ok si lo está.
- `completar`: **sin test nuevo** — el comportamiento no cambió, la suite existente del Flujo 3 sigue cubriéndolo.
- `calificar`: 400/409 si `estado != COMPLETADA`; guarda `calificacion`/`etiquetas`/`comentario`; se puede omitir sin que nada más se rompa; un segundo intento de calificar la misma asignación se rechaza o sobrescribe (decidir y documentar el comportamiento elegido — se recomienda rechazar con 409, "ya calificaste este retiro").
- `RecolectorResumenSerializer.calificacion_promedio`: `None` sin calificaciones, promedio correcto con varias.

---

## 4. Frontend (Flutter)

### 4.1 Modelos (`lib/models/`)

- `solicitud.dart`: `Solicitud` gana `estadoCoordinacion` (nuevo enum `EstadoCoordinacion`), `ventanaInicio`/`ventanaFin` (`DateTime?`), `notasEntrega`, y `recolectorUbicacion` (`UbicacionRecolector?`, con `latitud`, `longitud`, `actualizadoEn`, parseado solo si el JSON lo trae — el backend lo omite para quien no es el dueño). `Recolector` (la clase anidada) gana `telefono`, `fotoUrl`, `calificacionPromedio` (`double?`), `totalCompletadas` (`int`).
- `EstadoSolicitud` **no cambia** — sigue con los 4 valores de siempre.
- `lib/models/asignacion_retiro.dart` (extender el existente): `enCaminoEn`, `llegoEn`, `calificacion`, `calificacionEtiquetas`, `calificacionComentario`.

### 4.2 Servicio — extender `SolicitudesService`

No hace falta un servicio nuevo; estas acciones cuelgan de `/api/solicitudes/{id}/...` igual que las del Recolector en `PickerService`, pero las llama el Ciudadano. Se agregan a `SolicitudesService`:

```dart
Future<Solicitud> proponerFranja(int id, {required DateTime inicio, required DateTime fin, String notas = ''});
Future<Solicitud> aceptarFranja(int id);
Future<void> calificar(int id, {required int estrellas, List<String> etiquetas = const [], String comentario = ''});
```

`PickerService` gana el lado del Recolector: `proponerFranja` (mismo endpoint, distinto rol autenticado), `aceptarFranja`, `enCamino`. `completar` no cambia de firma ni de comportamiento.

### 4.3 Pantallas nuevas — mapeo directo a `stitch_ecorecicla_ciudadano/`

Conviene un subdirectorio propio, igual que el flujo del Recolector vive bajo `screens/picker/`:

| Pantalla Stitch | Archivo Flutter | Notas |
| --- | --- | --- |
| `elegir_franja_de_retiro` | `screens/coordinacion/elegir_franja_screen.dart` | Chips de día (`ChoiceChip` o fila custom con el estilo del mock) + lista de franjas fijas (Mañana/Mediodía/Tarde/Noche con sus horas fijas del mock) + "Proponer otro horario" abre `showDatePicker`+`showTimePicker` nativos (el `design-prompt.md` explícitamente exime de diseñar un calendario custom). Si `estadoCoordinacion == propuestaRecolector`, reemplaza la grilla por la tarjeta "Carlos propone…" con dos botones (`aceptarFranja` / limpiar y volver al modo selección). CTA inferior fijo (`FilledButton` full-width, patrón ya usado en `post_accept_screen.dart`) deshabilitado hasta elegir franja, texto dinámico `"Confirmar: mañana, 15:00–18:00"`. |
| `retiro_confirmado` | `screens/coordinacion/retiro_confirmado_screen.dart` | Dos variantes por `estadoCoordinacion` (`propuestaCiudadano` = "esperando", `confirmada` = confirmado), un solo widget con un `switch`. Tarjeta "Tu recolector" reutiliza el patrón de avatar+nombre+chip de `_Encabezado` en `request_details_screen.dart` pero en sentido ciudadano; botones WhatsApp/Llamar nuevos (ver §4.5). "Cancelar solicitud" **no se implementa** (ver §1 y §6) — se omite el link en vez de dejarlo como no-op. |
| `seguimiento_del_retiro` | `screens/coordinacion/seguimiento_retiro_screen.dart` | Timeline vertical de 4 pasos (widget nuevo `widgets/coordinacion/timeline_paso.dart`, reutilizable: estado completado/activo/pendiente con icono+texto, nunca solo color — regla de accesibilidad del `design-prompt.md`). Mapa: extiende `MapaUbicacion` de `eco_map.dart` con un segundo marcador opcional + `PolylineLayer` recto (no ruta real) cuando `solicitud.recolectorUbicacion != null`; ver §4.6. Botones de contacto solo visibles si `estado == enCamino` (regla explícita del mock). |
| `retiro_completado_y_calificaci_n` (versión regenerada, ya generada — ver `retiro-completado-rediseno-prompt.md`) | `screens/coordinacion/retiro_completado_screen.dart` | Resumen de solo lectura (avatar + "Carlos R." + chip "Verificado", material, peso, fecha, tag estático "Retiro domiciliario" — copy fijo, sin campo de backend) + bloque informativo "+N EcoPuntos acreditados a tu cuenta / Disponibles ahora mismo en tu balance" (los puntos ya están en la cuenta, no hay nada que confirmar) + sección de estrellas (widget nuevo `widgets/coordinacion/calificacion_estrellas.dart`, 5 iconos ≥48×48px) + chips de etiquetas fijas + campo opcional, con "Ahora no" para saltar sin bloquear nada. Si `AsignacionRetiro.calificacion` ya viene con valor (reapertura desde Historial), la sección de calificación se muestra en modo solo lectura en vez del selector interactivo. No hay botón "confirmar" ni flujo de reporte de problema — confirmado contra el mock regenerado. |

### 4.4 Enrutador y puntos de entrada

Nuevo helper `lib/routing_coordinacion.dart` (o un método estático en un widget) implementando la tabla de §2:

```dart
Future<void> abrirCoordinacion(BuildContext context, Solicitud solicitud) async {
  final pantalla = switch ((solicitud.estado, solicitud.estadoCoordinacion)) {
    (EstadoSolicitud.pendiente, _) => SolicitudDetalleScreen(solicitudId: solicitud.id),
    (EstadoSolicitud.aceptada, EstadoCoordinacion.pendiente) => ElegirFranjaScreen(solicitud: solicitud),
    (EstadoSolicitud.aceptada, EstadoCoordinacion.propuestaRecolector) => ElegirFranjaScreen(solicitud: solicitud),
    (EstadoSolicitud.aceptada, _) => RetiroConfirmadoScreen(solicitud: solicitud),
    (EstadoSolicitud.enCamino, _) => SeguimientoRetiroScreen(solicitud: solicitud),
    (EstadoSolicitud.completada, _) => RetiroCompletadoScreen(solicitud: solicitud),
  };
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
}
```

`_HomeTab` (`home_screen.dart`) cambia el `onTap` de `SolicitudCard` para llamar `abrirCoordinacion` en vez de navegar siempre a `SolicitudDetalleScreen`. `HistorialScreen` cambia igual: sus tarjetas (`estado == completada`) abren `RetiroCompletadoScreen` en modo solo lectura en vez del detalle genérico, para que el Ciudadano pueda ver/calificar un retiro pasado que todavía no calificó.

### 4.5 Contacto Ciudadano → Recolector

Hoy `WhatsAppButton`/`WhatsAppService` están pensados para que el **Recolector** contacte al Ciudadano (usa `solicitud.telefonoContacto`). Para este flujo se necesita el sentido inverso. Se recomienda reutilizar, no duplicar:

- Generalizar `WhatsAppService.contactar(telefono, mensaje)` (ya es genérico) y crear un widget nuevo `widgets/coordinacion/contacto_recolector_row.dart` con los dos botones "WhatsApp"/"Llamar" (icono `Icons.chat_bubble_outline`/`Icons.call_outlined`, mínimo `EcoSpacing.touchTarget`), usando `solicitud.recolector!.telefono`. "Llamar" usa `url_launcher` con `Uri(scheme: 'tel', path: telefono)` — no existe hoy en el proyecto, es la primera vez que se abre el marcador; confirmar que el `<queries>` de `AndroidManifest.xml` ya cubre `tel:` (revisar `intent-filter` de `ACTION_DIAL`/`ACTION_CALL`; si no está, agregarlo junto al de WhatsApp/Maps que ya existe).
- Si `solicitud.recolector!.telefono` está vacío (recolector viejo que nunca lo cargó), ocultar los botones y mostrar un texto neutro ("El recolector aún no registró un teléfono de contacto") en vez de un botón roto — mismo criterio que `Solicitud.tieneTelefono` ya aplica del otro lado.

### 4.6 Mapa de seguimiento (Screen 3)

`MapaUbicacion` (en `widgets/picker/eco_map.dart`) ya resuelve "un pin, sin gestos, dentro de una card". Se extiende (no se duplica) para aceptar un segundo punto opcional:

```dart
class MapaUbicacion extends StatelessWidget {
  const MapaUbicacion({
    ...
    this.ubicacionSecundaria,     // nuevo: LatLng? del recolector
    this.etiquetaSecundaria,      // nuevo: 'Tu recolector'
  });
```

Cuando `ubicacionSecundaria != null`: agrega un segundo `Marker` (icono de camioncito, `EcoColors.primary` sobre círculo, mismo lenguaje visual que `_ChinchetaDestino`) y una `PolylineLayer` con una línea recta entre ambos puntos — deliberadamente **no** una ruta por calles, para no fingir un dato que no existe (coherente con "no mostrar ruta precisa" del `design-prompt.md`). El `initialCenter`/`initialZoom` deben ajustarse con `LatLngBounds` para que ambos puntos queden visibles (usar el `fitCamera` de `FlutterMap` con los dos puntos).

**Para que `ubicacionSecundaria` tenga datos frescos**, el Recolector necesita seguir pingueando su posición mientras está `en_camino` — hoy solo se pinguea dentro de `cercanas()` (cuando busca solicitudes) y al llamar `ubicacion()` manualmente. Se agrega un `Timer.periodic` (p. ej. cada 30–60 s) dentro de `post_accept_screen.dart`, activo solo mientras `solicitud.estado == enCamino`, que llama `PickerService.actualizarUbicacion(...)` usando `location_service.dart` (ya existe, usado en el mapa del Recolector). Se cancela en `dispose()` y al completar.

### 4.7 Cambios mínimos en el flujo del Recolector (`post_accept_screen.dart`)

Esta pantalla no está rediseñada por este `design-prompt.md` (es exclusivo del Ciudadano), así que los agregados son deliberadamente utilitarios, no un rediseño:

1. Sección de estado de coordinación: si `estadoCoordinacion != confirmada`, un banner con "Proponer horario" (abre `showDatePicker`+`showTimePicker`, llama `proponerFranja`); si ya hay una propuesta del ciudadano pendiente, dos botones "Aceptar" / "Proponer otro".
2. Una vez `estadoCoordinacion == confirmada` y `estado == aceptada`: aparece "Voy en camino" (`FilledButton.icon`, llama `enCamino`).
3. "Marcar como completado" **no cambia**: sigue siendo la misma acción con el mismo snackbar de éxito ("¡Retiro completado! Gracias por reciclar.") — el Recolector sigue siendo quien cierra el retiro, sin ningún paso intermedio nuevo.
4. `PerfilRecolectorScreen` gana un `TextField` + botón guardar para `telefono` (llama al nuevo endpoint de §3.3), en la misma sección donde hoy vive el toggle de disponibilidad.

### 4.8 Integración con Flujo 3

**No requiere ningún cambio.** `gamificacion_service.dart`, `EcoPuntosModal` y `HitoRachaModal` se reutilizan sin tocar — como `completar()` no cambió, la acreditación de puntos sigue disparando el mismo `EventoPendiente` que hoy, y `HomeScreen._mostrarEventosPendientes()` lo sigue mostrando la próxima vez que el Ciudadano abre Inicio, exactamente como en el Flujo 3. `RetiroCompletadoScreen` de este flujo (la pantalla de calificación) es una superficie completamente aparte que no interactúa con ese modal — no lo abre ni depende de él.

### 4.9 Tests

- `test/models/`: `fromJson` de los campos nuevos en `Solicitud`/`AsignacionRetiro`, incluyendo el caso de `recolectorUbicacion` ausente.
- Widget test de `TimelinePaso`: los 4 estados (completado/activo/pendiente + el variante "llegó") se distinguen por texto e ícono, no solo color (assert explícito, ya que es una regla de accesibilidad citada en el propio `design-prompt.md`).
- Widget test de `ElegirFranjaScreen`: el CTA permanece deshabilitado sin selección y se habilita al elegir una franja.
- Widget test de `RetiroCompletadoScreen`: modo interactivo cuando `calificacion == null`, modo solo lectura cuando ya viene con valor; "Ahora no" no dispara ninguna llamada de red.
- `flutter analyze` en cero antes de cerrar la fase (regla del proyecto).

---

## 5. Orden de implementación sugerido

1. **Backend — modelos y migraciones**: `estado_coordinacion` y campos de franja en `SolicitudRetiro`; campos de calificación + `en_camino_en` en `AsignacionRetiro`; `telefono`/`foto` en `Recolector`. (`completar()` no se toca.)
2. **Backend — coordinación de franja**: `proponer-franja`, `aceptar-franja`, `en-camino`. Probar con `curl`/DRF browsable API contra `seed_picker_demo`.
3. **Backend — calificación**: acción `calificar`, con el gate `estado == COMPLETADA`.
4. **Backend — serializers y teléfono del recolector**: exponer todos los campos nuevos, `calificacion_promedio`, endpoint de teléfono.
5. **Backend — admin y seed**: filtro por `estado_coordinacion`, `telefono` en `seed_picker_demo`.
6. **Backend — tests**: cubrir coordinación de franja + `en_camino` + `calificar` (§3.7) antes de tocar Flutter.
7. **Frontend — modelos y servicio**: extender `Solicitud`/`AsignacionRetiro`, `SolicitudesService`, `PickerService`.
8. **Frontend — mapa**: extender `MapaUbicacion` con el segundo marcador + polyline recta; ping periódico de ubicación en `post_accept_screen.dart`.
9. ~~Regenerar Screen 4 en Stitch~~ — **hecho**: `stitch_ecorecicla_ciudadano/retiro_completado_y_calificaci_n/` ya tiene la versión de solo calificación, verificada contra `retiro-completado-rediseno-prompt.md`.
10. **Frontend — pantallas del Ciudadano**: las 4 pantallas, verificando pixel a pixel contra `stitch_ecorecicla_ciudadano/*/screen.png` (Screen 4 ya en su versión final de calificación).
11. **Frontend — enrutador**: `abrirCoordinacion`, cambio del `onTap` en `_HomeTab` y en `HistorialScreen`.
12. **Frontend — lado Recolector**: banner de coordinación + "Voy en camino" en `post_accept_screen.dart`, campo de teléfono en `PerfilRecolectorScreen`.
13. **Testing end-to-end**: con `ciudadano_demo`/`recolector_demo`, recorrer aceptar → proponer/confirmar franja → en camino → completar (recolector, EcoPuntos se acreditan aquí, igual que hoy) → calificar (ciudadano, opcional).
14. **`flutter analyze` + `python manage.py test` (ambas apps) en verde** antes de dar por cerrada la fase.

---

## 6. Riesgos y decisiones abiertas

1. **`llego_en` ("Tu recolector ha llegado")** es la única pieza que este plan marca como *nice-to-have*: agrega una micro-transición sin cambiar `estado`, solo para el copy del hero de Screen 3. Se puede diferir a una iteración posterior sin romper nada del resto del flujo.
2. **ETA ("Llegada estimada: 15–25 min")** se omite por completo en v1 — no hay motor de ruteo ni velocidad estimada real, y el propio `design-prompt.md` condiciona esa pieza a que "la aplicación disponga de ese dato".
3. **Bootstrapping de calificaciones**: los primeros recolectores no tendrán rating hasta que se completen los primeros retiros de este flujo. El frontend debe manejar `calificacionPromedio == null` con un estado explícito ("Sin calificaciones aún"), no con un placeholder inventado.
4. **Cancelación de solicitud**: queda fuera de esta fase (ver §1). Si se pide después, probablemente necesite su propio estado (`cancelada`) y una política de qué pasa con una solicitud `aceptada`/`en_camino` cancelada — no es una extensión trivial del modelo actual y merece su propio mini-plan.
5. **Reporte de problema**: se descartó junto con la confirmación explícita (§1). Si el producto lo pide más adelante, es una función de soporte/disputa independiente — no debería colgar de la pantalla de calificación.
6. **Teléfono del Recolector en el registro**: este plan lo agrega solo al perfil (editable después de crear la cuenta), no al formulario de registro (`registro_screen.dart`) — un recolector recién registrado no podrá ser contactado hasta que lo cargue. Si el producto prefiere pedirlo en el registro, es un cambio pequeño en `RegistroUsuarioSerializer`/`registro_screen.dart`, pero se deja fuera para no ampliar el alcance de `roles/`.
