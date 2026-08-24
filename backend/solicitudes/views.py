from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated

from .models import EstadoSolicitud, SolicitudRetiro
from .serializers import SolicitudRetiroSerializer


class SolicitudRetiroViewSet(viewsets.ModelViewSet):
    """
    CRUD de solicitudes de retiro para el Ciudadano autenticado.

    - `GET /api/solicitudes/?estado=activas`   -> Mis Solicitudes Activas (Home)
    - `GET /api/solicitudes/?estado=completada` -> Historial de Reciclaje
    - `GET /api/solicitudes/{id}/`              -> Detalle de Solicitud
    - `POST /api/solicitudes/`                  -> Publicar Retiro
    """

    serializer_class = SolicitudRetiroSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = SolicitudRetiro.objects.filter(usuario=self.request.user)

        estado = self.request.query_params.get('estado')
        if estado == 'activas':
            queryset = queryset.exclude(estado=EstadoSolicitud.COMPLETADA)
        elif estado:
            queryset = queryset.filter(estado=estado)

        return queryset
