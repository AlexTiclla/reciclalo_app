from django.db.models import Avg, Sum
from rest_framework import serializers

from .models import AsignacionRetiro, EstadoSolicitud, Recolector, SolicitudRetiro
from .utils import distancia_km


class RecolectorResumenSerializer(serializers.ModelSerializer):
    """Datos del recolector que ve el Ciudadano en su solicitud (Flujo 2 y 4)."""

    nombre = serializers.SerializerMethodField()
    calificacion_promedio = serializers.SerializerMethodField()

    class Meta:
        model = Recolector
        fields = ['id', 'nombre', 'telefono', 'foto', 'total_completadas', 'calificacion_promedio']

    def get_nombre(self, recolector):
        usuario = recolector.usuario
        return usuario.get_full_name() or usuario.username

    def get_calificacion_promedio(self, recolector):
        # AVG en SQL ya ignora las filas sin calificación (aceptadas/rechazadas
        # sin cerrar) — None si el recolector todavía no tiene ninguna.
        promedio = recolector.asignaciones.aggregate(promedio=Avg('calificacion'))['promedio']
        return round(promedio, 1) if promedio is not None else None


class RecolectorPerfilSerializer(serializers.ModelSerializer):
    """Perfil completo del recolector autenticado."""

    usuario_nombre = serializers.SerializerMethodField()

    class Meta:
        model = Recolector
        fields = [
            'id',
            'usuario_nombre',
            'es_activo',
            'latitud_actual',
            'longitud_actual',
            'telefono',
            'foto',
            'total_completadas',
            'ultimo_ping',
        ]
        read_only_fields = ['total_completadas', 'ultimo_ping']

    def get_usuario_nombre(self, recolector):
        usuario = recolector.usuario
        return usuario.get_full_name() or usuario.username


class SolicitudRetiroSerializer(serializers.ModelSerializer):
    """Serializer del flujo Ciudadano (crear / listar / ver mis solicitudes)."""

    recolector = RecolectorResumenSerializer(read_only=True)
    estado_coordinacion_display = serializers.CharField(
        source='get_estado_coordinacion_display', read_only=True
    )
    # Última posición conocida del recolector asignado (Flujo 4, Screen 3):
    # solo se expone al dueño de la solicitud, nunca en el serializer del
    # Recolector ni en `cercanas`.
    recolector_ubicacion = serializers.SerializerMethodField()
    # EcoPuntos ya acreditados por este retiro (Flujo 4, Screen 4) — se
    # acreditan en `completar()`, no aquí; este campo solo expone el monto
    # real para no inventar un número en la pantalla de calificación.
    puntos_acreditados = serializers.SerializerMethodField()
    # Calificación ya dada por el ciudadano a este retiro, si existe —
    # permite que Screen 4 se muestre en modo solo lectura al reabrirla.
    mi_calificacion = serializers.SerializerMethodField()

    class Meta:
        model = SolicitudRetiro
        fields = [
            'id',
            'tipo_material',
            'foto',
            'latitud',
            'longitud',
            'direccion_referencia',
            'precio',
            'telefono_contacto',
            'estado',
            'peso_kg',
            'recolector',
            'estado_coordinacion',
            'estado_coordinacion_display',
            'ventana_inicio',
            'ventana_fin',
            'notas_entrega',
            'franja_confirmada_en',
            'recolector_ubicacion',
            'puntos_acreditados',
            'mi_calificacion',
            'creado_en',
            'actualizado_en',
        ]
        read_only_fields = [
            'id', 'estado', 'peso_kg', 'recolector', 'estado_coordinacion',
            'ventana_inicio', 'ventana_fin', 'franja_confirmada_en', 'creado_en', 'actualizado_en',
        ]

    def create(self, validated_data):
        validated_data['usuario'] = self.context['request'].user
        return super().create(validated_data)

    def get_recolector_ubicacion(self, solicitud):
        request = self.context.get('request')
        if request is None or not getattr(request.user, 'is_authenticated', False):
            return None
        if request.user.id != solicitud.usuario_id:
            return None

        recolector = solicitud.recolector
        if recolector is None:
            return None
        if recolector.latitud_actual is None or recolector.longitud_actual is None:
            return None

        return {
            'latitud': recolector.latitud_actual,
            'longitud': recolector.longitud_actual,
            'actualizado_en': recolector.ultimo_ping,
        }

    def get_puntos_acreditados(self, solicitud):
        if solicitud.estado != EstadoSolicitud.COMPLETADA:
            return None

        # Import local para no acoplar `solicitudes` a `gamificacion` a nivel
        # de módulo — es el mismo patrón que ya usa `views.completar`.
        from gamificacion.models import TipoTransaccion, TransaccionEcoPuntos

        total = TransaccionEcoPuntos.objects.filter(
            solicitud=solicitud, tipo=TipoTransaccion.ACREDITACION
        ).aggregate(total=Sum('puntos'))['total']
        return total

    def _asignacion_completada(self, solicitud):
        return AsignacionRetiro.objects.filter(
            solicitud=solicitud, estado=AsignacionRetiro.Estado.COMPLETADA
        ).order_by('-completada_en').first()

    def get_mi_calificacion(self, solicitud):
        if solicitud.estado != EstadoSolicitud.COMPLETADA:
            return None

        asignacion = self._asignacion_completada(solicitud)
        if asignacion is None or asignacion.calificacion is None:
            return None

        return {
            'calificacion': asignacion.calificacion,
            'etiquetas': asignacion.calificacion_etiquetas,
            'comentario': asignacion.calificacion_comentario,
        }


