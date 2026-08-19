# App Map v0.1 — Vista Ciudadano

## Estructura Jerárquica de Pantallas

```text
[ Ingreso Rápido / Inicio de Sesión ]
   │
   └── [ Pantalla Principal (Home Ciudadano) ]
          │
          ├── 1. Mis Solicitudes Activas
          │      ├── Tarjeta de Solicitud (Estado: Pendiente / Aceptada / En camino)
          │      └── Detalle de Solicitud (Foto, tipo de residuo, datos del recolector asignado)
          │
          ├── 2. Botón de Acción Principal (+ Publicar Reciclaje)
          │      │
          │      └── [ Formulario de Solicitud de Retiro ]
          │             ├── Selección de Tipo de Material (Plástico / Cartón / Vidrio / Metal)
          │             ├── Subir / Tomar Foto del Paquete
          │             ├── Confirmación de Ubicación (GPS automático / Dirección)
          │             └── Botón "Publicar Retiro"
          │
          └── 3. Historial de Reciclaje
                 └── Lista de retiros completados con fecha y tipo de material