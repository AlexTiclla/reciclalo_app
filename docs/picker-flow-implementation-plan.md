# Plan de Implementación — Flujo Recolector (Picker)

Implementación del flujo completo 0del **Recolector/Operador** (picker role) en la app EcoRecicla. Este documento define la arquitectura backend, endpoints API, modelos de datos, estructura frontend Flutter, y el flujo de integración end-to-end.

---

## 1. Resumen Ejecutivo

### Alcance de esta fase
- **Vista del Recolector**: Mapa interactivo mostrando solicitudes cercanas
- **Gestión de solicitudes**: Aceptar/rechazar, confirmar, navegar, marcar como completada
- **Integraciones externas**: WhatsApp (contacto), Google Maps (navegación)
- **Comunicación en tiempo real**: Actualizaciones de solicitudes disponibles

### Fuera de alcance
- Chat/mensajería integrada (se usa WhatsApp)
- Pagos o gestión de ingresos
- Historial detallado de recolecciones (MVP básico solo)
- Notificaciones push (versión posterior)
- Rating/reviews (versión posterior)

### Dependencias
- Modelos `SolicitudRetiro` y `User` (v0.1 ciudadano ya existen)
- API REST del backend disponible
- Base de datos PostgreSQL

---

## 2. Backend (Django)

### 2.1 Modelos de datos nuevos

Extender la app `solicitudes` (existente en v0.1) con nuevos modelos y campos.

#### 2.1.1 Modelo: `Recolector`
```python
# solicitudes/models.py

class Recolector(models.Model):
    """
    Perfil extendido del usuario que actúa como recolector.
    Almacena información específica del recolector (ubicación actual, estado de disponibilidad).
    """
    usuario = models.OneToOneField(
        User, 
        on_delete=models.CASCADE,
        related_name='perfil_recolector'
    )
    es_activo = models.BooleanField(default=False)
    # Ubicación actual (actualizada en tiempo real por el cliente)
    latitud_actual = models.DecimalField(
        max_digits=9, decimal_places=6, null=True, blank=True
    )
    longitud_actual = models.DecimalField(
        max_digits=9, decimal_places=6, null=True, blank=True
    )
    ultimo_ping = models.DateTimeField(auto_now=True)
    # Estadísticas básicas
    total_completadas = models.IntegerField(default=0)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Recolector"
        verbose_name_plural = "Recolectores"

    def __str__(self):
        return f"{self.usuario.get_full_name() or self.usuario.username} (Recolector)"
```

#### 2.1.2 Modelo: `AsignacionRetiro`
```python
class AsignacionRetiro(models.Model):
    """
    Registro de la aceptación de una solicitud por un recolector.
    Permite trackear el estado y la historia de aceptaciones/rechazos.
    """
    solicitud = models.ForeignKey(
        SolicitudRetiro,
        on_delete=models.CASCADE,
        related_name='asignaciones'
    )
    recolector = models.ForeignKey(
        Recolector,
        on_delete=models.CASCADE,
        related_name='asignaciones'
    )
    
    ESTADO_CHOICES = [
        ('aceptada', 'Aceptada'),
        ('completada', 'Completada'),
        ('rechazada', 'Rechazada'),
    ]
    estado = models.CharField(
        max_length=20, 
        choices=ESTADO_CHOICES, 
        default='aceptada'
    )
    
    # Timestamps
    aceptada_en = models.DateTimeField(auto_now_add=True)
    completada_en = models.DateTimeField(null=True, blank=True)
    
    # Notas opcionales (para debugging/soporte)
    notas = models.TextField(blank=True)
    
    class Meta:
        ordering = ['-aceptada_en']
        verbose_name = "Asignación de Retiro"
        verbose_name_plural = "Asignaciones de Retiro"

    def __str__(self):
        return f"{self.recolector.usuario.username} - {self.solicitud.id} ({self.estado})"
```

#### 2.1.3 Actualizar modelo: `SolicitudRetiro`
```python
class SolicitudRetiro(models.Model):
    # ... campos existentes (usuario, tipo_material, foto, latitud, longitud, etc.) ...
    
    # Agregar campos para recolector:
    recolector = models.ForeignKey(
        Recolector,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='solicitudes_asignadas'
    )
    
    # Campo para medir distancia aproximada (opcional, calculado en lectura)
    # O calcularse en tiempo de query si se tiene la ubicación actual del picker
```

### 2.2 Serializers

```python
# solicitudes/serializers.py

from rest_framework import serializers
from django.contrib.auth.models import User
from .models import SolicitudRetiro, Recolector, AsignacionRetiro

class RecolectorSerializer(serializers.ModelSerializer):
    usuario_nombre = serializers.CharField(
        source='usuario.get_full_name',
        read_only=True
    )
    
    class Meta:
        model = Recolector
        fields = [
            'id', 'usuario_nombre', 'es_activo', 
            'latitud_actual', 'longitud_actual', 'total_completadas'
        ]
        read_only_fields = ['total_completadas']

class SolicitudRetiroPickerSerializer(serializers.ModelSerializer):
    """
    Serializer optimizado para el flujo del recolector (picker).
    Incluye datos mínimos de la solicitud + recolector actual asignado.
    """
    tipo_material_display = serializers.CharField(
        source='get_tipo_material_display',
        read_only=True
    )
    estado_display = serializers.CharField(
        source='get_estado_display',
        read_only=True
    )
    recolector_info = RecolectorSerializer(
        source='recolector',
        read_only=True
    )
    distancia_km = serializers.SerializerMethodField()
    
    class Meta:
        model = SolicitudRetiro
        fields = [
            'id', 'tipo_material', 'tipo_material_display',
            'foto', 'latitud', 'longitud', 'direccion_referencia',
            'estado', 'estado_display',
            'recolector_info', 'distancia_km', 'creado_en'
        ]
        read_only_fields = ['id', 'foto', 'creado_en']
    
    def get_distancia_km(self, obj):
        """
        Calcula distancia aproximada desde la ubicación del recolector actual.
        Requiere 'recolector_latitud' y 'recolector_longitud' en el contexto de la request.
        """
        recolector_lat = self.context.get('recolector_latitud')
        recolector_lng = self.context.get('recolector_longitud')
        
        if not (recolector_lat and recolector_lng):
            return None
        
        # Usar fórmula de Haversine o librería como 'geopy'
        from geopy.distance import geodesic
        picker_coords = (recolector_lat, recolector_lng)
        request_coords = (float(obj.latitud), float(obj.longitud))
        
        return round(geodesic(picker_coords, request_coords).kilometers, 2)

class AsignacionRetiroSerializer(serializers.ModelSerializer):
    solicitud = SolicitudRetiroPickerSerializer(read_only=True)
    
    class Meta:
        model = AsignacionRetiro
        fields = ['id', 'solicitud', 'estado', 'aceptada_en', 'completada_en']
        read_only_fields = ['aceptada_en', 'completada_en']
```

