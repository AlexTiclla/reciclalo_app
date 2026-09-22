# Flujo 4 — Rediseño de Screen 4: de "confirmación + calificación" a solo calificación

## Prompt para Google Stitch

### Overview

Rediseñar la cuarta pantalla del flujo de **coordinación y seguimiento de retiro** de EcoRecicla: la pantalla que ve el Ciudadano cuando el Recolector ya registró el retiro como completado. Antes pedía una confirmación explícita del Ciudadano antes de acreditar EcoPuntos; ahora los EcoPuntos **ya fueron acreditados** en el momento en que el Recolector completó el retiro, así que esta pantalla deja de ser un paso de validación y pasa a ser **una pantalla de cierre y calificación**: informa qué se registró y, opcionalmente, invita a calificar al recolector.

Diseñar para el rol **Ciudadano/Generador**, mobile, viewport 390 × 844 px, español (Bolivia), mismo estilo sobrio y cálido de EcoRecicla. Reutilizar únicamente los tokens reales de `frontend/lib/theme/app_theme.dart` (ver tabla de tokens abajo) — misma paleta y tipografía que las otras 3 pantallas del flujo.

### User Context

- Usuario: Ciudadano o comercio que ya coordinó y siguió su retiro (Screens 1–3 de este mismo flujo).
- Momento de entrada: al abrir desde "Mis solicitudes activas" o Historial una solicitud cuyo retiro el Recolector ya completó. No hay nada pendiente de validar — los EcoPuntos ya están en la cuenta del usuario.
- Marca: EcoRecicla; debe sentirse parte de la misma app que Publicar Reciclaje, Historial, Recompensas y Mi Impacto, y consistente con las otras 3 pantallas de este flujo (mismo header, mismo ícono de perfil arriba a la derecha).

### Key Elements

- **Header**: botón cerrar (✕) y título "Retiro completado". Ícono de ayuda y de perfil arriba a la derecha, igual que en las otras 3 pantallas del flujo.
- **Hero positivo**: círculo `mintLight` con ícono de check, título "¡Tu material ya fue recogido!" y texto de agradecimiento: "Gracias por darle una nueva vida a tus reciclables."
- **Resumen de retiro** (tarjeta, informativo — no hay ninguna acción de confirmar sobre estos datos, ya están cerrados):
  - Recolector: avatar + "Carlos R." + chip "Verificado".
  - Material: "Plástico PET".
  - Peso registrado: "3.5 kg".
  - Fecha/hora: "Jueves 12 · 16:20".
- **Chip o línea destacada de EcoPuntos ya acreditados**: por ejemplo "✓ +35 EcoPuntos acreditados a tu cuenta" en un bloque `mintLight`/`secondaryContainer` — deja claro, sin ambigüedad, que esto ya ocurrió (no depende de nada que el usuario haga en esta pantalla).
- **Calificación** (sección principal de la pantalla, no un bloque secundario):
  - Encabezado: "¿Cómo fue tu experiencia con Carlos?"
  - Texto de apoyo: "Tu opinión reconoce el trabajo del reciclador de tu barrio."
  - Cinco estrellas grandes (objetivo táctil ≥48×48 px), con etiqueta de apoyo según la selección ("Mala" a "Excelente", como en el mock anterior).
  - Chips de etiquetas rápidas seleccionables (multi-selección): "Puntual", "Amable y respetuoso", "Cuidado del material".
  - Campo de texto opcional: "Cuéntanos más (opcional)", con contador "Máx. 200 caracteres".
- **CTA final**:
  - Primario, ancho completo: "Enviar calificación" — habilitado solo si se eligió al menos una estrella. Al enviarla, vuelve a Inicio o muestra una confirmación breve tipo snackbar ("¡Gracias por tu calificación!").
  - Secundario, texto/enlace: "Ahora no" — permite salir sin calificar; no bloquea ni condiciona nada (los puntos ya están acreditados de todas formas).
- **No incluir**: pregunta de confirmación del retiro, botón "Sí, confirmar retiro", ni "Necesito reportar un problema". Esta pantalla no valida ni disputa nada — solo informa y califica.

### Interaction and State

