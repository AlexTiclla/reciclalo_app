# Flujo 5 — Recuperación de Contraseña: Design Prompt

## Overview

Diseñar las pantallas necesarias para que un usuario (Ciudadano o Recolector) que olvidó su contraseña pueda recuperarla siguiendo el **estándar de la industria: un código OTP de un solo uso enviado al correo registrado**. El usuario pide el código desde el Login, lo recibe por email, lo ingresa en la app y, si es válido, fija una contraseña nueva.

Este flujo agrega un punto de entrada nuevo a la pantalla de **Login** existente (link "¿Olvidaste tu contraseña?"). El campo de correo ya existe en el registro actual (`registro_screen.dart`, campo "Correo Electrónico"), así que no se requiere ningún cambio al flujo de Registro para soportar esto — a diferencia de la versión anterior de este documento, que dependía de teléfono + pregunta de seguridad capturados aparte.

---

## User Context

- **Roles**: Ciudadano/Comercio y Recolector — ambos usan el mismo flujo de recuperación, sin diferencias visuales por rol.
- **Momento de entrada**: desde el link "¿Olvidaste tu contraseña?" en el Login (pantalla vista en Figma, node 5:14 del archivo compartido).
- **Precondición**: el usuario debe tener un email válido asociado a su cuenta (ya se captura en registro). Si el correo quedó vacío por ser opcional a nivel de backend, ver Screen 3B (contingencia).
- **Device**: Mobile (390×844 viewport), consistente con el resto de la app.
- **Design System**: tokens reales de `frontend/lib/theme/app_theme.dart` — no inventar colores ni espaciados nuevos.

---

## Flow Overview

```text
Login ── "¿Olvidaste tu contraseña?" ──▶ Paso 1: Solicitar código
                                                │
                                                ▼
                                    Paso 2: Verificar código (OTP)
                                     │                    │
                              éxito  │                    │ código inválido/expirado
                                     ▼                    ▼
                        Paso 3: Nueva contraseña   (se queda en Paso 2, con
                                     │               opción de reenviar código)
                                     ▼
                        Paso 4: Confirmación de éxito
                                     │
                                     ▼
                                   Login
```

El flujo es lineal y siempre termina de vuelta en Login. A diferencia de la versión anterior (teléfono + pregunta de seguridad), aquí no hace falta una pantalla de contingencia separada como paso normal del flujo — el "reenviar código" cubre el caso de fallo, y solo se necesita un mensaje de ayuda si el correo no llegó (ver Screen 3B).

---

## Screen 1: Recuperar Contraseña — Solicitar Código

### Purpose

Punto de entrada: el usuario indica su usuario o correo para que se le envíe el código OTP.

### Key Elements

- **Header**: botón de volver (←) hacia Login, sin AppBar grande — mismo patrón minimal del Login.
- **Icono/ilustración** superior (sobre en verde/hoja) en `EcoColors.mintLight`.
- **Título**: "Recupera tu contraseña".
- **Subtítulo**: "Te enviaremos un código de verificación a tu correo registrado."
- **Campo "Usuario o correo"**: mismo estilo que el input de Login (icono persona o email).
- **Botón primario**: "Enviar código" (`FilledButton`, ancho completo, deshabilitado hasta que el campo no esté vacío).
- **Estado de carga**: al enviar, el botón muestra un spinner breve mientras el backend dispara el email — evitar que el usuario haga doble tap y dispare dos envíos.
- **Mensaje tras enviar**: navega directo a Screen 2 con un texto de confirmación arriba: "Enviamos un código a t***@correo.com" (correo parcialmente enmascarado, nunca completo, para no confirmar el email exacto a quien no sea el dueño de la cuenta).

### Design Notes

- **No enumeración de usuarios**: si el usuario/correo no existe, el comportamiento visual es idéntico (mismo mensaje de éxito, mismo avance a Screen 2) — el backend simplemente no envía nada en ese caso. El diseño no debe tener un estado de error tipo "usuario no encontrado".
- Reutilizar el mismo header sin AppBar que Login para consistencia visual.

