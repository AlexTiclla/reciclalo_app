import 'api_client.dart';

/// El código OTP ingresado no coincide con el enviado, ya expiró, o la
/// cuenta se bloqueó temporalmente por demasiados intentos fallidos — el
/// backend no distingue estos casos a propósito (ver design prompt del
/// Flujo 5, principio de no dar pistas de más).
class CodigoInvalidoException implements Exception {
  CodigoInvalidoException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// El token de verificación (emitido tras validar el código OTP) ya no es
/// válido para cambiar la contraseña: expiró o ya se usó.
class TokenExpiradoException implements Exception {
  TokenExpiradoException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Flujo 5: recuperación de contraseña vía código OTP enviado por correo.
class RecuperacionService {
  RecuperacionService(this._client);

  final ApiClient _client;

  /// Paso 1: pide el envío de un código de 6 dígitos al correo registrado.
  ///
  /// El backend responde 200 exista o no la cuenta (no enumera usuarios),
  /// así que esta llamada solo lanza si hay un problema real de red/servidor.
  Future<void> solicitarCodigo(String identificador) async {
    await _client.postJson('/api/roles/recuperacion/solicitar/', {
      'identificador': identificador,
    });
  }

  /// Paso 2: valida el código y retorna el token que autoriza el Paso 3A.
  Future<String> verificarCodigo(String identificador, String codigo) async {
    try {
      final data = await _client.postJson('/api/roles/recuperacion/verificar/', {
        'identificador': identificador,
        'codigo': codigo,
      });
      return data['token'] as String;
    } on ApiException catch (e) {
      if (e.statusCode == 400) {
        throw CodigoInvalidoException('Código incorrecto o expirado.');
      }
      rethrow;
    }
  }

  /// Paso 3A: cambia la contraseña usando el token del Paso 2.
  Future<void> restablecerPassword(String token, String nuevaPassword) async {
    try {
      await _client.postJson('/api/roles/recuperacion/restablecer/', {
        'token': token,
        'nueva_password': nuevaPassword,
      });
    } on ApiException catch (e) {
      if (e.statusCode == 400) {
        throw TokenExpiradoException(
          'Token inválido o expirado. Vuelve a solicitar un código.',
        );
      }
      rethrow;
    }
  }
}
