from django.contrib.auth.models import Group
from rest_framework import status, viewsets
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAdminUser, IsAuthenticated
from rest_framework.authtoken.models import Token
from rest_framework.throttling import ScopedRateThrottle

from .serializers import (
    GroupSerializer,
    RegistroUsuarioSerializer,
    RestablecerPasswordSerializer,
    SolicitarCodigoSerializer,
    VerificarCodigoSerializer,
)
from .services import restablecer_password, solicitar_codigo, verificar_codigo

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

class SolicitarCodigoView(APIView):
    """
    Paso 1 del Flujo 5: envía un código OTP de 6 dígitos por correo.
    POST /api/roles/recuperacion/solicitar/  { identificador }

    Responde 200 exista o no la cuenta — no enumera usuarios (ver
    docs/flujo-5-inicio-registro-recuperacion/recovery_password_design_prompt.md).
    """
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'recuperacion-solicitar'

    def post(self, request):
        serializer = SolicitarCodigoSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        solicitar_codigo(serializer.validated_data['identificador'])
        return Response({'mensaje': 'Si el usuario existe, enviamos un código a su correo.'})


class VerificarCodigoView(APIView):
    """
    Paso 2 del Flujo 5: valida el código OTP y emite un token de corta
    duración que autoriza el cambio de contraseña en el Paso 3A.
    POST /api/roles/recuperacion/verificar/  { identificador, codigo }
    """
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'recuperacion-verificar'

    def post(self, request):
        serializer = VerificarCodigoSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        token = verificar_codigo(**serializer.validated_data)
        if token is None:
            # Mensaje genérico a propósito: código incorrecto, expirado o
            # bloqueado por intentos se ven todos igual desde afuera.
            return Response({'error': 'Código incorrecto o expirado.'}, status=status.HTTP_400_BAD_REQUEST)
        return Response({'token': token})


class RestablecerPasswordView(APIView):
    """
    Paso 3A del Flujo 5: cambia la contraseña usando el token del Paso 2.
    POST /api/roles/recuperacion/restablecer/  { token, nueva_password }
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RestablecerPasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        ok = restablecer_password(**serializer.validated_data)
        if not ok:
            return Response(
                {'error': 'Token inválido o expirado. Vuelve a solicitar un código.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return Response({'mensaje': 'Contraseña actualizada.'})


class PerfilActualView(APIView):
    """
    Devuelve el usuario autenticado y su rol, para que el cliente sepa a qué
    flujo entrar después del login (el endpoint de login solo emite el token).
    GET /api/auth/me/
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        grupo = request.user.groups.first()
        return Response({
            "user_id": request.user.id,
            "username": request.user.username,
            "email": request.user.email,
            "first_name": request.user.first_name,
            "last_name": request.user.last_name,
            "rol": grupo.name if grupo else None,
        })