---

## Screen 2: Recuperar Contraseña — Verificar Código (OTP)

### Purpose

Confirmar que quien pide el reseteo tiene acceso al correo registrado, ingresando el código OTP recibido.

### Key Elements

- **Título**: "Ingresa el código".
- **Subtítulo**: "Enviamos un código de 6 dígitos a t***@correo.com" (correo enmascarado, continuidad con Screen 1).
- **Input de OTP**: 6 casillas individuales tipo "code input" (un dígito por casilla, avance automático al siguiente campo, teclado numérico), en vez de un único campo de texto — es el patrón estándar de la industria para OTP y reduce errores de tecleo.
- **Temporizador de expiración**: texto pequeño tipo "El código expira en 09:47" con cuenta regresiva — deja claro que el código no es válido indefinidamente.
- **Link "Reenviar código"**: deshabilitado/atenuado mientras el temporizador de reenvío esté activo (ej. "Reenviar en 00:30"), se habilita al terminar. Evita spam de reenvíos.
- **Botón primario**: "Verificar" (`FilledButton`, ancho completo, se habilita solo cuando las 6 casillas están llenas).
- **Estado de error**: "Código incorrecto o expirado. Intenta de nuevo o solicita uno nuevo." — no distinguir entre "incorrecto" y "expirado" en el mensaje (mismo principio de no dar pistas de más), pero el temporizador visual ya le indica al usuario si expiró.
- **Estado de bloqueo** (tras varios intentos fallidos, ej. 5): reemplaza el formulario por un mensaje: "Por seguridad, bloqueamos los intentos por unos minutos." + botón "Volver a Login".

### Design Notes

- Este es el paso de seguridad central del flujo — el input de 6 casillas debe usar `EcoRadius.lg` y `EcoColors.outlineVariant` igual que el resto de inputs de la app, no un componente visualmente distinto.
- Reservar `EcoColors.dangerRed` solo para el estado de bloqueo, no para cada intento individual fallido (mismo criterio que otros flujos de error de la app).

---

## Screen 3A: Nueva Contraseña

### Purpose

Dejar que el usuario, ya verificado por el OTP, fije una contraseña nueva.

### Key Elements

- **Título**: "Crea tu nueva contraseña".
- **Campo "Nueva contraseña"**: icono de candado, igual que Login; toggle de mostrar/ocultar (icono de ojo).
- **Campo "Confirmar contraseña"**: mismo estilo.
- **Validaciones en vivo**: longitud mínima, coincidencia entre ambos campos — checklist sutil debajo del campo (ej. "✓ Mínimo 8 caracteres"), no solo error al enviar.
- **Botón primario**: "Guardar contraseña" (`FilledButton`, deshabilitado hasta que ambas validaciones pasen).

### Design Notes

- Mismo lenguaje visual de inputs que Login/Registro — no introducir un nuevo estilo de campo de contraseña.
- El OTP verificado en Screen 2 debe tratarse como un token de sesión de corta duración para este paso (el usuario no debe poder llegar a Screen 3A sin haber pasado Screen 2) — esto es una nota de integración, no cambia el diseño visual.

---

## Screen 3B: Contingencia — No llega el código

### Purpose

Salida de ayuda para el caso borde en que el correo registrado ya no es accesible para el usuario (cuenta antigua sin email, correo dado de baja, etc.) — evita dejarlo completamente varado, sin ser el camino principal del flujo.

### Key Elements

