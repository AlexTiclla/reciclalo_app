from decimal import Decimal, InvalidOperation

from django.db import transaction
from django.utils import timezone
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import AsignacionRetiro, EstadoSolicitud, Recolector, SolicitudRetiro
from .permissions import EsRecolector, PuedeVerSolicitud
from .serializers import (
    AsignacionRetiroSerializer,
    RecolectorPerfilSerializer,
    SolicitudRetiroPickerSerializer,
    SolicitudRetiroSerializer,
)
from .utils import bounding_box, distancia_km

RADIO_KM_POR_DEFECTO = 5.0

# Acciones del flujo del Recolector: operan sobre solicitudes de otros usuarios,
# así que no pueden usar el queryset "solo mis solicitudes" del Ciudadano.
ACCIONES_RECOLECTOR = {'cercanas', 'aceptar', 'rechazar', 'completar'}


def _coordenadas(datos, requeridas=True):
    """Lee y valida latitud/longitud de un dict de request. Devuelve Decimals."""
    latitud = datos.get('latitud')
    longitud = datos.get('longitud')

    if latitud in (None, '') or longitud in (None, ''):
        if requeridas:
            raise ValueError('latitud y longitud son requeridas')
        return None

    try:
        return Decimal(str(latitud)), Decimal(str(longitud))
    except (InvalidOperation, TypeError):
        raise ValueError('latitud y longitud deben ser números') from None


