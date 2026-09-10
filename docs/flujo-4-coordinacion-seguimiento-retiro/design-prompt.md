# Flujo 4 — Coordinación y Seguimiento del Retiro: Design Prompt

## Overview

Diseñar cuatro pantallas móviles para el flujo de **coordinación y seguimiento de un retiro** de EcoRecicla. El objetivo es reducir la incertidumbre entre que una solicitud es publicada y que el material se recoge: el ciudadano sabe **cuándo** llegará el recolector, **quién** es y en qué estado está el retiro.

Este flujo empieza cuando un Recolector acepta una `SolicitudRetiro` y termina cuando el Ciudadano confirma que el retiro fue realizado. Al completarse, se enlaza con el Flujo 3 de fidelización: acreditación de EcoPuntos, impacto y racha.

Diseñar para el rol **Ciudadano / Generador**. No crear un chat interno ni un sistema de pagos; las acciones de contacto abren WhatsApp o una llamada telefónica.

---

## User Context

- **Usuario**: Ciudadano o comercio de Santa Cruz que ya publicó reciclables para retirar.
- **Momento de entrada**: desde el detalle de una solicitud recién aceptada, desde “Mis solicitudes activas” del Inicio, o tras una notificación de que el recolector está en camino.
- **Device**: mobile, viewport de 390 × 844 px.
- **Idioma**: español (Bolivia). Usar tono cálido, claro y directo.
- **Marca**: EcoRecicla; reutilizar los componentes, iconografía y estilo existentes. Debe sentirse parte de la misma app que Publicar Reciclaje, Historial, Recompensas y Mi Impacto.
- **Design system**: utilizar únicamente los tokens reales de `frontend/lib/theme/app_theme.dart`. No inventar una segunda paleta ni patrones visuales nuevos.

---

## Flow Overview

```text
Recolector acepta la solicitud
        ↓
Screen 1 — Elegir / confirmar franja horaria
        ↓
Screen 2 — Recolector y retiro confirmados
        ↓
Screen 3 — Seguimiento de estado del retiro
        ↓
Screen 4 — Confirmación y calificación
        ↓
Flujo 3 — Modal “¡Retiro completado!” + EcoPuntos
```

La Screen 1 se muestra solo cuando aún falta que el ciudadano indique disponibilidad o acepte una propuesta. Las Screens 2 y 3 son destinos persistentes dentro del detalle de la solicitud activa: el usuario puede volver a ellas desde Inicio sin reiniciar el flujo.

---

## Screen 1: Elegir franja de retiro

### Purpose

Permitir al ciudadano informar de manera rápida cuándo puede entregar su material, sin obligarlo a escribir mensajes. La selección hace que el recolector pueda organizar su recorrido antes de confirmar el retiro.

### Key Elements

- **Header**: botón volver y título “¿Cuándo puedes entregar?”
- **Contexto breve de la solicitud**: mini tarjeta con foto o placeholder, “Plástico”, cantidad estimada y dirección de retiro. Ejemplo: “Av. Banzer, 3.er anillo”.
- **Texto guía**: “Elige una franja en la que alguien pueda entregar el material.”
- **Selector de día**: chips horizontales con “Hoy, jue 12”, “Mañana, vie 13” y “Sáb 14”. El día activo tiene fondo `primary` y texto claro; los demás usan estilo outlined.
- **Franjas horarias**: lista de botones de selección de alto cómodo (mínimo 48 px):
  - “Mañana · 08:00–11:00”
  - “Mediodía · 11:00–14:00”
  - “Tarde · 15:00–18:00”
  - “Noche · 18:00–20:00”
- **Opción alternativa**: fila “Proponer otro horario” con icono de calendario. Abre un selector simple de fecha y hora; no requiere diseñar un calendario complejo en esta entrega.
- **Nota opcional**: campo de texto corto “Indicaciones para el recolector (opcional)”, por ejemplo: “Tocar timbre del portón azul”.
- **CTA fijo inferior**: `FilledButton` de ancho completo, “Confirmar disponibilidad”. Permanece deshabilitado hasta que se elija una franja.

### Interaction and State