### 2.3 API Endpoints

#### 2.3.1 Endpoints de autenticación (existente, puede expandirse)
```
POST /api/auth/login/ — Login (usuario + password)
POST /api/auth/logout/ — Logout
GET /api/auth/me/ — Obtener perfil del usuario actual
```

#### 2.3.2 Endpoints del Recolector (nuevos)

```
GET /api/recolector/perfil/
  Descripción: Obtener perfil del recolector actual (usuario autenticado).
  Respuesta: { usuario_nombre, es_activo, latitud_actual, longitud_actual, total_completadas }

POST /api/recolector/ubicacion/
  Descripción: Actualizar ubicación actual del recolector (ping con coordenadas).
  Payload: { latitud, longitud }
  Respuesta: { mensaje: "ubicación actualizada" }

POST /api/recolector/disponibilidad/
  Descripción: Cambiar disponibilidad del recolector (activo/inactivo).
  Payload: { es_activo: true/false }
  Respuesta: { es_activo: true/false }

GET /api/solicitudes/cercanas/?latitud={lat}&longitud={lng}&radio_km={km}
  Descripción: Listar solicitudes disponibles cercanas a la ubicación del recolector.
  Parámetros:
    - latitud, longitud: Ubicación actual del recolector
    - radio_km: Radio de búsqueda (default: 5 km)
  Respuesta: [
    {
      id, tipo_material, foto, latitud, longitud, direccion_referencia,
      estado, distancia_km, creado_en
    }
  ]
  Filtros implícitos: estado=pendiente (solo muestren solicitudes sin recolector)

GET /api/solicitudes/{id}/
  Descripción: Obtener detalle completo de una solicitud (ya existe en v0.1, expandir).
  Respuesta: {
    id, tipo_material, foto, latitud, longitud, direccion_referencia,
    estado, recolector_info (si aplica), creado_en, usuario_info (contacto)
  }

POST /api/solicitudes/{id}/aceptar/
  Descripción: Recolector acepta una solicitud.
  Payload: {} (o comentario opcional)
  Respuesta: { mensaje, asignacion: AsignacionRetiroSerializer }
  Cambios: SolicitudRetiro.estado → 'aceptada', SolicitudRetiro.recolector = recolector actual

POST /api/solicitudes/{id}/rechazar/
  Descripción: Recolector rechaza una solicitud.
  Payload: { motivo?: string } (opcional)
  Respuesta: { mensaje }
  Cambios: Crea un AsignacionRetiro con estado='rechazada' (sin cambiar estado de SolicitudRetiro)

POST /api/solicitudes/{id}/completar/
  Descripción: Marcar una solicitud aceptada como completada.
  Payload: {} (o foto de confirmación opcional)
  Respuesta: { mensaje, asignacion: AsignacionRetiroSerializer }
  Cambios: SolicitudRetiro.estado → 'completada', AsignacionRetiro.completada_en = now()

GET /api/recolector/solicitudes-aceptadas/
  Descripción: Listar solicitudes aceptadas por el recolector actual (filtro: estado=aceptada).
  Respuesta: [AsignacionRetiroSerializer]

GET /api/recolector/solicitudes-completadas/
  Descripción: Historial de solicitudes completadas por el recolector.
  Respuesta: [AsignacionRetiroSerializer] (filtro: estado=completada, ordenado por completada_en DESC)
```

### 2.4 Autenticación y permisos

```python
# solicitudes/permissions.py

from rest_framework.permissions import BasePermission

class EsRecolector(BasePermission):
    """
    Permite acceso solo a usuarios con perfil de recolector.
    """
    def has_permission(self, request, view):
        return (
            request.user and 
            request.user.is_authenticated and 
            hasattr(request.user, 'perfil_recolector')
        )

class EsSolicitudDelRecolectorOAutor(BasePermission):
    """
    Permite que un recolector solo acepte/rechace solicitudes disponibles (sin recolector).
    O que el autor de la solicitud pueda verla.
    """
    def has_object_permission(self, request, view, obj):
        # Recolector: puede ver/aceptar solo si la solicitud no tiene recolector
        if hasattr(request.user, 'perfil_recolector'):
            return obj.recolector is None or obj.recolector.usuario == request.user
        # Ciudadano: puede ver/editar solo si es el autor
        return obj.usuario == request.user
```

### 2.5 Views

