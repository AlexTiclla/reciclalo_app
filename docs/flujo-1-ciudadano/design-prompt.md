# Prompt de Diseño — Prototipo v0.1 (Stitch)

Contexto para generar el primer prototipo interactivo en Stitch, cubriendo la vista Ciudadano y el flujo principal de publicación de una solicitud de retiro de reciclaje.

## Prompt para Stitch

```
Diseña el prototipo v0.1 de "Reciclalo", una app móvil que conecta a vecinos/comercios que generan material reciclable con recolectores que pasan a retirarlo. Esta primera versión cubre solo la vista Ciudadano (Generador).

Usuario objetivo: Carlos Méndez, 34 años, vecino y padre de familia en Santa Cruz. Separa botellas PET, latas y cartón en casa pero no tiene tiempo ni transporte para llevarlos a un centro de acopio. No conoce horarios ni rutas de recolectores, así que a veces termina tirando el material a la basura común por falta de espacio. Necesita una forma simple de avisar a un recolector que tiene material listo para retirar.

Estilo visual: limpio, cálido y confiable, con paleta orientada a reciclaje/ecología (verdes, tonos neutros), tipografía legible, iconografía simple. Pensado para uso rápido desde el celular, en la calle o en casa, sin fricción.

Genera las siguientes pantallas, conectadas como un flujo navegable:

1. Ingreso Rápido / Inicio de Sesión
   - Pantalla simple de acceso (login o ingreso rápido) que lleva a la Pantalla Principal.

2. Pantalla Principal (Home Ciudadano)
   - Sección "Mis Solicitudes Activas": tarjetas de solicitud mostrando estado (Pendiente / Aceptada / En camino).
   - Botón de acción principal, destacado: "+ Publicar Reciclaje".
   - Acceso a "Historial de Reciclaje" (lista de retiros completados).

3. Detalle de Solicitud (accesible desde una tarjeta de "Mis Solicitudes Activas")
   - Foto del material, tipo de residuo, datos del recolector asignado (si aplica).

4. Formulario de Solicitud de Retiro (se abre al tocar "+ Publicar Reciclaje")
   - Paso 1: Selección de tipo de material (Plástico / Cartón / Vidrio / Metal), selección única, visual con iconos.
   - Paso 2: Subir o tomar foto del paquete/bolsas.
   - Paso 3: Confirmación de ubicación (GPS automático, con opción de ajustar dirección).
   - Botón "Publicar Retiro" al final, siempre visible/accesible.

5. Pantalla de Confirmación / Estado
   - Se muestra después de tocar "Publicar Retiro".
   - Mensaje de estado claro: "Buscando recolector cercano".
   - Debe transmitir confianza de que la solicitud fue recibida.

6. Historial de Reciclaje
   - Lista de retiros completados, con fecha y tipo de material por cada ítem.

Flujo interactivo principal a simular (camino feliz):
Pantalla Principal → tocar "+ Publicar Reciclaje" → Formulario de Retiro (seleccionar material → tomar/subir foto → confirmar ubicación GPS) → tocar "Publicar Solicitud" → Pantalla de Confirmación mostrando "Buscando recolector cercano".

Todas las pantallas deben estar conectadas mediante los botones y elementos de navegación correspondientes, para poder recorrer este flujo de principio a fin en el prototipo interactivo.
```

## Notas de alcance (v0.1)

- Solo vista **Ciudadano/Generador**. La vista Recolector queda fuera de esta primera versión.
- No incluir: clasificación automática con IA, pagos/billetera digital, chat interno en tiempo real (fuera de alcance según `brief/brief-v0.2.0.md`).
- El flujo interactivo mínimo a validar en el prototipo es el de `persona/flujo-v0.1.md`: publicar una solicitud de retiro, de principio a fin.

## Referencias usadas

- `persona/persona.V0.1.md` — perfil y necesidades del usuario objetivo.
- `persona/app-map-v0.1.md` — jerarquía de pantallas de la vista Ciudadano.
- `persona/flujo-v0.1.md` — flujo (happy path) de publicación de solicitud de retiro.
