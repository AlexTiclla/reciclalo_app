# Flujo 3 — Fidelización y Gamificación: Design Prompt

## Overview
Diseñar las pantallas de **fidelización, EcoPuntos, recompensas e impacto ambiental** de EcoRecicla. Este flujo cierra el ciclo después de cada retiro completado: acredita EcoPuntos, deja canjearlos, y muestra al usuario su impacto ambiental acumulado junto a su racha de constancia. Es compartido por **ambos roles** — Ciudadano y Recolector — con diferencias puntuales que se marcan en cada pantalla.

La especificación funcional completa (reglas de racha, protectores, tablas de puntos) vive en `flujo_de_fidelizaci_n_y_gamificaci_n.md`, en esta misma carpeta — este documento es el prompt de diseño visual derivado de esa especificación.

---

## User Context
- **Roles**: Ciudadano/Comercio (Generador) y Recolector/Operador — ambos ven estas pantallas, con la misma estructura visual.
- **Momento de entrada**: después de que una `SolicitudRetiro` pasa a `completada` (vía la acción `completar` del recolector).
- **Device**: Mobile (390×844 viewport)
- **Design System**: tokens reales de `frontend/lib/theme/app_theme.dart` (ver sección de tokens abajo) — **no inventar colores ni espaciados nuevos**, reutilizar `EcoColors` / `EcoSpacing` / `EcoRadius`.

---

## Flow Overview

```
(Solicitud marcada "completada")
        ↓
Modal de Acreditación de EcoPuntos (Paso 2)
        ↓
Pantalla "Recompensas" (Paso 3) ←→ Detalle de Recompensa → Confirmación de Canje
        ↓
Panel de Impacto y Racha (Paso 4) — pestaña del perfil, acceso permanente
        ↓
Modal de Hito de Racha (aparece solo al cruzar 2/4/8/12/26/52 semanas)
```

Las pantallas 2, 3 y 4 no son necesariamente secuenciales: el Panel de Impacto y Recompensas son destinos permanentes accesibles desde la navegación principal; los modales (1 y 4) son eventos que interrumpen el flujo cuando ocurren.

---

## Screen 1: Modal de Acreditación de EcoPuntos

### Purpose
Confirmar de inmediato, apenas se completa un retiro, cuántos EcoPuntos ganó el usuario — refuerzo positivo inmediato (Paso 1 → Paso 2 de la especificación).

### Key Elements
- **Modal centrado**, overlay oscuro semi-transparente detrás.
- **Icono/ilustración** de check o de una hoja/moneda ecológica en la parte superior, sobre `EcoColors.mintLight` como fondo circular.
- **Título**: "¡Retiro completado!" (mismo texto para ambos roles; el Recolector lo ve tras marcar `completar`, el Ciudadano tras recibir la confirmación).
- **Resumen del retiro**: tipo de material, peso/volumen registrado.
- **Puntos ganados**: número grande y prominente en `EcoColors.primary`, ej. "+45 EcoPuntos", con el ícono de EcoPuntos junto al número.
- **Saldo actualizado**: línea secundaria, ej. "Saldo total: 320 EcoPuntos".
- **Botones**:
  - Primario (`FilledButton`): "Ver recompensas" → navega a Screen 2.
  - Secundario (texto/ghost): "Cerrar" → descarta el modal.

### Design Notes
- No debe sentirse como una alerta de error — usar tonos verdes cálidos, nunca `dangerRed`/`warningAmber`.
- Modal ligero, sin scroll; debe caber en una pantalla sin desplazamiento.
- Reutilizar el mismo patrón de modal para el Screen 4 (Hito de Racha) por consistencia, cambiando solo contenido e ilustración.

---

## Screen 2: Recompensas (Canje de Incentivos)

### Purpose
Vitrina donde el usuario ve su saldo de EcoPuntos y navega el catálogo de recompensas canjeables. Pantalla compartida por Ciudadano y Recolector — mismo catálogo, mismo saldo compartido por rol.