```python
# solicitudes/views.py

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Q
from .models import SolicitudRetiro, Recolector, AsignacionRetiro
from .serializers import (
    SolicitudRetiroPickerSerializer, 
    RecolectorSerializer,
    AsignacionRetiroSerializer
)
from .permissions import EsRecolector, EsSolicitudDelRecolectorOAutor
from decimal import Decimal

class RecolectorViewSet(viewsets.ViewSet):
    """
    Endpoints del recolector: perfil, ubicación, disponibilidad.
    """
    permission_classes = [IsAuthenticated, EsRecolector]
    
    @action(detail=False, methods=['get'])
    def perfil(self, request):
        """Obtener perfil del recolector actual."""
        try:
            recolector = request.user.perfil_recolector
            serializer = RecolectorSerializer(recolector)
            return Response(serializer.data)
        except Recolector.DoesNotExist:
            return Response(
                {"error": "Usuario no tiene perfil de recolector"},
                status=status.HTTP_403_FORBIDDEN
            )
    
    @action(detail=False, methods=['post'])
    def ubicacion(self, request):
        """Actualizar ubicación actual del recolector."""
        try:
            recolector = request.user.perfil_recolector
        except Recolector.DoesNotExist:
            return Response(
                {"error": "Usuario no tiene perfil de recolector"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        latitud = request.data.get('latitud')
        longitud = request.data.get('longitud')
        
        if not (latitud and longitud):
            return Response(
                {"error": "latitud y longitud son requeridas"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            recolector.latitud_actual = Decimal(latitud)
            recolector.longitud_actual = Decimal(longitud)
            recolector.save()
            return Response({"mensaje": "Ubicación actualizada"})
        except Exception as e:
            return Response(
                {"error": str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    @action(detail=False, methods=['post'])
    def disponibilidad(self, request):
        """Cambiar disponibilidad del recolector."""
        try:
            recolector = request.user.perfil_recolector
        except Recolector.DoesNotExist:
            return Response(
                {"error": "Usuario no tiene perfil de recolector"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        es_activo = request.data.get('es_activo')
        if es_activo is None:
            return Response(
                {"error": "es_activo es requerido"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        recolector.es_activo = es_activo
        recolector.save()
        return Response({"es_activo": recolector.es_activo})
    
    @action(detail=False, methods=['get'])
    def solicitudes_aceptadas(self, request):
        """Listar solicitudes aceptadas por este recolector."""
        try:
            recolector = request.user.perfil_recolector
        except Recolector.DoesNotExist:
            return Response(
                {"error": "Usuario no tiene perfil de recolector"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        asignaciones = AsignacionRetiro.objects.filter(
            recolector=recolector,
            estado='aceptada'
        )
        serializer = AsignacionRetiroSerializer(asignaciones, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def solicitudes_completadas(self, request):
        """Historial de solicitudes completadas."""
        try:
            recolector = request.user.perfil_recolector
        except Recolector.DoesNotExist:
            return Response(
                {"error": "Usuario no tiene perfil de recolector"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        asignaciones = AsignacionRetiro.objects.filter(
            recolector=recolector,
            estado='completada'
        ).order_by('-completada_en')
        serializer = AsignacionRetiroSerializer(asignaciones, many=True)
        return Response(serializer.data)

class SolicitudRetiroViewSet(viewsets.ModelViewSet):
    """
    Endpoints de solicitudes. Expandido para soportar flujo de recolector.
    """
    queryset = SolicitudRetiro.objects.all()
    serializer_class = SolicitudRetiroPickerSerializer
    permission_classes = [IsAuthenticated]
    
    @action(detail=False, methods=['get'])
    def cercanas(self, request):
        """Listar solicitudes disponibles cercanas a ubicación del recolector."""
        if not hasattr(request.user, 'perfil_recolector'):
            return Response(
                {"error": "Usuario no tiene perfil de recolector"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        latitud = request.query_params.get('latitud')
        longitud = request.query_params.get('longitud')
        radio_km = float(request.query_params.get('radio_km', 5))
        
        if not (latitud and longitud):
            return Response(
                {"error": "latitud y longitud son requeridas"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Filtrar solicitudes pendientes (sin recolector)
        solicitudes = SolicitudRetiro.objects.filter(
            estado='pendiente',
            recolector__isnull=True
        )
        
        # Aquí se puede agregar filtrado por distancia usando la BD
        # (ej. con PostGIS si se usa PostgreSQL)
        # Por ahora, retornamos todas las pendientes y calculamos distancia en serializer
        
        serializer = self.get_serializer(
            solicitudes,
            many=True,
            context={
                'recolector_latitud': Decimal(latitud),
                'recolector_longitud': Decimal(longitud)
            }
        )
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def aceptar(self, request, pk=None):
        """Recolector acepta una solicitud."""
        if not hasattr(request.user, 'perfil_recolector'):
            return Response(
                {"error": "Usuario no tiene perfil de recolector"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        solicitud = self.get_object()
        
        # Validar que la solicitud esté disponible
        if solicitud.recolector is not None:
            return Response(
                {"error": "Solicitud ya ha sido aceptada por otro recolector"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        recolector = request.user.perfil_recolector
        
        # Actualizar solicitud
        solicitud.recolector = recolector
        solicitud.estado = 'aceptada'
        solicitud.save()
        
        # Crear asignación
        asignacion = AsignacionRetiro.objects.create(
            solicitud=solicitud,
            recolector=recolector,
            estado='aceptada'
        )
        
        serializer = AsignacionRetiroSerializer(asignacion)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    @action(detail=True, methods=['post'])
    def rechazar(self, request, pk=None):
        """Recolector rechaza una solicitud."""
        if not hasattr(request.user, 'perfil_recolector'):
            return Response(
                {"error": "Usuario no tiene perfil de recolector"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        solicitud = self.get_object()
        recolector = request.user.perfil_recolector
        
        # Crear asignación con estado rechazada (sin cambiar estado de solicitud)
        motivo = request.data.get('motivo', '')
        asignacion = AsignacionRetiro.objects.create(
            solicitud=solicitud,
            recolector=recolector,
            estado='rechazada',
            notas=motivo
        )
        
        serializer = AsignacionRetiroSerializer(asignacion)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    @action(detail=True, methods=['post'])
    def completar(self, request, pk=None):
        """Marcar solicitud como completada."""
        if not hasattr(request.user, 'perfil_recolector'):
            return Response(
                {"error": "Usuario no tiene perfil de recolector"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        solicitud = self.get_object()
        recolector = request.user.perfil_recolector
        
        # Validar que el recolector asignado es el actual
        if solicitud.recolector != recolector:
            return Response(
                {"error": "No estás asignado a esta solicitud"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Actualizar solicitud
        solicitud.estado = 'completada'
        solicitud.save()
        
        # Actualizar asignación
        asignacion = AsignacionRetiro.objects.get(
            solicitud=solicitud,
            recolector=recolector,
            estado='aceptada'
        )
        asignacion.estado = 'completada'
        asignacion.completada_en = timezone.now()
        asignacion.save()
        
        # Incrementar contador de completadas
        recolector.total_completadas += 1
        recolector.save()
        
        serializer = AsignacionRetiroSerializer(asignacion)
        return Response(serializer.data)
```

