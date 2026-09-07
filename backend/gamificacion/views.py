from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Canje, EventoPendiente, ProgresoRacha, Recompensa, RolRacha, SaldoEcoPuntos, TransaccionEcoPuntos
from .serializers import (
    CanjeSerializer,
    EventoPendienteSerializer,
    ProgresoRachaSerializer,
    RecompensaSerializer,
    SaldoEcoPuntosSerializer,
    TransaccionEcoPuntosSerializer,
)
from .services import SaldoInsuficienteError, canjear_recompensa, obtener_impacto


def _rol_de(usuario):
    if usuario.groups.filter(name='Recolector').exists():
        return RolRacha.RECOLECTOR
    return RolRacha.CIUDADANO


class SaldoEcoPuntosView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        saldo = SaldoEcoPuntos.para_usuario(request.user)
        return Response(SaldoEcoPuntosSerializer(saldo).data)


class TransaccionEcoPuntosListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        queryset = TransaccionEcoPuntos.objects.filter(usuario=request.user)
        tipo = request.query_params.get('tipo')
        if tipo:
            queryset = queryset.filter(tipo=tipo)
        serializer = TransaccionEcoPuntosSerializer(queryset, many=True)
        return Response(serializer.data)


class RecompensaViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = RecompensaSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = Recompensa.objects.filter(activa=True)
        categoria = self.request.query_params.get('categoria')
        if categoria:
            queryset = queryset.filter(categoria=categoria)
        return queryset

    @action(detail=True, methods=['post'])
    def canjear(self, request, pk=None):
        try:
            canje, saldo_restante = canjear_recompensa(request.user, pk)
        except Recompensa.DoesNotExist:
            return Response({'error': 'Recompensa no encontrada'}, status=status.HTTP_404_NOT_FOUND)
        except SaldoInsuficienteError as error:
            return Response({'error': str(error)}, status=status.HTTP_409_CONFLICT)

        return Response(
            {'canje': CanjeSerializer(canje).data, 'saldo_restante': saldo_restante},
            status=status.HTTP_201_CREATED,
        )


class ProgresoRachaView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        rol = _rol_de(request.user)
        progreso, _ = ProgresoRacha.objects.get_or_create(
            usuario=request.user,
            rol=rol,
            defaults={'mes_protectores': timezone.localdate().replace(day=1)},
        )
        return Response(ProgresoRachaSerializer(progreso).data)


class ImpactoView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        rol = _rol_de(request.user)
        return Response(obtener_impacto(request.user, rol))


class EventoPendienteListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        eventos = EventoPendiente.objects.filter(usuario=request.user, visto_en__isnull=True)
        return Response(EventoPendienteSerializer(eventos, many=True).data)


class EventoPendienteMarcarVistoView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk=None):
        evento = get_object_or_404(EventoPendiente, pk=pk, usuario=request.user)
        if evento.visto_en is None:
            evento.visto_en = timezone.now()
            evento.save(update_fields=['visto_en'])
        return Response(status=status.HTTP_204_NO_CONTENT)
