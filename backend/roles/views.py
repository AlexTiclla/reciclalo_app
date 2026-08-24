from django.contrib.auth.models import Group
from rest_framework import status, viewsets
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAdminUser
from rest_framework.authtoken.models import Token

from .serializers import GroupSerializer, RegistroUsuarioSerializer

class RegistroView(APIView):
    """
    Endpoint público para registrar usuarios como 'Ciudadano' o 'Recolector'.
    POST /api/roles/registro/
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegistroUsuarioSerializer(data=request.data)
        if serializer.is_valid():
            usuario = serializer.save()
            
            # Generar token para que el frontend inicie sesión automáticamente
            token, _ = Token.objects.get_or_create(user=usuario)
            
            # Obtener el nombre del rol asignado
            rol_asignado = usuario.groups.first().name if usuario.groups.exists() else None
            
            return Response({
                "mensaje": "Usuario creado exitosamente",
                "token": token.key,
                "user_id": usuario.id,
                "username": usuario.username,
                "email": usuario.email,
                "rol": rol_asignado
            }, status=status.HTTP_201_CREATED)
            
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class GroupViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Endpoint para listar grupos existentes (solo lectura para autenticados o admin).
    GET /api/roles/grupos/
    """
    queryset = Group.objects.all()
    serializer_class = GroupSerializer
    permission_classes = [IsAdminUser]