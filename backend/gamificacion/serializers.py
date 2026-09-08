from rest_framework import serializers

from .models import Canje, EventoPendiente, ProgresoRacha, Recompensa, SaldoEcoPuntos, TransaccionEcoPuntos
from .services import PROTECTORES_POR_MES, proximo_hito


class SaldoEcoPuntosSerializer(serializers.ModelSerializer):
    class Meta:
        model = SaldoEcoPuntos
        fields = ['saldo']


class TransaccionEcoPuntosSerializer(serializers.ModelSerializer):
    tipo_display = serializers.CharField(source='get_tipo_display', read_only=True)
    referencia = serializers.SerializerMethodField()

    class Meta:
        model = TransaccionEcoPuntos
        fields = ['id', 'tipo', 'tipo_display', 'puntos', 'referencia', 'creado_en']
        read_only_fields = fields

    def get_referencia(self, transaccion):
        if transaccion.solicitud_id:
            return transaccion.solicitud.get_tipo_material_display()
        if transaccion.racha_semanas:
            return f'Racha de {transaccion.racha_semanas} semanas'
        if transaccion.canje_id:
            return transaccion.canje.recompensa.nombre
        return ''


class RecompensaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Recompensa
        fields = [
            'id', 'nombre', 'descripcion', 'imagen', 'costo_puntos',
            'categoria', 'comercio_nombre',
        ]
        read_only_fields = fields


class CanjeSerializer(serializers.ModelSerializer):
    recompensa = RecompensaSerializer(read_only=True)

    class Meta:
        model = Canje
        fields = ['id', 'recompensa', 'puntos_gastados', 'codigo', 'creado_en']
        read_only_fields = fields


class ProgresoRachaSerializer(serializers.ModelSerializer):
    protectores_totales = serializers.SerializerMethodField()
    proximo_hito = serializers.SerializerMethodField()
    puntos_proximo_hito = serializers.SerializerMethodField()

    class Meta:
        model = ProgresoRacha
        fields = [
            'racha_actual', 'racha_maxima', 'protectores_disponibles',
            'protectores_totales', 'proximo_hito', 'puntos_proximo_hito',
        ]
        read_only_fields = fields

    def get_protectores_totales(self, progreso):
        return PROTECTORES_POR_MES

    def _hito_y_puntos(self, progreso):
        return proximo_hito(progreso.rol, progreso.racha_actual)

    def get_proximo_hito(self, progreso):
        hito, _ = self._hito_y_puntos(progreso)
        return hito

    def get_puntos_proximo_hito(self, progreso):
        _, puntos = self._hito_y_puntos(progreso)
        return puntos


class EventoPendienteSerializer(serializers.ModelSerializer):
    class Meta:
        model = EventoPendiente
        fields = ['id', 'tipo', 'payload', 'creado_en']
        read_only_fields = fields
