from rest_framework.permissions import BasePermission

class PerteneceAGrupo(BasePermission):
    """Permiso base para validar grupos por defecto."""
    nombre_grupo = None

    def has_permission(self, request, view):
        return bool(
            request.user and 
            request.user.is_authenticated and 
            request.user.groups.filter(name=self.nombre_grupo).exists()
        )

class EsCiudadano(PerteneceAGrupo):
    nombre_grupo = 'Ciudadano'

class EsRecolector(PerteneceAGrupo):
    nombre_grupo = 'Recolector'