### 2.6 URLs

```python
# solicitudes/urls.py

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import RecolectorViewSet, SolicitudRetiroViewSet

router = DefaultRouter()
router.register(r'solicitudes', SolicitudRetiroViewSet)
router.register(r'recolector', RecolectorViewSet, basename='recolector')

urlpatterns = [
    path('', include(router.urls)),
]
```

### 2.7 Migraciones

```bash
cd backend
python manage.py makemigrations solicitudes
python manage.py migrate
python manage.py createsuperuser  # Crear usuarios de prueba (ciudadano + recolector)
```

### 2.8 Admin

```python
# solicitudes/admin.py

from django.contrib import admin
from .models import Recolector, AsignacionRetiro, SolicitudRetiro

@admin.register(Recolector)
class RecolectorAdmin(admin.ModelAdmin):
    list_display = ['usuario', 'es_activo', 'total_completadas', 'ultimo_ping']
    list_filter = ['es_activo', 'creado_en']
    search_fields = ['usuario__username', 'usuario__email']
    readonly_fields = ['ultimo_ping', 'total_completadas']

@admin.register(AsignacionRetiro)
class AsignacionRetiroAdmin(admin.ModelAdmin):
    list_display = ['recolector', 'solicitud', 'estado', 'aceptada_en']
    list_filter = ['estado', 'aceptada_en']
    search_fields = ['recolector__usuario__username', 'solicitud__id']
    readonly_fields = ['aceptada_en', 'completada_en']

# Extender SolicitudRetiroAdmin (si existe)
admin.site.unregister(SolicitudRetiro)
@admin.register(SolicitudRetiro)
class SolicitudRetiroAdmin(admin.ModelAdmin):
    list_display = ['id', 'usuario', 'tipo_material', 'estado', 'recolector', 'creado_en']
    list_filter = ['estado', 'tipo_material', 'creado_en']
    search_fields = ['usuario__username', 'id']
    readonly_fields = ['creado_en', 'actualizado_en']
```

### 2.9 Tareas backend (orden sugerido)

1. **Dependencias**: Agregar `geopy` a `requirements.txt` (para cálculo de distancia).
2. **Modelos**: Crear `Recolector`, `AsignacionRetiro`; actualizar `SolicitudRetiro`.
3. **Migraciones**: `makemigrations`, `migrate`.
4. **Serializers**: Implementar `RecolectorSerializer`, `SolicitudRetiroPickerSerializer`, `AsignacionRetiroSerializer`.
5. **Permisos**: Crear `EsRecolector`, `EsSolicitudDelRecolectorOAutor`.
6. **Views**: Implementar `RecolectorViewSet` y acciones en `SolicitudRetiroViewSet` (cercanas, aceptar, rechazar, completar).
7. **URLs**: Registrar routers en `urls.py`.
8. **Admin**: Registrar nuevos modelos en Django admin.
9. **Pruebas**: Validar endpoints con DRF browsable API, `curl`, o Postman.
10. **Datos de prueba**: Crear superusuario, ciudadanos y recolectores de prueba vía admin.

---

## 3. Frontend (Flutter)

### 3.1 Estructura de proyecto

Extender estructura existente de `lib/` con nuevas pantallas y servicios para recolector:

```
lib/
  main.dart
  screens/
    login_screen.dart           # Existente (v0.1)
    home_screen.dart            # Existente (v0.1)
    # ... otros (v0.1) ...
    
    # NUEVAS PANTALLAS RECOLECTOR:
    picker/
      picker_map_screen.dart            # Pantalla principal: mapa + pins
      request_details_screen.dart       # Detalle de solicitud + aceptar/rechazar
      confirmation_dialog.dart          # Diálogo de confirmación
      post_accept_screen.dart           # Después de aceptar: navegar + marcar hecho
      
  widgets/
    # Existentes (v0.1)
    # NUEVOS:
    picker/
      location_pin.dart                 # Widget del pin en el mapa
      request_card.dart                 # Card de preview de solicitud
      bottom_sheet_request.dart         # Bottom sheet expandible
      
  models/
    # Existentes (v0.1)
    # NUEVOS:
    recolector.dart                     # Modelo de Recolector
    asignacion_retiro.dart              # Modelo de AsignacionRetiro
    
  services/
    # Existentes (v0.1)
    # NUEVOS:
    picker_service.dart                 # API client para endpoints de recolector
    location_service.dart               # Gestión de ubicación en tiempo real (existente, expandir)
    maps_service.dart                   # Integración con Google Maps
    whatsapp_service.dart               # Integración con WhatsApp
```