- La calificación es completamente opcional; "Ahora no" siempre está disponible con el mismo peso visual secundario que en el resto de la app (no es un botón oculto ni penalizado).
- No hay ningún estado de "pendiente de confirmación" — la pantalla siempre representa un retiro ya cerrado.
- Si el usuario ya calificó antes (reabre la pantalla desde Historial), mostrar la calificación ya dada en modo solo lectura en vez del selector interactivo.

### Design Notes

- El tono es de cierre calmado y agradecido, no de celebración de puntos — esa celebración específica (el conteo animado, "+N EcoPuntos") vive en el modal de acreditación del Flujo 3, no aquí. El bloque de "EcoPuntos acreditados" de esta pantalla es informativo y discreto, no el protagonista visual.
- Evitar cualquier lenguaje que implique que falta una acción del usuario para que el retiro "cuente" (nada de "confirma para...", "libera tus puntos", etc.) — todo lo que se muestra ya es un hecho consumado.
- Mantener la misma jerarquía tipográfica y espaciado (`EcoSpacing.element/stack/container/section`) que las otras 3 pantallas del flujo.

### Design System Tokens (EcoRecicla)

| Token | Valor | Uso en esta pantalla |
| --- | --- | --- |
| `EcoColors.primary` | `#0F5238` | CTA "Enviar calificación", estrellas seleccionadas |
| `EcoColors.mintLight` | `#D8F3DC` | Fondo del ícono de check del hero, bloque de EcoPuntos acreditados |
| `EcoColors.secondaryContainer` | `#B0F1CC` | Chips de etiquetas seleccionadas |
| `EcoColors.surface` | `#F8F9FA` | Fondo general |
| `EcoColors.surfaceContainerLowest` | `#FFFFFF` | Cards principales |
| `EcoColors.surfaceContainerLow` | `#F3F4F5` | Card de resumen de retiro |
| `EcoColors.onSurface` | `#191C1D` | Texto principal |
| `EcoColors.onSurfaceVariant` | `#404943` | Texto descriptivo y metadata |
| `EcoColors.outlineVariant` | `#BFC9C1` | Bordes, separadores |
| `EcoSpacing.element / stack / container / section` | `8 / 16 / 24 / 32 px` | Ritmo vertical |
| `EcoSpacing.touchTarget` | `48 px` | Alto mínimo de estrellas, chips y botones |
| `EcoRadius.lg / xl / x2l` | `8 / 12 / 16 px` | Radios de campos, cards y contenedores |
| Tipografía | Inter | `headlineLarge` para el hero; `bodySmall` para metadata |

### Accessibility & UX Notes

1. Todos los objetivos táctiles (estrellas, chips, botones) miden al menos 48 × 48 px.
2. Contraste AA para texto y CTAs, especialmente texto claro sobre verde.
3. El bloque de EcoPuntos acreditados debe leerse como un hecho pasado (ej. "acreditados", no "se acreditarán").
4. Usar fecha y hora completas e inequívocas ("Jueves 12 · 16:20"), no relativas.

### Scope Boundaries

- **In scope**: resumen de lo ya registrado, indicación clara de que los EcoPuntos ya se acreditaron, calificación opcional de 1 a 5 estrellas con etiquetas y comentario libre.
- **Out of scope**: cualquier pregunta de confirmación/validación del retiro, reporte de problemas, chat, pagos, rediseño del modal de EcoPuntos del Flujo 3 (se sigue abriendo desde otro lado, no desde aquí).

### Deliverable Request for Google Stitch

Regenerar **solo** la pantalla "Retiro completado y calificación" (`retiro_completado_y_calificaci_n`) del prototipo existente de EcoRecicla, reemplazándola por la versión descrita arriba — quitando el bloque de confirmación ("¿Se realizó el retiro correctamente?" / "Sí, confirmar retiro" / "Necesito reportar un problema") y dejando la calificación como contenido principal de la pantalla, con el resumen del retiro y el aviso de EcoPuntos ya acreditados como contexto arriba. Mantener las otras 3 pantallas del flujo (`elegir_franja_de_retiro`, `retiro_confirmado`, `seguimiento_del_retiro`) sin cambios y usar los mismos datos de demostración ya establecidos: solicitud de **Plástico PET**, recolector **Carlos R.**, horario **jueves 12, 15:00–18:00**, peso final **3.5 kg**.
