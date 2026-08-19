# Flujo v0.1 — Vista Ciudadano (Tarea Principal)

## Tarea Única
**Publicar una solicitud de retiro de reciclaje.**

---

## Diagrama del Flujo (Camino Feliz / Happy Path)

```text
[ Pantalla Principal ]
       │
       ▼
( 1. Tocar botón "+ Publicar Reciclaje" )
       │
       ▼
[ Pantalla de Formulario de Retiro ]
       │
       ├──> 2. Seleccionar material (ej. "Plástico")
       │
       ├──> 3. Tomar o subir foto de las bolsas/paquete
       │
       └──> 4. Confirmar punto GPS actual
       │
       ▼
( 5. Tocar botón "Publicar Solicitud" )
       │
       ▼
[ Pantalla de Confirmación / Estado ]
       │
       └──> Estado visible: "Buscando recolector cercano"