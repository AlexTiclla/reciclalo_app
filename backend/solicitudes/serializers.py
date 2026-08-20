from rest_framework import serializers

from .models import SolicitudRetiro


class RecolectorSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    nombre = serializers.SerializerMethodField()

    def get_nombre(self, user):
        return user.get_full_name() or user.username


class SolicitudRetiroSerializer(serializers.ModelSerializer):
    recolector = RecolectorSerializer(read_only=True)

    class Meta:
        model = SolicitudRetiro
        fields = [
            'id',
            'tipo_material',
            'foto',
            'latitud',
            'longitud',
            'direccion_referencia',
            'estado',
            'recolector',
            'creado_en',
            'actualizado_en',
        ]
        read_only_fields = ['id', 'estado', 'recolector', 'creado_en', 'actualizado_en']

    def create(self, validated_data):
        validated_data['usuario'] = self.context['request'].user
        return super().create(validated_data)