### Key Elements
- **Header**: título "Recompensas", con el saldo de EcoPuntos del usuario destacado en una tarjeta fija arriba (ícono + número grande + "EcoPuntos disponibles").
- **Tabs o filtro de categoría** (opcional, si el catálogo crece): "Todos", "Descuentos", "Servicios", "Productos".
- **Lista/grid de recompensas** (cards de 2 columnas o lista vertical):
  - Imagen/logo del comercio aliado.
  - Nombre de la recompensa (ej. "20% de descuento en Tienda Verde").
  - Costo en EcoPuntos (ej. "150 pts").
  - Estado visual: si el usuario no tiene saldo suficiente, la card se ve atenuada (opacidad reducida) con un badge "Te faltan 80 pts".
- **Interacciones**:
  - Tap en una card → Screen 3 (Detalle de Recompensa).

### Design Notes
- El saldo debe ser lo primero que se lee en la pantalla — tratarlo como el "hero" de la vista, similar a un balance de billetera.
- Usar `EcoColors.surfaceContainerLow` para el fondo de las cards, `EcoColors.primary` para precios/CTAs.
- Si el catálogo está vacío (sin recompensas activas de comercios aliados), mostrar un estado vacío amigable, no un error.

---

## Screen 3: Detalle de Recompensa y Confirmación de Canje

### Purpose
Mostrar el detalle de una recompensa puntual y confirmar el canje antes de descontar puntos — patrón espejo del "Confirmation Dialog" del flujo del recolector (`picker-flow-design-prompt.md`).

### Key Elements
- **Header**: botón de cerrar/volver.
- **Imagen grande** del comercio/recompensa.
- **Detalles**: nombre, descripción, condiciones de uso (vigencia, restricciones), costo en EcoPuntos.
- **Botón principal**: "Canjear por X EcoPuntos" (`FilledButton`, ancho completo).
- **Modal de confirmación** al tocar el botón (mismo patrón que "Confirmar Aceptar" del flujo del recolector):
  - "¿Confirmas el canje?" + resumen (recompensa, costo, saldo restante tras el canje).
  - Botones: "Sí, canjear" (primario) / "Cancelar" (ghost).
- **Pantalla de éxito** tras confirmar: check verde, código o instrucciones para reclamar la recompensa (ej. código QR o código alfanumérico), botón "Volver a Recompensas".

### Design Notes
- Si el saldo es insuficiente, el botón principal debe estar deshabilitado con texto "Te faltan X pts" en vez de ocultarse.
- El código de canje (si aplica) debe ser fácil de copiar/mostrar al comercio — texto grande, monoespaciado si es alfanumérico.

---

## Screen 4: Panel de Impacto y Racha (Paso 4)

### Purpose
Vista central de perfil/gamificación: huella de carbono evitada + racha de constancia + protectores disponibles. Es la pantalla ancla de todo el flujo — el usuario vuelve aquí seguido para ver su progreso, no solo tras completar un retiro.

### Key Elements
- **Header**: "Mi Impacto" (o el nombre que use el resto de la app para el tab de perfil/impacto).
- **Tarjeta de racha** (arriba, prominente):
  - Número grande de semanas actuales, ej. "4 semanas seguidas" con un ícono de llama o de hoja (mantener el lenguaje visual "eco", evitar copiar literalmente el ícono de fuego de Duolingo si no calza con la marca — se puede usar una hoja o gota que se "acumula").
  - Fila de **protectores de racha**: 2 íconos de escudo, llenos o vacíos según cuántos quedan disponibles este mes.
  - Texto secundario con la **racha máxima histórica**, ej. "Tu mejor racha: 12 semanas".
  - Mini indicador de progreso hacia el próximo hito (ej. barra o texto "3 semanas para tu próximo bono").