class SolicitudRetiroPickerSerializer(serializers.ModelSerializer):
    """
    Vista de una solicitud para el flujo del Recolector.

    `distancia_km` se calcula contra la ubicación que el recolector envía en la
    request; si no hay ubicación en el contexto, el campo viaja como `null`.
    """

    tipo_material_display = serializers.CharField(
        source='get_tipo_material_display', read_only=True
    )
    estado_display = serializers.CharField(
        source='get_estado_display', read_only=True
    )
    estado_coordinacion_display = serializers.CharField(
        source='get_estado_coordinacion_display', read_only=True
    )
    recolector_info = RecolectorResumenSerializer(source='recolector', read_only=True)
    ciudadano_nombre = serializers.SerializerMethodField()
    distancia_km = serializers.SerializerMethodField()

    class Meta:
        model = SolicitudRetiro
        fields = [
            'id',
            'tipo_material',
            'tipo_material_display',
            'foto',
            'latitud',
            'longitud',
            'direccion_referencia',
            'precio',
            'telefono_contacto',
            'estado',
            'estado_display',
            'peso_kg',
            'ciudadano_nombre',
            'recolector_info',
            'distancia_km',
            # Coordinación de franja (Flujo 4) — el Recolector también la
            # necesita para renderizar su propio banner de estado en
            # `post_accept_screen.dart`.
            'estado_coordinacion',
            'estado_coordinacion_display',
            'ventana_inicio',
            'ventana_fin',
            'notas_entrega',
            'franja_confirmada_en',
            'creado_en',
        ]
        read_only_fields = fields

    def get_ciudadano_nombre(self, solicitud):
        usuario = solicitud.usuario
        return usuario.get_full_name() or usuario.username

    def get_distancia_km(self, solicitud):
        origen = self.context.get('ubicacion_recolector')
        if not origen:
            return None
        return distancia_km(origen, (solicitud.latitud, solicitud.longitud))


class AsignacionRetiroSerializer(serializers.ModelSerializer):
    solicitud = SolicitudRetiroPickerSerializer(read_only=True)

    class Meta:
        model = AsignacionRetiro
        fields = [
            'id', 'solicitud', 'estado', 'aceptada_en', 'completada_en', 'notas',
            'en_camino_en', 'llego_en',
            'calificacion', 'calificacion_etiquetas', 'calificacion_comentario',
        ]
        read_only_fields = fields
