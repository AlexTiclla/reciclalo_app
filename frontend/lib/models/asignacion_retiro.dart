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
    this.enCaminoEn,
    this.llegoEn,
    this.calificacion,
    this.calificacionEtiquetas = const [],
    this.calificacionComentario = '',
  });

  final int id;
  final Solicitud solicitud;
  final EstadoAsignacion estado;
  final DateTime aceptadaEn;
  final DateTime? completadaEn;
  final String notas;

  // --- Seguimiento y calificación (Flujo 4) ---
  final DateTime? enCaminoEn;
  final DateTime? llegoEn;

  /// `null` mientras el ciudadano no calificó este retiro todavía.
  final int? calificacion;
  final List<String> calificacionEtiquetas;
  final String calificacionComentario;

  bool get yaCalificado => calificacion != null;

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
      enCaminoEn: json['en_camino_en'] != null
          ? DateTime.parse(json['en_camino_en'] as String)
          : null,
      llegoEn: json['llego_en'] != null ? DateTime.parse(json['llego_en'] as String) : null,
      calificacion: json['calificacion'] as int?,
      calificacionEtiquetas: (json['calificacion_etiquetas'] as List?)?.cast<String>() ?? const [],
      calificacionComentario: json['calificacion_comentario'] as String? ?? '',
    );
  }
}