- Al seleccionar una franja, mostrar un check claro y actualizar el CTA a “Confirmar: mañana, 15:00–18:00”.
- Tras confirmar, mostrar una confirmación ligera tipo snackbar: “Disponibilidad enviada. Te avisaremos cuando el recolector confirme.” Luego llevar a Screen 2 con estado “Esperando confirmación”.
- Si el recolector ya propuso una franja, sustituir la selección libre por una tarjeta destacada: “Carlos propone: Mañana, 15:00–18:00”, con acciones “Aceptar horario” y “Elegir otro”.

### Design Notes

- La pantalla debe sentirse rápida y práctica: priorizar selección mediante chips y botones sobre formularios largos.
- No usar un mapa ni información repetida de la dirección; basta el resumen de solicitud.
- Mantener el CTA accesible sobre cualquier lista desplazable, respetando el área segura inferior.

---

## Screen 2: Retiro confirmado

### Purpose

Dar certeza al ciudadano una vez que hay recolector y horario: quién realizará el retiro, cuándo ocurrirá y cómo contactarlo si hace falta.

### Key Elements

- **Header**: botón volver, título “Retiro confirmado” y chip de estado verde “Confirmado”.
- **Hero de estado**: icono de check dentro de un círculo `mintLight`, título “¡Todo listo para tu retiro!” y texto: “Carlos pasará mañana entre 15:00 y 18:00.”
- **Tarjeta de horario**: icono de calendario, fecha y franja en tipografía prominente; texto secundario “Te avisaremos cuando esté en camino”.
- **Tarjeta “Tu recolector”**:
  - Avatar circular con inicial o foto.
  - Nombre: “Carlos R.”
  - Etiqueta de confianza: “Recolector verificado”.
  - Si ya existe información fiable, una calificación compacta, por ejemplo “★ 4.8 · 126 retiros”. No inventar una calificación si la app no la maneja.
  - Botones de contacto: “WhatsApp” y “Llamar”, cada uno con icono y etiqueta; deben ser secundarios al estado, no CTAs dominantes.
- **Resumen compacto**: material, cantidad estimada y dirección. Añadir enlace “Ver detalle de solicitud”.
- **Acción inferior**: botón outlined “Cambiar horario” y enlace discreto “Cancelar solicitud” solo si la política actual permite cancelar.

### Waiting State

Usar esta misma composición justo después de Screen 1, con variante de espera:

- Chip ámbar/neutro: “Esperando confirmación”.
- Hero: “Disponibilidad enviada”.
- Texto: “Carlos confirmará el horario pronto.”
- La tarjeta de horario muestra la franja solicitada como “Propuesta”.
- No mostrar el botón de cambiar horario como confirmación final; mostrar “Editar disponibilidad”.

### Design Notes

- La información que debe leerse primero es: **estado, día/hora y persona asignada**.
- Evitar una UI de mensajería. WhatsApp y llamada son salidas del sistema, consistentes con el alcance del proyecto.
- La Screen 2 debe poder aparecer en el detalle existente de la solicitud sin perder la foto ni los datos básicos que ya tiene la app.

---

## Screen 3: Seguimiento del retiro

### Purpose

Permitir al ciudadano revisar el progreso sin tener que contactar al recolector. Comunica claramente qué ha pasado, qué sigue y cuándo debe prepararse para entregar el material.

### Key Elements

- **Header**: botón volver y título “Seguimiento del retiro”.
- **Tarjeta de estado principal**:
  - Estado actual destacado: “Carlos está en camino”.
  - Texto de apoyo: “Prepárate para entregar tu material.”
  - Hora de actualización: “Actualizado hace 3 min”.
  - Opcional: estimación discreta “Llega aprox. en 15–25 min”. Solo usarla si la aplicación dispone de ese dato; de lo contrario, omitirla.
- **Timeline vertical** de cuatro pasos, con iconos y conectores:
  1. “Solicitud aceptada” — completado, con fecha/hora.
  2. “Horario confirmado” — completado, “Mañana · 15:00–18:00”.
  3. “En camino” — activo en `primary`, con texto “Carlos va hacia tu dirección”.
  4. “Material recogido” — pendiente, tono `outlineVariant`.
