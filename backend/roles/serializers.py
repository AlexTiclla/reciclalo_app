from django.contrib.auth.models import User, Group, Permission
from rest_framework import serializers

# --- Serializadores para consultar Roles/Permisos ---
class PermissionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Permission
        fields = ['id', 'name', 'codename']

class GroupSerializer(serializers.ModelSerializer):
    permissions = PermissionSerializer(many=True, read_only=True)

    class Meta:
        model = Group
        fields = ['id', 'name', 'permissions']


# --- Serializador para Registro con Roles Nativo de Django ---
class RegistroUsuarioSerializer(serializers.ModelSerializer):
    # El frontend debe enviar 'rol': 'Ciudadano' o 'rol': 'Recolector'
    rol = serializers.ChoiceField(
        choices=['Ciudadano', 'Recolector'],
        write_only=True,
        required=True
    )
    password = serializers.CharField(write_only=True, min_length=6)

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'first_name', 'last_name', 'rol']

    def create(self, validated_data):
        rol_nombre = validated_data.pop('rol')
        
        # 1. Crear el usuario nativo con su contraseña hasheada
        usuario = User.objects.create_user(**validated_data)
        
        # 2. Buscar o crear el grupo nativo y asignarlo al usuario
        grupo, _ = Group.objects.get_or_create(name=rol_nombre)
        usuario.groups.add(grupo)
        
        return usuario