### 3.2 Modelos Flutter

```dart
// lib/models/recolector.dart

class Recolector {
  final int id;
  final String usuarioNombre;
  final bool esActivo;
  final double? latitudActual;
  final double? longitudActual;
  final int totalCompletadas;

  Recolector({
    required this.id,
    required this.usuarioNombre,
    required this.esActivo,
    this.latitudActual,
    this.longitudActual,
    required this.totalCompletadas,
  });

  factory Recolector.fromJson(Map<String, dynamic> json) {
    return Recolector(
      id: json['id'] as int,
      usuarioNombre: json['usuario_nombre'] as String,
      esActivo: json['es_activo'] as bool,
      latitudActual: json['latitud_actual'] != null 
        ? double.parse(json['latitud_actual'].toString()) 
        : null,
      longitudActual: json['longitud_actual'] != null 
        ? double.parse(json['longitud_actual'].toString()) 
        : null,
      totalCompletadas: json['total_completadas'] as int,
    );
  }
}
```

```dart
// lib/models/asignacion_retiro.dart

class AsignacionRetiro {
  final int id;
  final SolicitudRetiro solicitud;
  final String estado; // 'aceptada', 'completada', 'rechazada'
  final DateTime aceptadaEn;
  final DateTime? completadaEn;

  AsignacionRetiro({
    required this.id,
    required this.solicitud,
    required this.estado,
    required this.aceptadaEn,
    this.completadaEn,
  });

  factory AsignacionRetiro.fromJson(Map<String, dynamic> json) {
    return AsignacionRetiro(
      id: json['id'] as int,
      solicitud: SolicitudRetiro.fromJson(json['solicitud']),
      estado: json['estado'] as String,
      aceptadaEn: DateTime.parse(json['aceptada_en'] as String),
      completadaEn: json['completada_en'] != null 
        ? DateTime.parse(json['completada_en'] as String) 
        : null,
    );
  }
}

// Asume que SolicitudRetiro existe en models/solicitud.dart
```

### 3.3 Servicios

```dart
// lib/services/picker_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/recolector.dart';
import '../models/asignacion_retiro.dart';
import 'api_client.dart';

class PickerService {
  final ApiClient apiClient;

  PickerService(this.apiClient);

  /// Obtener perfil del recolector actual
  Future<Recolector> obtenerPerfil() async {
    final response = await apiClient.get('/api/recolector/perfil/');
    if (response.statusCode == 200) {
      return Recolector.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener perfil');
    }
  }

  /// Actualizar ubicación actual
  Future<void> actualizarUbicacion(double latitud, double longitud) async {
    final response = await apiClient.post(
      '/api/recolector/ubicacion/',
      body: jsonEncode({
        'latitud': latitud,
        'longitud': longitud,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al actualizar ubicación');
    }
  }

  /// Cambiar disponibilidad
  Future<void> cambiarDisponibilidad(bool esActivo) async {
    final response = await apiClient.post(
      '/api/recolector/disponibilidad/',
      body: jsonEncode({'es_activo': esActivo}),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al cambiar disponibilidad');
    }
  }

  /// Obtener solicitudes cercanas
  Future<List<Map<String, dynamic>>> obtenerSolicitudesCercanas(
    double latitud,
    double longitud, {
    double radioKm = 5,
  }) async {
    final response = await apiClient.get(
      '/api/solicitudes/cercanas/?latitud=$latitud&longitud=$longitud&radio_km=$radioKm',
    );
    if (response.statusCode == 200) {
      List<dynamic> json = jsonDecode(response.body);
      return json.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Error al obtener solicitudes cercanas');
    }
  }

  /// Obtener detalle de una solicitud
  Future<Map<String, dynamic>> obtenerDetalleSolicitud(int solicitudId) async {
    final response = await apiClient.get('/api/solicitudes/$solicitudId/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al obtener detalle');
    }
  }

  /// Aceptar una solicitud
  Future<AsignacionRetiro> aceptarSolicitud(int solicitudId) async {
    final response = await apiClient.post(
      '/api/solicitudes/$solicitudId/aceptar/',
      body: '{}',
    );
    if (response.statusCode == 201) {
      return AsignacionRetiro.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Error al aceptar solicitud');
    }
  }

  /// Rechazar una solicitud
  Future<AsignacionRetiro> rechazarSolicitud(
    int solicitudId, {
    String motivo = '',
  }) async {
    final response = await apiClient.post(
      '/api/solicitudes/$solicitudId/rechazar/',
      body: jsonEncode({'motivo': motivo}),
    );
    if (response.statusCode == 201) {
      return AsignacionRetiro.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Error al rechazar solicitud');
    }
  }

  /// Marcar solicitud como completada
  Future<AsignacionRetiro> completarSolicitud(int solicitudId) async {
    final response = await apiClient.post(
      '/api/solicitudes/$solicitudId/completar/',
      body: '{}',
    );
    if (response.statusCode == 200) {
      return AsignacionRetiro.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Error al completar solicitud');
    }
  }

  /// Obtener solicitudes aceptadas
  Future<List<AsignacionRetiro>> obtenerSolicitudesAceptadas() async {
    final response = await apiClient.get('/api/recolector/solicitudes-aceptadas/');
    if (response.statusCode == 200) {
      List<dynamic> json = jsonDecode(response.body);
      return json.map((s) => AsignacionRetiro.fromJson(s)).toList();
    } else {
      throw Exception('Error al obtener solicitudes aceptadas');
    }
  }

  /// Obtener historial de solicitudes completadas
  Future<List<AsignacionRetiro>> obtenerHistorial() async {
    final response = await apiClient.get('/api/recolector/solicitudes-completadas/');
    if (response.statusCode == 200) {
      List<dynamic> json = jsonDecode(response.body);
      return json.map((s) => AsignacionRetiro.fromJson(s)).toList();
    } else {
      throw Exception('Error al obtener historial');
    }
  }
}
```