- **Punto de entrada**: un link discreto en Screen 2, del tipo "¿No te llegó el código? ¿Problemas con tu correo?" debajo del botón "Reenviar código" — no compite visualmente con el flujo normal de OTP.
- **Icono**: neutro (sobre con signo de interrogación en `EcoColors.mintLight`), no de error.
- **Título**: "¿No tienes acceso a tu correo?".
- **Cuerpo**: "Contáctanos por WhatsApp y te ayudamos a recuperar el acceso a tu cuenta."
- **Botón primario**: "Contactar por WhatsApp" — deep link de WhatsApp (mismo mecanismo ya usado en `services/maps_service.dart` para el flujo del recolector) con mensaje prellenado: "Hola, necesito ayuda para recuperar el acceso a mi cuenta. Mi usuario es: ___".
- **Botón secundario (texto)**: "Volver a Login".

### Design Notes

- A diferencia de la versión anterior del documento, esta pantalla ya no es el camino de verificación principal — es un escape hatch de baja frecuencia, por eso vive detrás de un link secundario y no como un paso del flujo lineal.

---

## Screen 4: Confirmación de Éxito

### Purpose

Cerrar el flujo con refuerzo positivo claro, mismo patrón que otros momentos de éxito de la app (ej. confirmación de canje en Flujo 3).

### Key Elements

- **Icono de check** grande sobre fondo `EcoColors.mintLight`.
- **Título**: "¡Contraseña actualizada!".
- **Cuerpo**: "Ya puedes iniciar sesión con tu nueva contraseña."
- **Botón primario**: "Ir a iniciar sesión" → Login.

### Design Notes

- Reutilizar el mismo patrón de pantalla de éxito ya usado en el Flujo 3 (canje de recompensas) para no introducir un tercer estilo de "success state" en la app.

---

## Design System Tokens (EcoRecicla — `app_theme.dart`)

| Token | Valor | Uso sugerido en este flujo |
|---|---|---|
| `EcoColors.primary` | `#0F5238` | Botones primarios, links ("¿Olvidaste tu contraseña?", "Reenviar código") |
| `EcoColors.mintLight` | `#D8F3DC` | Fondos de íconos en pantallas de estado (solicitud, contingencia, éxito) |
| `EcoColors.surface` | `#F8F9FA` | Fondo general de pantalla |
| `EcoColors.surfaceContainerLowest` | `#FFFFFF` | Fondo de inputs, casillas de OTP |
| `EcoColors.onSurface` | `#191C1D` | Texto principal, títulos, dígitos del OTP |
| `EcoColors.onSurfaceVariant` | `#404943` | Subtítulos, texto de ayuda, temporizador |
| `EcoColors.outlineVariant` | `#BFC9C1` | Bordes de inputs y casillas de OTP (igual que Login) |
| `EcoColors.dangerRed` | `#E63946` | Solo el estado de bloqueo por intentos, no errores individuales |
| `EcoSpacing.element` / `stack` / `container` / `section` | 8 / 16 / 24 / 32 px | Ritmo vertical estándar |
| `EcoSpacing.touchTarget` | 48px | Alto mínimo de botones e inputs |
| `EcoRadius.lg` | 8px | Bordes de inputs y casillas de OTP (igual que Login) |
| Tipografía | Inter | `headlineSmall`/`titleLarge` para títulos de paso, `bodyMedium` para subtítulos, `headlineLarge` monoespaciado-like para los dígitos del OTP |

No introducir un componente de "code input" visualmente distinto al resto de inputs de la app — mismas proporciones de borde/radio, solo cambia el layout (6 casillas en fila en vez de un input ancho).

---

## Accessibility & UX Notes

