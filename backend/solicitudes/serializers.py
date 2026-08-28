from rest_framework import serializers

from .models import AsignacionRetiro, Recolector, SolicitudRetiro
from .utils import distancia_km


class RecolectorResumenSerializer(serializers.ModelSerializer):
    """Datos mínimos del recolector que ve el Ciudadano en su solicitud."""

    nombre = serializers.SerializerMethodField()

    class Meta:
        model = Recolector
        fields = ['id', 'nombre']

    def get_nombre(self, recolector):
        usuario = recolector.usuario
        return usuario.get_full_name() or usuario.username


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
            'recolector',
            'creado_en',
            'actualizado_en',
        ]
        read_only_fields = ['id', 'estado', 'recolector', 'creado_en', 'actualizado_en']

    def create(self, validated_data):
        validated_data['usuario'] = self.context['request'].user
        return super().create(validated_data)


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
            'ciudadano_nombre',
            'recolector_info',
            'distancia_km',
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
        fields = ['id', 'solicitud', 'estado', 'aceptada_en', 'completada_en', 'notas']
        read_only_fields = fields
