/// Perfil del recolector autenticado (`GET /api/recolector/perfil/`).
///
/// Distinto de [Recolector] en `models/solicitud.dart`, que es solo el resumen
/// {id, nombre} que el ciudadano ve en su solicitud.
class PerfilRecolector {
  PerfilRecolector({
    required this.id,
    required this.usuarioNombre,
    required this.esActivo,
    required this.totalCompletadas,
    this.latitudActual,
    this.longitudActual,
  });

  final int id;
  final String usuarioNombre;
  final bool esActivo;
  final int totalCompletadas;
  final double? latitudActual;
  final double? longitudActual;

  factory PerfilRecolector.fromJson(Map<String, dynamic> json) {
    return PerfilRecolector(
      id: json['id'] as int,
      usuarioNombre: json['usuario_nombre'] as String? ?? '',
      esActivo: json['es_activo'] as bool? ?? false,
      totalCompletadas: json['total_completadas'] as int? ?? 0,
      latitudActual: _aDouble(json['latitud_actual']),
      longitudActual: _aDouble(json['longitud_actual']),
    );
  }
}

double? _aDouble(Object? valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString());
}