- **Tarjeta de huella ambiental**:
  - Métricas de impacto del mes (o histórico, con selector de periodo si aplica): CO2 evitado (kg), agua ahorrada (litros), quizás cantidad de material reciclado (kg) por tipo.
  - Formato tipo "stat tile": ícono + número grande + unidad + etiqueta.
- **Botón de compartir**: ícono de compartir junto a las métricas, para redes sociales (mencionado en la especificación original del Paso 4).
- **Diferencia por rol**: el Recolector ve además un contador de "Retiros completados este mes" en vez de (o junto a) las métricas de huella ambiental orientadas al Ciudadano, ya que su impacto se mide más en volumen gestionado que en huella evitada personal.

### Design Notes
- Esta pantalla reutiliza el patrón de "stat tiles" — mantener consistencia de tamaño de ícono, tipografía (`headlineLarge` para números, `bodySmall` para etiquetas) entre la tarjeta de racha y la de huella.
- Cuando un protector se consume automáticamente esa semana, no hace falta un modal (ver especificación) — pero sí debe reflejarse aquí con un pequeño indicador visual (ej. el ícono de escudo con un check superpuesto o un tooltip "Usado esta semana") para que el usuario entienda por qué su racha no se rompió sin tener actividad.

---

## Screen 5: Modal de Hito de Racha

### Purpose
Celebrar el momento exacto en que el usuario cruza un umbral de racha (2, 4, 8, 12, 26 o 52 semanas) — evento que **no** ocurre cada semana, solo al alcanzar esos hitos exactos (ver especificación, sección "Notificación del hito").

### Key Elements
- Mismo patrón de modal que Screen 1 (icono superior, título, cuerpo, dos botones), para que el usuario reconozca visualmente "este es un logro" sin aprender un componente nuevo.
- **Ilustración/ícono de celebración**: distinto al de acreditación de puntos — algo más festivo (confeti sutil, medalla, o el ícono de racha con un brillo), para diferenciarlo del modal rutinario de puntos por retiro.
- **Título**: "¡Racha de X semanas!" (X = 2, 4, 8, 12, 26 o 52).
- **Cuerpo**: bono de EcoPuntos otorgado, con la tabla correspondiente al rol (Ciudadano o Recolector) de la especificación — el número debe coincidir exactamente con esa tabla, no un valor genérico.
- **Botones**:
  - Primario: "Ver mis recompensas" → Screen 2.
  - Secundario: "Seguir reciclando" / "Cerrar" → descarta el modal y vuelve a donde estaba el usuario.

### Design Notes
- Debe sentirse como un logro, no como una notificación transaccional — usar más espacio en blanco, ilustración más grande, tono más celebratorio que el modal de Screen 1.
- Aparece encima de cualquier pantalla en la que el usuario esté (según la especificación: "al abrir la app o al completarse la acción que cierra esa semana") — diseñar como overlay global, no atado a una pantalla específica.

---

## Design System Tokens (EcoRecicla — `app_theme.dart`)

| Token | Valor | Uso sugerido en este flujo |
|---|---|---|
| `EcoColors.primary` | `#0F5238` | CTAs primarios, números de puntos/racha |
| `EcoColors.primaryContainer` | `#2D6A4F` | Fondos de tarjetas destacadas (racha, saldo) |
| `EcoColors.onPrimaryContainer` | `#A8E7C5` | Texto sobre `primaryContainer` |
| `EcoColors.mintLight` | `#D8F3DC` | Fondos de íconos/ilustraciones en modales |
| `EcoColors.secondaryContainer` | `#B0F1CC` | Chips de estado (ej. "Canjeado") |
| `EcoColors.surface` | `#F8F9FA` | Fondo general de pantalla |
| `EcoColors.surfaceContainerLowest` | `#FFFFFF` | Fondo de cards |
| `EcoColors.surfaceContainerLow` | `#F3F4F5` | Fondo de cards secundarias (recompensas) |
| `EcoColors.onSurface` | `#191C1D` | Texto principal |
| `EcoColors.onSurfaceVariant` | `#404943` | Texto secundario |
| `EcoColors.outlineVariant` | `#BFC9C1` | Bordes de botones outlined, separadores |
| `EcoColors.warningAmber` | `#FCBF49` | Íconos de "protector no disponible" o alertas suaves |
| `EcoColors.dangerRed` | `#E63946` | Solo para saldo insuficiente / errores reales |
| `EcoSpacing.element` / `stack` / `container` / `section` | 8 / 16 / 24 / 32 px | Ritmo vertical estándar |
| `EcoSpacing.touchTarget` | 48px | Alto mínimo de botones |
| `EcoRadius.lg` / `xl` / `x2l` | 8 / 12 / 16 px | Radios de cards y botones |
| Tipografía | Inter, escala en `_textTheme` | `headlineLarge` (26px/700) para números de impacto/racha, `bodySmall` (14px) para etiquetas |

