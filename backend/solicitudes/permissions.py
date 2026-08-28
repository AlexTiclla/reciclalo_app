from rest_framework.permissions import BasePermission

from roles.permissions import EsRecolector  # noqa: F401  (re-exportado para las vistas)


class PuedeVerSolicitud(BasePermission):
    """
    El Ciudadano solo accede a sus propias solicitudes; el Recolector accede a
    las que están libres o a las que él mismo aceptó.
    """

    def has_object_permission(self, request, view, obj):
        if obj.usuario_id == request.user.id:
            return True

        perfil = getattr(request.user, 'perfil_recolector', None)
        if perfil is None:
            return request.user.groups.filter(name='Recolector').exists()

        return obj.recolector_id is None or obj.recolector_id == perfil.id