1. **No enumeración de usuarios/correos**: Screen 1 nunca confirma si el usuario o correo existe; el mensaje y el flujo son idénticos exista o no la cuenta.
2. **Touch targets**: inputs y botones ≥ 48px de alto; cada casilla del OTP también debe cumplir ≥ 48px para que sea cómoda de tocar en móvil.
3. **Teclado numérico automático**: las casillas de OTP deben abrir el teclado numérico del sistema, no el alfabético completo.
4. **Mostrar/ocultar contraseña**: obligatorio en ambos campos de Screen 3A.
5. **Reenvío con límite de frecuencia**: el temporizador de "Reenviar código" debe ser visible para que el usuario entienda por qué el botón está deshabilitado, no solo verlo gris sin explicación.
6. **Salida siempre disponible**: cada pantalla del flujo debe tener una forma de volver a Login sin completar el proceso.
7. **Accesibilidad del OTP**: las casillas deben anunciarse correctamente a lectores de pantalla como "dígito 1 de 6", etc., y permitir pegar el código completo desde el portapapeles (autofill de SMS/email code) en una sola acción en vez de forzar tecleo dígito por dígito.

---

## Integration Notes

- **Proveedor de email**: requiere una integración real de envío (ej. SendGrid, Amazon SES, o SMTP configurado en Django) — está fuera del alcance de este documento de diseño, pero condiciona el copy de Screen 1/2 ("revisa spam" podría agregarse como nota si el proveedor elegido lo amerita).
- **Expiración del OTP**: el diseño asume una ventana corta (ej. 10 minutos) reflejada en el temporizador de Screen 2 — el valor exacto lo define el backend, el diseño solo necesita mostrar la cuenta regresiva real que devuelva la API.
- **Rate limiting**: tanto el envío (Screen 1) como el reenvío (Screen 2) deben limitarse en backend (por usuario/IP) para evitar abuso de la bandeja de correo de terceros — el diseño refleja el estado resultante (botón deshabilitado con temporizador), no implementa la lógica.
- **Hash del OTP**: el código debe almacenarse hasheado o con TTL corto en el backend, nunca en texto plano persistente — nota de integración, no afecta el diseño visual.
- **Token de sesión entre Screen 2 y 3A**: verificar el OTP debe emitir un token de corta duración que autorice únicamente el cambio de contraseña, para que no sea posible saltar directo a Screen 3A sin pasar la verificación.
- **WhatsApp deep link (Screen 3B)**: reutilizar el mismo servicio/mecanismo que ya usa `maps_service.dart` para WhatsApp en el flujo del recolector, no crear una integración nueva.
- **Campo email en registro**: ya existe en `registro_screen.dart` (campo "Correo Electrónico") y en `RegistroUsuarioSerializer` (`backend/roles/serializers.py`), pero no es `required`/único a nivel de backend hoy. Si se quiere garantizar que todo usuario nuevo pueda usar este flujo, conviene endurecer ese campo a requerido y único en el backend — fuera del alcance visual de este documento, pero es un prerrequisito funcional real para que Screen 1 nunca caiga en el caso "no tengo correo".

---

## Future Enhancements (Out of Scope for v0.1)

- Autenticación de dos factores (2FA) reutilizando la misma infraestructura de OTP para el login normal, no solo para recuperación.
- Notificación de seguridad al correo cuando se cambia la contraseña exitosamente ("Si no fuiste tú, contáctanos").
- Verificación de correo obligatoria en el registro (confirmar email antes de poder usarlo como canal de recuperación).

---

## Summary

El Flujo 5 (versión OTP por email) agrega cinco pantallas nuevas, sin requerir cambios al Registro:

1. **Screen 1** — Solicitar código (usuario o correo).
2. **Screen 2** — Verificar código OTP de 6 dígitos, con temporizador de expiración y reenvío.
3. **Screen 3A** — Nueva contraseña.
4. **Screen 3B** — Contingencia (WhatsApp) para quien perdió acceso a su correo — escape hatch secundario, no paso principal.
5. **Screen 4** — Confirmación de éxito.

Todo el flujo reutiliza el lenguaje visual ya establecido en Login (inputs con icono, botón verde full-width) y en el Flujo 3 (patrón de pantalla de éxito), y el único componente nuevo real es el input de 6 casillas para el OTP, que debe mantener los mismos tokens de borde/radio que el resto de inputs de la app.