No introducir colores nuevos (ej. dorado/oro para "hitos") sin verificar antes que no exista ya un token adecuado — preferir `EcoColors.primary`/`mintLight` para mantener la identidad de marca verde en vez de una paleta "de logros" separada.

---

## Accessibility & UX Notes

1. **Touch Targets**: todos los botones y cards interactivas ≥ 48px de alto.
2. **Contraste**: los números grandes de puntos/racha deben cumplir contraste AA sobre su fondo (ej. `onPrimaryContainer` sobre `primaryContainer`).
3. **Estados sin datos**: un usuario nuevo con racha en 0 y sin recompensas canjeadas no debe ver una pantalla vacía fría — usar copy motivador (ej. "Completa tu primer retiro para empezar tu racha").
4. **Diferenciación de modales**: el modal de hito (Screen 5) debe ser visualmente distinguible del modal rutinario de puntos (Screen 1) para que el usuario perciba la diferencia de logro sin leer el texto completo.
5. **Compartir en redes**: el botón de compartir debe generar una imagen/tarjeta resumen (no solo texto) para que sea atractiva al postearse.

---

## Integration Notes

- **Origen de datos de racha**: calculada bajo demanda desde `SolicitudRetiro.completada` / `AsignacionRetiro` según el rol (ver especificación funcional) — el diseño no debe asumir un contador cacheado, la UI debe poder mostrar un estado de carga breve al abrir el Panel de Impacto.
- **EcoPuntos compartidos**: el saldo y el catálogo de Screen 2 son los mismos para Ciudadano y Recolector — no diseñar catálogos separados por rol.
- **Trigger del modal de hito**: se dispara al detectar el cruce del umbral, típicamente al abrir la app tras el cierre de semana — el diseño debe contemplar que puede aparecer en cualquier pantalla de entrada (splash/home) como overlay.

---

## Future Enhancements (Out of Scope for v0.1)

- Tabla de posiciones / ranking entre usuarios (leaderboard).
- Insignias/badges coleccionables además de los bonos de puntos.
- Notificaciones push recordando reciclar antes de perder la racha (el proyecto no usa push notifications por ahora).
- Historial detallado de transacciones de EcoPuntos con filtros.

---

## Summary

El Flujo 3 tiene cuatro destinos de diseño:
1. **Modal de Acreditación** — refuerzo inmediato tras completar un retiro.
2. **Recompensas + Detalle/Canje** — vitrina y flujo de canje de EcoPuntos, compartido por ambos roles.
3. **Panel de Impacto y Racha** — pantalla ancla con huella ambiental, racha semanal y protectores.
4. **Modal de Hito de Racha** — celebración puntual al cruzar 2/4/8/12/26/52 semanas, distinta del modal rutinario de puntos.

Reutilizar los tokens de `app_theme.dart` en todo momento y mantener el mismo lenguaje de modal/confirmación ya establecido en el flujo del recolector (`picker-flow-design-prompt.md`) para que las tres experiencias (ciudadano, recolector, fidelización) se sientan como una sola app.