- **Mapa contextual pequeño** (no navegación completa): ubicación de retiro marcada y, si se dispone de geolocalización, un indicador genérico del recolector aproximándose. No mostrar ruta precisa ni simular GPS si no existe.
- **Tarjeta “Datos del retiro”**: material, dirección y franja horaria, con link a los detalles.
- **Acciones inferiores**:
  - Primaria: “Contactar a Carlos” (WhatsApp) solo si el estado es “En camino” o “Llegó”.
  - Secundaria: “Llamar”.

### State Variants

- **Aceptado / antes del horario**: la timeline deja activo “Horario confirmado”; el hero dice “Tu retiro está programado”. No mostrar estimación ni botones urgentes de contacto.
- **Llegó**: hero “Tu recolector ha llegado”, con icono de ubicación. CTA “Contactar a Carlos”. El paso “En camino” pasa a completado y “Material recogido” sigue pendiente.
- **Sin conexión / cargando**: preservar la última actualización y mostrar “No pudimos actualizar el estado. Intenta de nuevo.” con acción “Reintentar”; no borrar la información confirmada.

### Design Notes

- La timeline es el elemento principal, no un mapa. Es más útil y viable que un rastreo GPS en tiempo real.
- Diferenciar siempre activo, completado y pendiente con color, icono y texto; no depender únicamente del color.
- No incluir un botón “Marcar como completado” en esta pantalla: la confirmación se maneja después de que el recolector registra el retiro.

---

## Screen 4: Retiro completado y calificación

### Purpose

Cerrar la coordinación de forma confiable: el ciudadano valida que el material fue recogido y deja una valoración breve. Esta confirmación abre la puerta al flujo de EcoPuntos ya existente.

### Entry Condition

El Recolector marcó el retiro como completado. Mostrar primero el resumen para que el ciudadano pueda validar el resultado, no asumir la confirmación sin informar qué se registró.

### Key Elements

- **Header**: botón cerrar y título “Retiro completado”.
- **Hero positivo**: círculo `mintLight` con check, título “¡Tu material ya fue recogido!” y texto de agradecimiento: “Gracias por darle una nueva vida a tus reciclables.”
- **Resumen de retiro**:
  - Material: “Plástico PET”.
  - Peso registrado: “3.5 kg”. Si el peso aún no está disponible, usar “Peso por validar” y no inventar un número.
  - Fecha/hora: “Jueves 12 · 16:20”.
  - Recolector: “Carlos R.”
- **Confirmación explícita**: pregunta “¿Se realizó el retiro correctamente?”
  - Botón primario: “Sí, confirmar retiro”.
  - Acción de texto: “Necesito reportar un problema”. Esta abre un estado simple con motivos (no llegó, retiro parcial, otro) y botón “Enviar reporte”; no diseñar soporte conversacional.
- **Calificación**: visible después de confirmar o debajo de la confirmación como sección opcional. Pregunta “¿Cómo fue tu experiencia con Carlos?” con cinco estrellas grandes, etiquetas de apoyo (“Mala” a “Excelente”) y campo opcional “Cuéntanos más”.
- **CTA final**: después de enviar la valoración, “Ver mis EcoPuntos” → abre el modal de acreditación / Recompensas del Flujo 3. Alternativa secundaria: “Volver al inicio”.

### Interaction and State

- El botón de confirmar debe requerir toque intencional, pero no otro modal adicional: el usuario ya está viendo el resumen completo.
- La calificación es opcional y puede omitirse con “Ahora no”. No bloquear los EcoPuntos ni el cierre del retiro por no calificar.
- Tras confirmar, la solicitud sale de “Activas” y se archiva en Historial con estado “Completada”.

### Design Notes

- Esta pantalla debe sentirse como un cierre calmado y satisfactorio, no como una celebración de puntos: la celebración de EcoPuntos corresponde al Flujo 3.
- Evitar duplicar los paneles de impacto, racha o recompensas aquí. Incluir solamente el puente “Ver mis EcoPuntos”.

---

## Design System Tokens (EcoRecicla)