```dart
// lib/services/maps_service.dart

import 'package:url_launcher/url_launcher.dart';

class MapsService {
  /// Abrir Google Maps con ubicación de destino
  static Future<void> abrirGoogleMaps(
    double latitud,
    double longitud, {
    String? etiqueta,
  }) async {
    final query = Uri.encodeComponent('$latitud,$longitud');
    final label = Uri.encodeComponent(etiqueta ?? 'Destino');
    
    final googleUrl = 'https://www.google.com/maps/search/?api=1&query=$query';
    
    if (await canLaunchUrl(Uri.parse(googleUrl))) {
      await launchUrl(Uri.parse(googleUrl));
    } else {
      throw 'No se puede abrir Google Maps';
    }
  }
}
```

```dart
// lib/services/whatsapp_service.dart

import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  /// Abrir WhatsApp con mensaje pre-escrito
  /// 
  /// Nota: Requiere el número de teléfono del ciudadano.
  /// En v0.1, este número se obtiene del detalle de la solicitud (usuario).
  static Future<void> contactarViaWhatsApp(
    String numeroTelefono,
    String mensaje,
  ) async {
    // Formato: https://wa.me/{numero}?text={mensaje}
    final numeroLimpio = numeroTelefono.replaceAll(RegExp(r'[^\d+]'), '');
    final mensajeEncodificado = Uri.encodeComponent(mensaje);
    
    final whatsappUrl = 'https://wa.me/$numeroLimpio?text=$mensajeEncodificado';
    
    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
      await launchUrl(Uri.parse(whatsappUrl));
    } else {
      throw 'WhatsApp no está instalado o número no válido';
    }
  }
}
```

### 3.4 Pantallas

```dart
// lib/screens/picker/picker_map_screen.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/picker_service.dart';
import '../../services/location_service.dart';
import '../../models/recolector.dart';

class PickerMapScreen extends StatefulWidget {
  const PickerMapScreen({Key? key}) : super(key: key);

  @override
  State<PickerMapScreen> createState() => _PickerMapScreenState();
}

class _PickerMapScreenState extends State<PickerMapScreen> {
  late GoogleMapController mapController;
  final PickerService pickerService = PickerService(/* apiClient */);
  final LocationService locationService = LocationService();
  
  Position? currentPosition;
  List<Marker> markers = [];
  List<Map<String, dynamic>> solicitudes = [];
  Map<String, dynamic>? selectedSolicitud;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    // Obtener ubicación actual
    currentPosition = await locationService.obtenerUbicacionActual();
    
    // Actualizar ubicación en backend
    await pickerService.actualizarUbicacion(
      currentPosition!.latitude,
      currentPosition!.longitude,
    );
    
    // Obtener solicitudes cercanas
    await _cargarSolicitudesCercanas();
    
    setState(() {});
  }

  Future<void> _cargarSolicitudesCercanas() async {
    setState(() => isLoading = true);
    try {
      solicitudes = await pickerService.obtenerSolicitudesCercanas(
        currentPosition!.latitude,
        currentPosition!.longitude,
        radioKm: 5,
      );
      
      // Crear marcadores
      markers = solicitudes.asMap().entries.map((e) {
        int idx = e.key;
        Map<String, dynamic> s = e.value;
        return Marker(
          markerId: MarkerId(s['id'].toString()),
          position: LatLng(
            double.parse(s['latitud'].toString()),
            double.parse(s['longitud'].toString()),
          ),
          infoWindow: InfoWindow(
            title: s['tipo_material_display'],
            snippet: '${s['distancia_km']} km - \$${s.containsKey('precio') ? s['precio'] : 'Gratis'}',
          ),
          onTap: () => _mostrarDetalleSolicitud(s),
        );
      }).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _mostrarDetalleSolicitud(Map<String, dynamic> solicitud) {
    selectedSolicitud = solicitud;
    // Navegar a RequestDetailsScreen o mostrar bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestDetailsScreen(solicitud: solicitud),
      ),
    );
  }

  void _centrarEnMiUbicacion() {
    if (currentPosition != null) {
      mapController.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(currentPosition!.latitude, currentPosition!.longitude),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickups Nearby'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Chip(
              label: Text('${solicitudes.length} active'),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          if (currentPosition != null)
            GoogleMap(
              onMapCreated: (controller) => mapController = controller,
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  currentPosition!.latitude,
                  currentPosition!.longitude,
                ),
                zoom: 15,
              ),
              markers: Set.from(markers),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
            )
          else
            const Center(child: CircularProgressIndicator()),
          
          // Floating Action Button (compass)
          Positioned(
            bottom: 80,
            right: 16,
            child: FloatingActionButton(
              onPressed: _centrarEnMiUbicacion,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
```

