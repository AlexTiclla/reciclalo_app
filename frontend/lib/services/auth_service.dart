import 'package:frontend/models/user_model.dart';
import 'package:frontend/services/api_client.dart';

class AuthService {
  final ApiClient client;

  AuthService(this.client);

  /// Inicia sesión consumiendo POST /api/auth/login/.
  ///
  /// El endpoint de login solo emite el token, así que a continuación se
  /// consulta `/api/auth/me/` para saber a qué flujo entrar (Ciudadano o
  /// Recolector).
  Future<Usuario> login(String username, String password) async {
    final response = await client.postJson('/api/auth/login/', {
      'username': username,
      'password': password,
    });

    final token = response?['token'] as String?;
    if (token == null) {
      throw ApiException('El servidor no devolvió un token de sesión');
    }
    client.setToken(token);

    return usuarioActual(token: token);
  }

  /// Usuario autenticado y su rol (GET /api/auth/me/).
  Future<Usuario> usuarioActual({String token = ''}) async {
    final response = await client.get('/api/auth/me/');
    return Usuario.fromJson({
      ...response as Map<String, dynamic>,
      'token': token,
    });
  }

  /// Registra un nuevo usuario con rol ('Ciudadano' o 'Recolector')
  /// consumiendo POST /api/roles/registro/
  Future<Usuario> registrar({
    required String username,
    required String email,
    required String password,
    required RolUsuario rol,
  }) async {
    final response = await client.postJson('/api/roles/registro/', {
      'username': username,
      'email': email,
      'password': password,
      'rol': rol.value,
    });

    if (response != null) {
      final usuario = Usuario.fromJson(response);
      client.setToken(usuario.token);
      return usuario;
    }
    throw ApiException('No se pudo procesar la respuesta del servidor');
  }

  /// Cierra la sesión eliminando el token del cliente API
  void logout() {
    client.setToken(null);
  }
}