| Token | Valor | Uso en este flujo |
| --- | --- | --- |
| `EcoColors.primary` | `#0F5238` | CTAs principales, estado activo, selección confirmada |
| `EcoColors.primaryContainer` | `#2D6A4F` | Fondos de bloques destacados si se necesita alto contraste |
| `EcoColors.onPrimaryContainer` | `#A8E7C5` | Texto sobre `primaryContainer` |
| `EcoColors.mintLight` | `#D8F3DC` | Fondo de iconos positivos, check de confirmación |
| `EcoColors.secondaryContainer` | `#B0F1CC` | Chips de estado positivo y acentos suaves |
| `EcoColors.surface` | `#F8F9FA` | Fondo general |
| `EcoColors.surfaceContainerLowest` | `#FFFFFF` | Cards principales |
| `EcoColors.surfaceContainerLow` | `#F3F4F5` | Cards secundarias, timeline pendiente |
| `EcoColors.onSurface` | `#191C1D` | Texto principal |
| `EcoColors.onSurfaceVariant` | `#404943` | Texto descriptivo y metadata |
| `EcoColors.outlineVariant` | `#BFC9C1` | Bordes, pasos pendientes y separadores |
| `EcoColors.warningAmber` | `#FCBF49` | Solo estado de espera o atención suave |
| `EcoColors.dangerRed` | `#E63946` | Reportar un problema, errores reales |
| `EcoSpacing.element / stack / container / section` | `8 / 16 / 24 / 32 px` | Ritmo vertical |
| `EcoSpacing.touchTarget` | `48 px` | Alto mínimo interactivo |
| `EcoRadius.lg / xl / x2l` | `8 / 12 / 16 px` | Radios de campos, cards y contenedores |
| Tipografía | Inter | `headlineLarge` para estado/horario clave; `bodySmall` para metadata |

---

## Accessibility & UX Notes

1. Todos los objetivos táctiles (chips, botones, estrellas, iconos de contacto) deben medir al menos 48 × 48 px.
2. No comunicar estados solo mediante color: acompañar cada paso de timeline con icono, etiqueta y estado textual.
3. Mantener contraste AA para texto, estados y CTAs, especialmente texto claro sobre verde.
4. Usar fechas y horas completas o inequívocas; no usar solo “mañana” si el usuario puede volver a abrir la pantalla otro día.
5. Si el recolector, el horario o la conexión no están disponibles, explicar la situación y preservar la información ya confirmada en lugar de mostrar una pantalla vacía.
6. Las acciones de WhatsApp y llamada deben tener etiquetas de texto; no depender únicamente de logos.
7. El usuario debe poder volver al detalle de la solicitud desde las Screens 2 y 3 sin perder su posición ni la información del flujo.

---

## Scope Boundaries

- **In scope**: franja horaria, datos del recolector asignado, estados de retiro, contacto externo, confirmación ciudadana y valoración simple.
- **Out of scope**: chat interno, pagos, rastreo GPS real o rutas en vivo, negociación de precios, soporte conversacional, múltiples recolectores por solicitud.
- **Integración con Flujo 3**: después de la Screen 4, abrir el modal de acreditación ya definido en `docs/flujo-3-fidelizacion-gamificacion/flujo-3-design-prompt.md`. No rediseñar EcoPuntos, recompensas, impacto ni rachas dentro de este flujo.

---

## Deliverable Request for Google Stitch

Crear un prototipo mobile de 4 pantallas conectadas para EcoRecicla:

1. **Elegir franja de retiro** — selector de día/franja y CTA de confirmación.
2. **Retiro confirmado** — horario, recolector asignado y contacto externo.
3. **Seguimiento del retiro** — timeline de cuatro estados con variante “en camino”.
4. **Retiro completado y calificación** — resumen, confirmación ciudadana, valoración opcional y enlace a EcoPuntos.

Usar datos de demostración coherentes en todo el prototipo: solicitud de **Plástico PET**, dirección **Av. Banzer, 3.er anillo**, recolector **Carlos R.**, horario **jueves 12, 15:00–18:00**, y peso final **3.5 kg**. Conservar la estética sobria, amable y ecológica de EcoRecicla; mucho espacio legible, cards blancas sobre fondo claro y verde oscuro como color de acción principal.