```dart
// lib/screens/picker/request_details_screen.dart

import 'package:flutter/material.dart';
import '../../services/picker_service.dart';
import '../../services/whatsapp_service.dart';
import '../../services/maps_service.dart';

class RequestDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> solicitud;

  const RequestDetailsScreen({
    Key? key,
    required this.solicitud,
  }) : super(key: key);

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  late PickerService pickerService;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    pickerService = PickerService(/* apiClient */);
  }

  Future<void> _aceptarSolicitud() async {
    setState(() => isLoading = true);
    try {
      await pickerService.aceptarSolicitud(widget.solicitud['id']);
      
      if (!mounted) return;
      
      // Mostrar diálogo de confirmación
      _mostrarDialogoConfirmacion();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _rechazarSolicitud() async {
    // Navegar de vuelta
    Navigator.pop(context);
  }

  void _mostrarDialogoConfirmacion() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Aceptar esta solicitud?'),
        content: Text(
          '${widget.solicitud['tipo_material_display']}\n'
          '${widget.solicitud['distancia_km']} km away',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              // Navegar a PostAcceptScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PostAcceptScreen(
                    solicitud: widget.solicitud,
                  ),
                ),
              );
            },
            child: const Text('Sí, aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Imagen
            Container(
              width: double.infinity,
              height: 200,
              color: Colors.grey[300],
              child: widget.solicitud['foto'] != null
                  ? Image.network(
                      widget.solicitud['foto'],
                      fit: BoxFit.cover,
                    )
                  : const Icon(Icons.image, size: 80),
            ),
            
            // Detalles
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.solicitud['tipo_material_display'],
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '📍 ${widget.solicitud['distancia_km']} km away',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '\$${widget.solicitud.containsKey('precio') ? widget.solicitud['precio'] : 'Gratis'} en efectivo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Mapa pequeño
                  Container(
                    height: 150,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.location_on, size: 40),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // WhatsApp Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.message),
                      label: const Text('Contactar por WhatsApp'),
                      onPressed: () {
                        // Obtener número del ciudadano y contactar
                        WhatsAppService.contactarViaWhatsApp(
                          '+34600123456', // Obtener del API
                          '¿Dónde exactamente está el punto de recolección?',
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  Row(
                    gap: 8,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _aceptarSolicitud,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Aceptar'),
                        ),
                      ),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _rechazarSolicitud,
                          child: const Text('Rechazar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

```dart
// lib/screens/picker/post_accept_screen.dart

import 'package:flutter/material.dart';
import '../../services/picker_service.dart';
import '../../services/maps_service.dart';
import '../../services/whatsapp_service.dart';

class PostAcceptScreen extends StatefulWidget {
  final Map<String, dynamic> solicitud;

  const PostAcceptScreen({
    Key? key,
    required this.solicitud,
  }) : super(key: key);

  @override
  State<PostAcceptScreen> createState() => _PostAcceptScreenState();
}

class _PostAcceptScreenState extends State<PostAcceptScreen> {
  late PickerService pickerService;
  bool isCompleting = false;

  @override
  void initState() {
    super.initState();
    pickerService = PickerService(/* apiClient */);
  }

  Future<void> _marcarComoCompletada() async {
    setState(() => isCompleting = true);
    try {
      await pickerService.completarSolicitud(widget.solicitud['id']);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Solicitud completada!')),
      );
      
      // Navegar de vuelta al mapa
      Navigator.pop(context);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accepted'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Chip de estado
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Chip(
                label: const Text('Aceptado'),
                backgroundColor: Colors.green[100],
              ),
            ),
            
