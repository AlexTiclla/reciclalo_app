import '../models/canje.dart';
import '../models/evento_pendiente.dart';
import '../models/impacto.dart';
import '../models/progreso_racha.dart';
import '../models/recompensa.dart';
import '../models/saldo_ecopuntos.dart';
import '../models/transaccion_ecopuntos.dart';
import 'api_client.dart';

/// Se lanza cuando el saldo no alcanza para el canje (HTTP 409).
class SaldoInsuficienteException implements Exception {
  SaldoInsuficienteException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Cliente de los endpoints del flujo de fidelización y gamificación.
class GamificacionService {
  GamificacionService(this._client);

  final ApiClient _client;

  Future<SaldoEcoPuntos> obtenerSaldo() async {
    final data = await _client.get('/api/gamificacion/saldo/');
    return SaldoEcoPuntos.fromJson(data as Map<String, dynamic>);
  }

  Future<List<TransaccionEcoPuntos>> historialTransacciones({String? tipo}) async {
    final data = await _client.get(
      '/api/gamificacion/transacciones/',
      query: tipo != null ? {'tipo': tipo} : null,
    );
    return (data as List)
        .map((json) => TransaccionEcoPuntos.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Recompensa>> catalogoRecompensas({String? categoria}) async {
    final data = await _client.get(
      '/api/gamificacion/recompensas/',
      query: categoria != null ? {'categoria': categoria} : null,
    );
    return (data as List)
        .map((json) => Recompensa.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Recompensa> obtenerRecompensa(int id) async {
    final data = await _client.get('/api/gamificacion/recompensas/$id/');
    return Recompensa.fromJson(data as Map<String, dynamic>);
  }

  /// Canjea una recompensa. Lanza [SaldoInsuficienteException] si el saldo
  /// no alcanza (HTTP 409).
  Future<Canje> canjear(int recompensaId) async {
    try {
      final data = await _client.postJson(
        '/api/gamificacion/recompensas/$recompensaId/canjear/',
        const {},
      );
      return Canje.fromJson((data as Map<String, dynamic>)['canje'] as Map<String, dynamic>);
    } on ApiException catch (error) {
      if (error.statusCode == 409) {
        throw SaldoInsuficienteException('No tienes suficientes EcoPuntos para este canje.');
      }
      rethrow;
    }
  }

  Future<ProgresoRacha> obtenerRacha() async {
    final data = await _client.get('/api/gamificacion/racha/');
    return ProgresoRacha.fromJson(data as Map<String, dynamic>);
  }

  Future<Impacto> obtenerImpacto() async {
    final data = await _client.get('/api/gamificacion/impacto/');
    return Impacto.fromJson(data as Map<String, dynamic>);
  }

  Future<List<EventoPendiente>> eventosPendientes() async {
    final data = await _client.get('/api/gamificacion/eventos-pendientes/');
    return (data as List)
        .map((json) => EventoPendiente.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> marcarEventoVisto(int id) {
    return _client.postJson('/api/gamificacion/eventos-pendientes/$id/marcar-visto/', const {});
  }
}
