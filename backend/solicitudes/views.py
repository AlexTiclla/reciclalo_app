from decimal import Decimal, InvalidOperation

from django.db import transaction
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import (
    AsignacionRetiro,
    EstadoCoordinacion,
    EstadoSolicitud,
    Recolector,
    SolicitudRetiro,
)
from .permissions import EsRecolector, PuedeVerSolicitud
from .serializers import (
    AsignacionRetiroSerializer,
    RecolectorPerfilSerializer,
    SolicitudRetiroPickerSerializer,
    SolicitudRetiroSerializer,
)
from .utils import bounding_box, distancia_km

RADIO_KM_POR_DEFECTO = 5.0
ETIQUETAS_CALIFICACION_MAX = 5
ETIQUETA_CALIFICACION_LONGITUD_MAX = 30

# Acciones del flujo del Recolector: operan sobre solicitudes de otros usuarios,
# así que no pueden usar el queryset "solo mis solicitudes" del Ciudadano.
ACCIONES_RECOLECTOR = {'cercanas', 'aceptar', 'rechazar', 'completar', 'en_camino'}

# Coordinación de franja (Flujo 4): las dos partes pueden llamarlas, así que no
# encajan en el set anterior (permiso de clase EsRecolector) ni en el queryset
# "solo mis solicitudes" del Ciudadano cuando quien llama es el Recolector.
ACCIONES_COORDINACION = {'proponer_franja', 'aceptar_franja'}


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
    def telefono(self, request):
        """Teléfono de contacto que el Ciudadano ve en las Screens 2/3 del Flujo 4."""
        telefono = str(request.data.get('telefono') or '').strip()
        perfil = self._perfil()
        perfil.telefono = telefono
        perfil.save(update_fields=['telefono'])
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
        # Las de coordinación las puede llamar cualquiera de las dos partes: si
        # quien llama es el Recolector, necesita el mismo queryset ampliado.
        if self.action in ACCIONES_RECOLECTOR or (
            self.action in ({'retrieve'} | ACCIONES_COORDINACION) and self._es_recolector()
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

    # --- Coordinación de franja horaria (Flujo 4) --------------------------

    @action(detail=True, methods=['post'], url_path='proponer-franja')
    def proponer_franja(self, request, pk=None):
        """
        Cualquiera de las dos partes (Ciudadano dueño o Recolector asignado)
        propone una ventana de retiro. La última propuesta reemplaza a la
        anterior; `aceptar_franja` es lo que la confirma.
        """
        solicitud = self.get_object()
        es_ciudadano = solicitud.usuario_id == request.user.id
        es_recolector = self._recolector_asignado(solicitud)

        if not es_ciudadano and not es_recolector:
            return Response(
                {'error': 'No participás en esta solicitud'},
                status=status.HTTP_403_FORBIDDEN,
            )

        if solicitud.estado not in (EstadoSolicitud.ACEPTADA, EstadoSolicitud.EN_CAMINO):
            return Response(
                {'error': 'La solicitud no admite coordinar una franja en este estado'},
                status=status.HTTP_409_CONFLICT,
            )

        inicio = parse_datetime(str(request.data.get('ventana_inicio') or ''))
        fin = parse_datetime(str(request.data.get('ventana_fin') or ''))
        if inicio is None or fin is None:
            return Response(
                {'error': 'ventana_inicio y ventana_fin son requeridas (ISO 8601)'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if timezone.is_naive(inicio):
            inicio = timezone.make_aware(inicio)
        if timezone.is_naive(fin):
            fin = timezone.make_aware(fin)
        if fin <= inicio:
            return Response(
                {'error': 'ventana_fin debe ser posterior a ventana_inicio'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if inicio < timezone.now():
            return Response(
                {'error': 'La franja no puede estar en el pasado'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        solicitud.ventana_inicio = inicio
        solicitud.ventana_fin = fin
        solicitud.estado_coordinacion = (
            EstadoCoordinacion.PROPUESTA_CIUDADANO
            if es_ciudadano
            else EstadoCoordinacion.PROPUESTA_RECOLECTOR
        )
        campos = ['ventana_inicio', 'ventana_fin', 'estado_coordinacion', 'actualizado_en']

        # Las indicaciones para el recolector solo las escribe el ciudadano.
        if es_ciudadano and 'notas_entrega' in request.data:
            solicitud.notas_entrega = str(request.data.get('notas_entrega') or '')[:280]
            campos.append('notas_entrega')

        solicitud.save(update_fields=campos)

        serializer = self.get_serializer(solicitud)
        return Response(serializer.data)

    @action(detail=True, methods=['post'], url_path='aceptar-franja')
    def aceptar_franja(self, request, pk=None):
        """Confirma la última franja propuesta por la otra parte."""
        solicitud = self.get_object()
        es_ciudadano = solicitud.usuario_id == request.user.id
        es_recolector = self._recolector_asignado(solicitud)

        if not es_ciudadano and not es_recolector:
            return Response(
                {'error': 'No participás en esta solicitud'},
                status=status.HTTP_403_FORBIDDEN,
            )

        propuesta_de_la_otra_parte = (
            (es_ciudadano and solicitud.estado_coordinacion == EstadoCoordinacion.PROPUESTA_RECOLECTOR)
            or (es_recolector and solicitud.estado_coordinacion == EstadoCoordinacion.PROPUESTA_CIUDADANO)
        )
        if not propuesta_de_la_otra_parte:
            return Response(
                {'error': 'No hay una propuesta de la otra parte para aceptar'},
                status=status.HTTP_409_CONFLICT,
            )

        solicitud.estado_coordinacion = EstadoCoordinacion.CONFIRMADA
        solicitud.franja_confirmada_en = timezone.now()
        solicitud.save(
            update_fields=['estado_coordinacion', 'franja_confirmada_en', 'actualizado_en']
        )

        serializer = self.get_serializer(solicitud)
        return Response(serializer.data)

    @action(detail=True, methods=['post'], url_path='en-camino')
    def en_camino(self, request, pk=None):
        """El Recolector asignado sale hacia el punto de retiro."""
        perfil = Recolector.para_usuario(request.user)

        solicitud = SolicitudRetiro.objects.filter(pk=pk).first()
        if solicitud is None:
            return Response(
                {'error': 'Solicitud no encontrada'}, status=status.HTTP_404_NOT_FOUND
            )
        if solicitud.recolector_id != perfil.id:
            return Response(
                {'error': 'No estás asignado a esta solicitud'},
                status=status.HTTP_403_FORBIDDEN,
            )
        if solicitud.estado != EstadoSolicitud.ACEPTADA:
            return Response(
                {'error': 'La solicitud no está en un estado que permita salir en camino'},
                status=status.HTTP_409_CONFLICT,
            )
        if solicitud.estado_coordinacion != EstadoCoordinacion.CONFIRMADA:
            return Response(
                {'error': 'Todavía no hay una franja horaria confirmada'},
                status=status.HTTP_409_CONFLICT,
            )

        solicitud.estado = EstadoSolicitud.EN_CAMINO
        solicitud.save(update_fields=['estado', 'actualizado_en'])

        asignacion = AsignacionRetiro.objects.filter(
            solicitud=solicitud, recolector=perfil, estado=AsignacionRetiro.Estado.ACEPTADA
        ).first()
        if asignacion is not None:
            asignacion.en_camino_en = timezone.now()
            asignacion.save(update_fields=['en_camino_en'])

        serializer = self.get_serializer(solicitud)
        return Response(serializer.data)

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

            # El retiro solo se puede cerrar tras pasar por "en camino" — no se
            # puede completar apenas aceptada, saltándose la coordinación de
            # franja y la salida hacia el punto de retiro.
            if solicitud.estado != EstadoSolicitud.EN_CAMINO:
                return Response(
                    {
                        'error': 'Primero debes marcar "en camino" antes de '
                        'completar el retiro.'
                    },
                    status=status.HTTP_409_CONFLICT,
                )

            try:
                peso_kg = Decimal(str(request.data.get('peso_kg')))
            except (InvalidOperation, TypeError):
                return Response(
                    {'error': 'peso_kg es requerido y debe ser un número'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if peso_kg <= 0:
                return Response(
                    {'error': 'peso_kg debe ser mayor que 0'}, status=status.HTTP_400_BAD_REQUEST
                )

            solicitud.estado = EstadoSolicitud.COMPLETADA
            solicitud.peso_kg = peso_kg
            solicitud.save(update_fields=['estado', 'peso_kg', 'actualizado_en'])

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

        # Fuera del `atomic()`: la app `gamificacion` maneja su propia
        # transacción (saldo + ledger + evento pendiente).
        from gamificacion.services import acreditar_por_completado
        acreditar_por_completado(asignacion)

        serializer = AsignacionRetiroSerializer(
            asignacion, context=self.get_serializer_context()
        )
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def calificar(self, request, pk=None):
        """
        Calificación opcional del Ciudadano al Recolector, una vez que el
        retiro ya está `completada`. No condiciona nada más — los EcoPuntos
        ya se acreditaron cuando el Recolector completó (ver `completar`).
        """
        solicitud = SolicitudRetiro.objects.filter(pk=pk, usuario=request.user).first()
        if solicitud is None:
            return Response(
                {'error': 'Solicitud no encontrada'}, status=status.HTTP_404_NOT_FOUND
            )
        if solicitud.estado != EstadoSolicitud.COMPLETADA:
            return Response(
                {'error': 'Solo se puede calificar un retiro ya completado'},
                status=status.HTTP_409_CONFLICT,
            )

        asignacion = (
            AsignacionRetiro.objects.filter(
                solicitud=solicitud, estado=AsignacionRetiro.Estado.COMPLETADA
            )
            .order_by('-completada_en')
            .first()
        )
        if asignacion is None:
            return Response(
                {'error': 'Esta solicitud no tiene un retiro completado que calificar'},
                status=status.HTTP_409_CONFLICT,
            )
        if asignacion.calificacion is not None:
            return Response(
                {'error': 'Ya calificaste este retiro'}, status=status.HTTP_409_CONFLICT
            )

        try:
            calificacion = int(request.data.get('calificacion'))
        except (TypeError, ValueError):
            return Response(
                {'error': 'calificacion es requerida y debe ser un número entero'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if calificacion < 1 or calificacion > 5:
            return Response(
                {'error': 'calificacion debe estar entre 1 y 5'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        etiquetas = request.data.get('etiquetas') or []
        if not isinstance(etiquetas, list) or len(etiquetas) > ETIQUETAS_CALIFICACION_MAX:
            return Response(
                {'error': f'etiquetas debe ser una lista de máximo {ETIQUETAS_CALIFICACION_MAX} ítems'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        etiquetas = [str(e)[:ETIQUETA_CALIFICACION_LONGITUD_MAX] for e in etiquetas]

        asignacion.calificacion = calificacion
        asignacion.calificacion_etiquetas = etiquetas
        asignacion.calificacion_comentario = str(request.data.get('comentario') or '')[:200]
        asignacion.save(
            update_fields=['calificacion', 'calificacion_etiquetas', 'calificacion_comentario']
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

    def _recolector_asignado(self, solicitud):
        perfil = getattr(self.request.user, 'perfil_recolector', None)
        return perfil is not None and solicitud.recolector_id == perfil.id

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
