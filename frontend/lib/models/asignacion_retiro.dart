import 'solicitud.dart';

enum EstadoAsignacion {
  aceptada('aceptada', 'Aceptada'),
  completada('completada', 'Completada'),
  rechazada('rechazada', 'Rechazada');

  const EstadoAsignacion(this.value, this.label);

  final String value;
  final String label;

  static EstadoAsignacion fromValue(String value) {
    return EstadoAsignacion.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EstadoAsignacion.aceptada,
    );
  }
}

/// Registro de que un recolector aceptó, completó o rechazó una solicitud.
class AsignacionRetiro {
  AsignacionRetiro({
    required this.id,
    required this.solicitud,
    required this.estado,
    required this.aceptadaEn,
    this.completadaEn,
    this.notas = '',
  });

  final int id;
  final Solicitud solicitud;
  final EstadoAsignacion estado;
  final DateTime aceptadaEn;
  final DateTime? completadaEn;
  final String notas;

  factory AsignacionRetiro.fromJson(Map<String, dynamic> json) {
    return AsignacionRetiro(
      id: json['id'] as int,
      solicitud: Solicitud.fromJson(json['solicitud'] as Map<String, dynamic>),
      estado: EstadoAsignacion.fromValue(json['estado'] as String),
      aceptadaEn: DateTime.parse(json['aceptada_en'] as String),
      completadaEn: json['completada_en'] != null
          ? DateTime.parse(json['completada_en'] as String)
          : null,
      notas: json['notas'] as String? ?? '',
    );
  }
}