class RecolectorViewSet(viewsets.ViewSet):
    """
    Endpoints del propio Recolector autenticado.

    - `GET  /api/recolector/perfil/`
    - `POST /api/recolector/ubicacion/`
    - `POST /api/recolector/disponibilidad/`
    - `GET  /api/recolector/solicitudes-aceptadas/`
    - `GET  /api/recolector/solicitudes-completadas/`
    """

    permission_classes = [IsAuthenticated, EsRecolector]

    def _perfil(self):
        return Recolector.para_usuario(self.request.user)

    @action(detail=False, methods=['get'])
    def perfil(self, request):
        return Response(RecolectorPerfilSerializer(self._perfil()).data)

    @action(detail=False, methods=['post'])
    def ubicacion(self, request):
        try:
            latitud, longitud = _coordenadas(request.data)
        except ValueError as error:
            return Response({'error': str(error)}, status=status.HTTP_400_BAD_REQUEST)

        perfil = self._perfil()
        perfil.latitud_actual = latitud
        perfil.longitud_actual = longitud
        perfil.save(update_fields=['latitud_actual', 'longitud_actual', 'ultimo_ping'])

        return Response(RecolectorPerfilSerializer(perfil).data)

    @action(detail=False, methods=['post'])
    def disponibilidad(self, request):
        es_activo = request.data.get('es_activo')
        if not isinstance(es_activo, bool):
            return Response(
                {'error': 'es_activo es requerido y debe ser true o false'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        perfil = self._perfil()
        perfil.es_activo = es_activo
        perfil.save(update_fields=['es_activo', 'ultimo_ping'])

        return Response({'es_activo': perfil.es_activo})

    @action(detail=False, methods=['get'], url_path='solicitudes-aceptadas')
    def solicitudes_aceptadas(self, request):
        return self._listar_asignaciones(AsignacionRetiro.Estado.ACEPTADA)

    @action(detail=False, methods=['get'], url_path='solicitudes-completadas')
    def solicitudes_completadas(self, request):
        return self._listar_asignaciones(
            AsignacionRetiro.Estado.COMPLETADA, orden='-completada_en'
        )

    def _listar_asignaciones(self, estado, orden=None):
        perfil = self._perfil()
        asignaciones = AsignacionRetiro.objects.filter(
            recolector=perfil, estado=estado
        ).select_related('solicitud', 'solicitud__usuario')

        if orden:
            asignaciones = asignaciones.order_by(orden)

        contexto = self.get_contexto_ubicacion(perfil)
        serializer = AsignacionRetiroSerializer(
            asignaciones, many=True, context=contexto
        )
        return Response(serializer.data)

    def get_contexto_ubicacion(self, perfil):
        contexto = {'request': self.request}
        if perfil.latitud_actual is not None and perfil.longitud_actual is not None:
            contexto['ubicacion_recolector'] = (
                perfil.latitud_actual,
                perfil.longitud_actual,
            )
        return contexto


class SolicitudRetiroViewSet(viewsets.ModelViewSet):
    """
    CRUD de solicitudes de retiro.

    Flujo Ciudadano:
    - `GET /api/solicitudes/?estado=activas`     -> Mis Solicitudes Activas
    - `GET /api/solicitudes/?estado=completada`  -> Historial de Reciclaje
    - `POST /api/solicitudes/`                   -> Publicar Retiro

    Flujo Recolector:
    - `GET  /api/solicitudes/cercanas/?latitud=&longitud=&radio_km=`
    - `POST /api/solicitudes/{id}/aceptar/`
    - `POST /api/solicitudes/{id}/rechazar/`
    - `POST /api/solicitudes/{id}/completar/`
    """

    permission_classes = [IsAuthenticated]

    def get_permissions(self):
        if self.action in ACCIONES_RECOLECTOR:
            return [IsAuthenticated(), EsRecolector()]
        if self.action == 'retrieve':
            return [IsAuthenticated(), PuedeVerSolicitud()]
        return super().get_permissions()

    def get_serializer_class(self):
        if self.action in ACCIONES_RECOLECTOR or self._es_recolector():
            return SolicitudRetiroPickerSerializer
        return SolicitudRetiroSerializer

    def get_queryset(self):
        # Las acciones del recolector (y el detalle que abre desde el mapa)
        # necesitan ver solicitudes ajenas; `PuedeVerSolicitud` acota el acceso.
        if self.action in ACCIONES_RECOLECTOR or (
            self.action == 'retrieve' and self._es_recolector()
        ):
            return SolicitudRetiro.objects.select_related('usuario', 'recolector')

        queryset = SolicitudRetiro.objects.filter(usuario=self.request.user)

        estado = self.request.query_params.get('estado')
        if estado == 'activas':
            queryset = queryset.exclude(estado=EstadoSolicitud.COMPLETADA)
        elif estado:
            queryset = queryset.filter(estado=estado)

        return queryset

    def get_serializer_context(self):
        contexto = super().get_serializer_context()
        ubicacion = self._ubicacion_recolector()
        if ubicacion:
            contexto['ubicacion_recolector'] = ubicacion
        return contexto

    # --- Acciones del flujo Recolector -----------------------------------

    @action(detail=False, methods=['get'])
    def cercanas(self, request):
        """Solicitudes pendientes y sin recolector dentro del radio indicado."""
        try:
            latitud, longitud = _coordenadas(request.query_params)
            radio_km = float(request.query_params.get('radio_km') or RADIO_KM_POR_DEFECTO)
        except (ValueError, TypeError) as error:
            mensaje = str(error) if isinstance(error, ValueError) else 'radio_km inválido'
            return Response({'error': mensaje}, status=status.HTTP_400_BAD_REQUEST)

        if radio_km <= 0:
            return Response(
                {'error': 'radio_km debe ser mayor que 0'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        perfil = Recolector.para_usuario(request.user)
        perfil.latitud_actual = latitud
        perfil.longitud_actual = longitud
        perfil.save(update_fields=['latitud_actual', 'longitud_actual', 'ultimo_ping'])

        lat_min, lat_max, lng_min, lng_max = bounding_box(latitud, longitud, radio_km)
        candidatas = (
            self.get_queryset()
            .filter(
                estado=EstadoSolicitud.PENDIENTE,
                recolector__isnull=True,
                latitud__gte=lat_min,
                latitud__lte=lat_max,
                longitud__gte=lng_min,
                longitud__lte=lng_max,
            )
            # No volver a ofrecer lo que este recolector ya rechazó.
            .exclude(
                asignaciones__recolector=perfil,
                asignaciones__estado=AsignacionRetiro.Estado.RECHAZADA,
            )
        )

        # El bounding box deja pasar las esquinas del rectángulo: se descarta
        # con la distancia real y se ordena de la más cercana a la más lejana.
        origen = (latitud, longitud)
        medidas = [
            (distancia_km(origen, (s.latitud, s.longitud)), s) for s in candidatas
        ]
        cercanas = [s for distancia, s in sorted(medidas, key=lambda par: par[0])
                    if distancia <= radio_km]

        serializer = self.get_serializer(cercanas, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def aceptar(self, request, pk=None):
        perfil = Recolector.para_usuario(request.user)

        with transaction.atomic():
            # Bloqueo de fila: si dos recolectores aceptan a la vez, el segundo
            # lee la solicitud ya asignada y recibe 409 en lugar de pisarla.
            solicitud = (
                SolicitudRetiro.objects.select_for_update().filter(pk=pk).first()
            )
            if solicitud is None:
                return Response(
                    {'error': 'Solicitud no encontrada'},
                    status=status.HTTP_404_NOT_FOUND,
                )

            if solicitud.recolector_id is not None:
                return Response(
                    {'error': 'Esta solicitud ya fue aceptada por otro recolector'},
                    status=status.HTTP_409_CONFLICT,
                )

            solicitud.recolector = perfil
            solicitud.estado = EstadoSolicitud.ACEPTADA
            solicitud.save(update_fields=['recolector', 'estado', 'actualizado_en'])

            asignacion = AsignacionRetiro.objects.create(
                solicitud=solicitud,
                recolector=perfil,
                estado=AsignacionRetiro.Estado.ACEPTADA,
            )

        serializer = AsignacionRetiroSerializer(
            asignacion, context=self.get_serializer_context()
        )
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def rechazar(self, request, pk=None):
        solicitud = self.get_object()
        perfil = Recolector.para_usuario(request.user)

        asignacion = AsignacionRetiro.objects.create(
            solicitud=solicitud,
            recolector=perfil,
            estado=AsignacionRetiro.Estado.RECHAZADA,
            notas=request.data.get('motivo', ''),
        )

        serializer = AsignacionRetiroSerializer(
            asignacion, context=self.get_serializer_context()
        )
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def completar(self, request, pk=None):
        perfil = Recolector.para_usuario(request.user)

        with transaction.atomic():
            solicitud = (
                SolicitudRetiro.objects.select_for_update().filter(pk=pk).first()
            )
            if solicitud is None:
                return Response(
                    {'error': 'Solicitud no encontrada'},
                    status=status.HTTP_404_NOT_FOUND,
                )

            if solicitud.recolector_id != perfil.id:
                return Response(
                    {'error': 'No estás asignado a esta solicitud'},
                    status=status.HTTP_403_FORBIDDEN,
                )

            if solicitud.estado == EstadoSolicitud.COMPLETADA:
                return Response(
                    {'error': 'Esta solicitud ya está completada'},
                    status=status.HTTP_409_CONFLICT,
                )

            solicitud.estado = EstadoSolicitud.COMPLETADA
            solicitud.save(update_fields=['estado', 'actualizado_en'])

            asignacion = (
                AsignacionRetiro.objects.filter(
                    solicitud=solicitud,
                    recolector=perfil,
                    estado=AsignacionRetiro.Estado.ACEPTADA,
                ).first()
                or AsignacionRetiro(solicitud=solicitud, recolector=perfil)
            )
            asignacion.estado = AsignacionRetiro.Estado.COMPLETADA
            asignacion.completada_en = timezone.now()
            asignacion.save()

            Recolector.objects.filter(pk=perfil.pk).update(
                total_completadas=perfil.total_completadas + 1
            )

        serializer = AsignacionRetiroSerializer(
            asignacion, context=self.get_serializer_context()
        )
        return Response(serializer.data)

    # --- Helpers ---------------------------------------------------------

    def _es_recolector(self):
        usuario = self.request.user
        return (
            usuario.is_authenticated
            and usuario.groups.filter(name='Recolector').exists()
        )

    def _ubicacion_recolector(self):
        try:
            latitud, longitud = _coordenadas(self.request.query_params, requeridas=True)
            return latitud, longitud
        except (ValueError, TypeError):
            pass

        perfil = getattr(self.request.user, 'perfil_recolector', None)
        if perfil and perfil.latitud_actual is not None and perfil.longitud_actual is not None:
            return perfil.latitud_actual, perfil.longitud_actual
        return None