            // Mensaje de confirmación
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Text(
                    '¡Solicitud aceptada!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${widget.solicitud['tipo_material_display']} - '
                    '${widget.solicitud['distancia_km']} km away',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Mapa de ubicación
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 200,
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.location_on, size: 40),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Botones de acción
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                gap: 12,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.navigation),
                      label: const Text('Ir a Google Maps'),
                      onPressed: () {
                        MapsService.abrirGoogleMaps(
                          double.parse(widget.solicitud['latitud'].toString()),
                          double.parse(widget.solicitud['longitud'].toString()),
                          etiqueta: widget.solicitud['tipo_material_display'],
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.message),
                      label: const Text('Contactar por WhatsApp'),
                      onPressed: () {
                        WhatsAppService.contactarViaWhatsApp(
                          '+34600123456', // Obtener del API
                          '¿Dónde exactamente está el punto?',
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isCompleting ? null : _marcarComoCompletada,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: isCompleting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Marcar como completado'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 3.5 Dependencias (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Existentes (v0.1)
  http: ^1.1.0
  image_picker: ^1.0.0
  geolocator: ^9.0.0
  permission_handler: ^11.0.0
  provider: ^6.0.0
  go_router: ^7.0.0
  
  # NUEVOS para picker flow:
  google_maps_flutter: ^2.5.0
  url_launcher: ^6.1.0
  geopy: ^2.0.0 (opcional, si se calcula distancia en Flutter)

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0
```

### 3.6 Configuración de permisos (Android/iOS)

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Esta app necesita acceso a tu ubicación para mostrar solicitudes cercanas</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Esta app necesita acceso a tu ubicación para actualizar tu posición</string>
```

### 3.7 Navegación

Integrar las nuevas pantallas en el router (ej. usando `go_router`):

```dart
// lib/main.dart / router configuración

GoRouter(
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (_, __) => const HomeScreen(),
    ),
    // PICKER ROUTES
    GoRoute(
      path: '/picker/map',
      builder: (_, __) => const PickerMapScreen(),
    ),
    GoRoute(
      path: '/picker/request/:id',
      builder: (_, state) => RequestDetailsScreen(
        solicitud: state.extra as Map<String, dynamic>,
      ),
    ),
    GoRoute(
      path: '/picker/accepted/:id',
      builder: (_, state) => PostAcceptScreen(
        solicitud: state.extra as Map<String, dynamic>,
      ),
    ),
  ],
)
```

### 3.8 Tareas frontend (orden sugerido)

1. **Diseño visual**: Generar prototipos en Stitch (4 pantallas del picker).
2. **Dependencias**: Agregar `google_maps_flutter`, `url_launcher`, `geopy` a `pubspec.yaml`.
3. **Modelos**: Crear `Recolector`, `AsignacionRetiro`.
4. **Servicios**: Implementar `PickerService`, `MapsService`, `WhatsAppService`.
5. **Pantallas**: Implementar 4 pantallas (PickerMapScreen, RequestDetailsScreen, ConfirmationDialog, PostAcceptScreen).
6. **Navegación**: Integrar rutas en router.
7. **Permisos**: Configurar permisos de ubicación en Android/iOS.
8. **Testing**: `flutter analyze`, `flutter test`.
9. **Integración**: Conectar al backend real, validar flujo end-to-end.

---

## 4. Flujo end-to-end (Picker)

### Happy path

```
1. Picker abre app y hace login
2. Sistema obtiene su ubicación actual (GPS)
3. Navega a PickerMapScreen
   - Mapa muestra pins de solicitudes cercanas
   - Cada pin muestra material y precio
4. Tap en un pin → RequestDetailsScreen
   - Ver foto, descripción, ubicación
   - Ver precio (gratis o monto en efectivo)
   - Botón "Contactar por WhatsApp" (abre app)
5. Tap "Aceptar" → ConfirmationDialog
   - "¿Aceptar esta solicitud?"
   - Confirma detalles
6. Tap "Sí, aceptar" → PostAcceptScreen
   - Mensaje: "¡Solicitud aceptada!"
   - Botón "Ir a Google Maps" (abre navegación)
   - Botón "Contactar por WhatsApp" (pre-escrito: "¿Dónde está?")
   - Botón "Marcar como completado"
7. Pickup realizado → Tap "Marcar como completado"
   - Solicitud pasa a estado 'completada'
   - Recolector vuelve a PickerMapScreen

### Estados de solicitud (actualizado con picker flow)

```
pendiente → aceptada → completada
                    ↘ rechazada (no cambia estado de SolicitudRetiro)
```

---

## 5. Base de datos

### Cambios en schema (ER diagram actualizado)

```
User (existente)
├── Perfil de Recolector (1-to-1)
│   ├── es_activo
│   ├── latitud_actual, longitud_actual
│   └── total_completadas

SolicitudRetiro (existente, expandida)
├── recolector (FK a Recolector, nullable)
├── estado (pendiente, aceptada, en_camino, completada)
└── asignaciones (1-to-many a AsignacionRetiro)

AsignacionRetiro (nueva)
├── solicitud (FK)
├── recolector (FK)
├── estado (aceptada, completada, rechazada)
├── aceptada_en, completada_en
└── notas
```

---

## 6. Testing

### Backend

```bash
# Pruebas unitarias (models, serializers)
python manage.py test solicitudes.tests.TestRecolector
python manage.py test solicitudes.tests.TestAsignacionRetiro

# Pruebas de integración (endpoints)
python manage.py test solicitudes.tests.TestPickerAPI

# Manual (DRF browsable API)
python manage.py runserver
# Navegar a http://localhost:8000/api/
```

### Frontend

```bash
# Tests de widgets
flutter test test/screens/picker/picker_map_screen_test.dart

# Tests de servicios
flutter test test/services/picker_service_test.dart

# Análisis estático
flutter analyze

# Build
flutter build apk  # Android
flutter build ios  # iOS
```

---

## 7. Cronograma sugerido (orden de implementación)

| Fase | Duración | Tareas |
|------|----------|--------|
| **1. Backend - Modelos** | 2-3 días | Crear Recolector, AsignacionRetiro; actualizar SolicitudRetiro; migraciones |
| **2. Backend - API** | 3-4 días | Serializers, viewsets, endpoints, permisos; testing manual |
| **3. Frontend - Setup** | 1-2 días | Dependencias, modelos, servicios (PickerService, MapsService, WhatsAppService) |
| **4. Frontend - Pantallas** | 4-5 días | PickerMapScreen, RequestDetailsScreen, PostAcceptScreen; navegación |
| **5. Frontend - Integración** | 2-3 días | Conectar servicios al backend real; validar flujo; permisos |
| **6. Testing & Refinement** | 2-3 días | Tests, bug fixes, optimizaciones |
| **7. Documentación** | 1 día | README, guía de setup, guía de uso |

**Total estimado**: 2-3 semanas (team size: 1-2 devs)

---

## 8. Consideraciones futuras

- **Real-time updates**: WebSocket o Server-Sent Events para notificaciones de nuevas solicitudes
- **Notificaciones push**: Firebase Cloud Messaging
- **Analytics**: Trackear aceptaciones/rechazos por recolector, tiempo promedio de completación
- **Rating/Reviews**: Sistema de calificación entre ciudadanos y recolectores
- **Pagos**: Integración de billetera digital (v0.2+)
- **Historial detallado**: Reportes de recolecciones, ganancias, tendencias

---

## 9. Notas de implementación

1. **Ubicación en tiempo real**: El picker debe actualizar su ubicación frecuentemente (cada 30-60 seg) cuando está activo. Considerar batería + rendimiento.
2. **Distancia**: Usar Haversine o PostGIS (si PostgreSQL soporta) para filtrar por radio. Alternativamente, calcular en cliente.
3. **Solicitudes expiradas**: Implementar lógica para marcar solicitudes como expiradas si no se aceptan en X tiempo.
4. **Concurrencia**: Manejo de race conditions cuando múltiples pickers intentan aceptar la misma solicitud.
5. **WhatsApp integration**: Usar deep linking; número del ciudadano debe estar disponible en API (agregar a modelo de Usuario si no existe).
6. **Google Maps**: Requiere API key; configurar en Android/iOS.
7. **Documentación API**: Generar con `drf-spectacular` o similar.

---

## Referencias

- Documento de diseño: `docs/picker-flow-design-prompt.md`
- Persona del recolector: `persona/` (agregar si aún no existe)
- Brief del producto: `brief/brief-v0.2.0.md`
- Implementación del ciudadano: `docs/implementation-plan-v0.1.md`
