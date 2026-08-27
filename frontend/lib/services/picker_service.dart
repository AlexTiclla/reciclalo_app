import '../models/asignacion_retiro.dart';
import '../models/perfil_recolector.dart';
import '../models/solicitud.dart';
import 'api_client.dart';

/// Se lanza cuando otro recolector ganó la solicitud (HTTP 409).
class SolicitudYaTomadaException implements Exception {
  SolicitudYaTomadaException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Cliente de los endpoints del flujo del Recolector.
class PickerService {
  PickerService(this._client);

  final ApiClient _client;

  /// Perfil del recolector autenticado. Se crea en el backend al primer uso.
  Future<PerfilRecolector> obtenerPerfil() async {
    final data = await _client.get('/api/recolector/perfil/');
    return PerfilRecolector.fromJson(data as Map<String, dynamic>);
  }

  /// Reporta la posición actual del recolector (ping periódico).
  Future<PerfilRecolector> actualizarUbicacion(
    double latitud,
    double longitud,
  ) async {
    final data = await _client.postJson('/api/recolector/ubicacion/', {
      // El backend guarda DecimalField(decimal_places=6); el GPS entrega más
      // precisión de la que la columna admite.
      'latitud': latitud.toStringAsFixed(6),
      'longitud': longitud.toStringAsFixed(6),
    });
    return PerfilRecolector.fromJson(data as Map<String, dynamic>);
  }

  Future<bool> cambiarDisponibilidad(bool esActivo) async {
    final data = await _client.postJson('/api/recolector/disponibilidad/', {
      'es_activo': esActivo,
    });
    return (data as Map<String, dynamic>)['es_activo'] as bool;
  }

  /// Solicitudes pendientes dentro del radio, ordenadas de más cerca a más lejos.
  Future<List<Solicitud>> solicitudesCercanas({
    required double latitud,
    required double longitud,
    double radioKm = 5,
  }) async {
    final data = await _client.get(
      '/api/solicitudes/cercanas/',
      query: {
        'latitud': latitud.toStringAsFixed(6),
        'longitud': longitud.toStringAsFixed(6),
        'radio_km': radioKm.toString(),
      },
    );
    return _aSolicitudes(data);
  }

  Future<Solicitud> obtenerDetalle(int solicitudId) async {
    final data = await _client.get('/api/solicitudes/$solicitudId/');
    return Solicitud.fromJson(data as Map<String, dynamic>);
  }

  /// Acepta una solicitud. Lanza [SolicitudYaTomadaException] si otro
  /// recolector se adelantó.
  Future<AsignacionRetiro> aceptar(int solicitudId) async {
    try {
      final data = await _client.postJson(
        '/api/solicitudes/$solicitudId/aceptar/',
        const {},
      );
      return AsignacionRetiro.fromJson(data as Map<String, dynamic>);
    } on ApiException catch (error) {
      if (error.statusCode == 409) {
        throw SolicitudYaTomadaException(
          'Otro recolector aceptó esta solicitud antes que tú.',
        );
      }
      rethrow;
    }
  }

  Future<AsignacionRetiro> rechazar(int solicitudId, {String motivo = ''}) async {
    final data = await _client.postJson(
      '/api/solicitudes/$solicitudId/rechazar/',
      {'motivo': motivo},
    );
    return AsignacionRetiro.fromJson(data as Map<String, dynamic>);
  }

  Future<AsignacionRetiro> completar(int solicitudId) async {
    final data = await _client.postJson(
      '/api/solicitudes/$solicitudId/completar/',
      const {},
    );
    return AsignacionRetiro.fromJson(data as Map<String, dynamic>);
  }

  Future<List<AsignacionRetiro>> solicitudesAceptadas() =>
      _asignaciones('/api/recolector/solicitudes-aceptadas/');

  Future<List<AsignacionRetiro>> historial() =>
      _asignaciones('/api/recolector/solicitudes-completadas/');

  Future<List<AsignacionRetiro>> _asignaciones(String path) async {
    final data = await _client.get(path);
    return (data as List)
        .map((json) => AsignacionRetiro.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  List<Solicitud> _aSolicitudes(Object? data) {
    return (data as List)
        .map((json) => Solicitud.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
