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
```


# Flujo v0.1 — Vista Recolector (Tarea Principal)

## Tarea Única
**Aceptar y completar una solicitud de recolección cercana.**

---

## Diagrama del Flujo (Camino Feliz / Happy Path)

```text
[ Pantalla Principal: Mapa de Solicitudes ]
       │
       ▼
( 1. Tocar marcador de material en el mapa, ej. "Cartón" )
       │
       ▼
[ Tarjeta Inferior de Previsualización ]
       │
       ├──> Ver material, distancia (0 m) y condición (Gratis)
       │
       ▼
( 2. Tocar botón "Aceptar" )
       │
       ▼
[ Modal de Confirmación ]
       │
       ▼
( 3. Tocar botón "Sí, aceptar" )
       │
       ▼
[ Pantalla de Solicitud Aceptada ]
       │
       ├──> Opcional: Navegar con "Ir a Google Maps" o coordinar por "WhatsApp"
       │
       ▼
( 4. Tocar botón "✓ Marcar como completado" )
       │
       ▼
[ Pantalla de Historial ]
       │
       └──> Estado visible: Registro de retiro finalizado guardado con éxito