import 'dart:typed_data';

import '../models/asignacion_retiro.dart';
import '../models/solicitud.dart';
import 'api_client.dart';

class SolicitudesService {
  SolicitudesService(this._client);

  final ApiClient _client;

  Future<List<Solicitud>> listarActivas() => _listar('activas');

  Future<List<Solicitud>> listarCompletadas() => _listar('completada');

  Future<List<Solicitud>> _listar(String estado) async {
    final data = await _client.get('/api/solicitudes/', query: {'estado': estado});
    return (data as List)
        .map((json) => Solicitud.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Solicitud> obtener(int id) async {
    final data = await _client.get('/api/solicitudes/$id/');
    return Solicitud.fromJson(data as Map<String, dynamic>);
  }

  Future<Solicitud> publicar({
    required TipoMaterial tipoMaterial,
    required Uint8List fotoBytes,
    required String fotoNombre,
    required double latitud,
    required double longitud,
    String direccionReferencia = '',
  }) async {
    final data = await _client.postMultipart(
      '/api/solicitudes/',
      {
        'tipo_material': tipoMaterial.value,
        // El modelo Django (DecimalField) solo acepta 6 decimales; el GPS
        // entrega más precisión de la que la BD admite.
        'latitud': latitud.toStringAsFixed(6),
        'longitud': longitud.toStringAsFixed(6),
        'direccion_referencia': direccionReferencia,
      },
      'foto',
      fotoBytes,
      fotoNombre,
    );
    return Solicitud.fromJson(data as Map<String, dynamic>);
  }

  // --- Coordinación y seguimiento del retiro (Flujo 4) ---------------------

  Future<Solicitud> proponerFranja(
    int id, {
    required DateTime inicio,
    required DateTime fin,
    String notas = '',
  }) async {
    final data = await _client.postJson('/api/solicitudes/$id/proponer-franja/', {
      'ventana_inicio': inicio.toIso8601String(),
      'ventana_fin': fin.toIso8601String(),
      'notas_entrega': notas,
    });
    return Solicitud.fromJson(data as Map<String, dynamic>);
  }

  Future<Solicitud> aceptarFranja(int id) async {
    final data = await _client.postJson('/api/solicitudes/$id/aceptar-franja/', const {});
    return Solicitud.fromJson(data as Map<String, dynamic>);
  }

  /// Calificación opcional del recolector, una vez que el retiro ya está
  /// `completada`. No condiciona los EcoPuntos: ya se acreditaron al completar.
  Future<AsignacionRetiro> calificar(
    int id, {
    required int estrellas,
    List<String> etiquetas = const [],
    String comentario = '',
  }) async {
    final data = await _client.postJson('/api/solicitudes/$id/calificar/', {
      'calificacion': estrellas,
      'etiquetas': etiquetas,
      'comentario': comentario,
    });
    return AsignacionRetiro.fromJson(data as Map<String, dynamic>);
  }
}
