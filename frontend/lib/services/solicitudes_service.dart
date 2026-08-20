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
    required String fotoPath,
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
      fotoPath,
    );
    return Solicitud.fromJson(data as Map<String, dynamic>);
  }
}
