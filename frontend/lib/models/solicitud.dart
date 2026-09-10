import 'package:flutter/material.dart';

enum TipoMaterial {
  plastico('plastico', 'Plástico', Icons.local_drink_outlined),
  carton('carton', 'Cartón', Icons.inventory_2_outlined),
  vidrio('vidrio', 'Vidrio', Icons.wine_bar_outlined),
  metal('metal', 'Metal', Icons.tapas_outlined);

  const TipoMaterial(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  static TipoMaterial fromValue(String value) {
    return TipoMaterial.values.firstWhere((t) => t.value == value);
  }
}

enum EstadoSolicitud {
  pendiente('pendiente', 'Pendiente', Color(0xFFFCBF49)),
  aceptada('aceptada', 'Aceptada', Color(0xFF457B9D)),
  enCamino('en_camino', 'En camino', Color(0xFF457B9D)),
  completada('completada', 'Completado', Color(0xFF2D6A4F));

  const EstadoSolicitud(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  static EstadoSolicitud fromValue(String value) {
    return EstadoSolicitud.values.firstWhere((e) => e.value == value);
  }
}

/// Coordinación de franja horaria (Flujo 4) — independiente de [EstadoSolicitud].
enum EstadoCoordinacion {
  pendiente('pendiente'),
  propuestaCiudadano('propuesta_ciudadano'),
  propuestaRecolector('propuesta_recolector'),
  confirmada('confirmada');

  const EstadoCoordinacion(this.value);

  final String value;

  static EstadoCoordinacion fromValue(String? value) {
    return EstadoCoordinacion.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EstadoCoordinacion.pendiente,
    );
  }
}

/// Última posición conocida del recolector asignado, solo visible para el
/// dueño de la solicitud (ver `SolicitudRetiroSerializer.recolector_ubicacion`).
class UbicacionRecolector {
  UbicacionRecolector({
    required this.latitud,
    required this.longitud,
    required this.actualizadoEn,
  });

  final double latitud;
  final double longitud;
  final DateTime actualizadoEn;

  factory UbicacionRecolector.fromJson(Map<String, dynamic> json) {
    return UbicacionRecolector(
      latitud: double.parse(json['latitud'].toString()),
      longitud: double.parse(json['longitud'].toString()),
      actualizadoEn: DateTime.parse(json['actualizado_en'] as String),
    );
  }
}

/// Calificación ya dada por el ciudadano a un retiro completado, si existe
/// (ver `SolicitudRetiroSerializer.mi_calificacion`).
class MiCalificacion {
  MiCalificacion({required this.estrellas, required this.etiquetas, required this.comentario});

  final int estrellas;
  final List<String> etiquetas;
  final String comentario;

  factory MiCalificacion.fromJson(Map<String, dynamic> json) {
    return MiCalificacion(
      estrellas: json['calificacion'] as int,
      etiquetas: (json['etiquetas'] as List?)?.cast<String>() ?? const [],
      comentario: json['comentario'] as String? ?? '',
    );
  }
}

class Recolector {
  Recolector({
    required this.id,
    required this.nombre,
    this.telefono = '',
    this.fotoUrl,
    this.totalCompletadas = 0,
    this.calificacionPromedio,
  });

  final int id;
  final String nombre;
  final String telefono;
  final String? fotoUrl;
  final int totalCompletadas;

  /// `null` mientras el recolector no tiene ninguna calificación todavía —
  /// no se debe mostrar un número inventado en ese caso.
  final double? calificacionPromedio;

  bool get tieneTelefono => telefono.trim().isNotEmpty;

  factory Recolector.fromJson(Map<String, dynamic> json) {
    return Recolector(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      telefono: json['telefono'] as String? ?? '',
      fotoUrl: json['foto'] as String?,
      totalCompletadas: json['total_completadas'] as int? ?? 0,
      calificacionPromedio: _aDouble(json['calificacion_promedio']),
    );
  }
}

class Solicitud {
  Solicitud({
    required this.id,
    required this.tipoMaterial,
    required this.fotoUrl,
    required this.latitud,
    required this.longitud,
    required this.direccionReferencia,
    required this.estado,
    required this.recolector,
    required this.creadoEn,
    this.precio,
    this.telefonoContacto = '',
    this.ciudadanoNombre = '',
    this.distanciaKm,
    this.estadoCoordinacion = EstadoCoordinacion.pendiente,
    this.ventanaInicio,
    this.ventanaFin,
    this.notasEntrega = '',
    this.franjaConfirmadaEn,
    this.recolectorUbicacion,
    this.puntosAcreditados,
    this.pesoKg,
    this.miCalificacion,
    this.actualizadoEn,
  });

  final int id;
  final TipoMaterial tipoMaterial;
  final String fotoUrl;
  final double latitud;
  final double longitud;
  final String direccionReferencia;
  final EstadoSolicitud estado;
  final Recolector? recolector;
  final DateTime creadoEn;

  /// Recompensa ofrecida al recolector. `null` = el material se entrega gratis.
  final double? precio;

  /// Teléfono del ciudadano para el contacto por WhatsApp. Puede venir vacío.
  final String telefonoContacto;

  /// Nombre del ciudadano. Solo llega en las vistas del flujo del recolector.
  final String ciudadanoNombre;

  /// Distancia desde el recolector. `null` cuando la vista no la calcula
  /// (por ejemplo, en las pantallas del ciudadano).
  final double? distanciaKm;

  // --- Coordinación y seguimiento (Flujo 4) ---
  final EstadoCoordinacion estadoCoordinacion;
  final DateTime? ventanaInicio;
  final DateTime? ventanaFin;
  final String notasEntrega;
  final DateTime? franjaConfirmadaEn;

  /// Solo llega cuando quien pide la solicitud es su dueño (Ciudadano).
  final UbicacionRecolector? recolectorUbicacion;

  /// EcoPuntos ya acreditados por este retiro. `null` mientras no está
  /// `completada` — nunca se inventa un número antes de que exista.
  final int? puntosAcreditados;

  /// Peso real entregado, capturado por el recolector al completar. `null`
  /// mientras la solicitud está pendiente/aceptada/en camino.
  final double? pesoKg;

  /// `null` mientras el ciudadano no calificó este retiro todavía.
  final MiCalificacion? miCalificacion;

  /// Última vez que el backend guardó la solicitud — para un retiro ya
  /// `completada`, coincide con el momento en que se completó.
  final DateTime? actualizadoEn;

  bool get esGratis => precio == null || precio == 0;

  bool get tieneTelefono => telefonoContacto.trim().isNotEmpty;

  /// Etiqueta de precio tal como aparece en el diseño: "$5 en efectivo".
  String get precioLabel {
    if (esGratis) return 'Gratis';
    final monto = precio!;
    final texto = monto == monto.roundToDouble()
        ? monto.toStringAsFixed(0)
        : monto.toStringAsFixed(2);
    return '\$$texto en efectivo';
  }

  /// Distancia legible: metros por debajo de 1 km, kilómetros por encima.
  String get distanciaLabel {
    final km = distanciaKm;
    if (km == null) return 'Distancia no disponible';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  factory Solicitud.fromJson(Map<String, dynamic> json) {
    // El serializer del recolector expone el recolector como `recolector_info`;
    // el del ciudadano, como `recolector`.
    final recolectorJson = json['recolector'] ?? json['recolector_info'];

    return Solicitud(
      id: json['id'] as int,
      tipoMaterial: TipoMaterial.fromValue(json['tipo_material'] as String),
      fotoUrl: json['foto'] as String? ?? '',
      latitud: double.parse(json['latitud'].toString()),
      longitud: double.parse(json['longitud'].toString()),
      direccionReferencia: json['direccion_referencia'] as String? ?? '',
      estado: EstadoSolicitud.fromValue(json['estado'] as String),
      recolector: recolectorJson != null
          ? Recolector.fromJson(recolectorJson as Map<String, dynamic>)
          : null,
      creadoEn: DateTime.parse(json['creado_en'] as String),
      precio: _aDouble(json['precio']),
      telefonoContacto: json['telefono_contacto'] as String? ?? '',
      ciudadanoNombre: json['ciudadano_nombre'] as String? ?? '',
      distanciaKm: _aDouble(json['distancia_km']),
      estadoCoordinacion: EstadoCoordinacion.fromValue(json['estado_coordinacion'] as String?),
      ventanaInicio: _aFecha(json['ventana_inicio']),
      ventanaFin: _aFecha(json['ventana_fin']),
      notasEntrega: json['notas_entrega'] as String? ?? '',
      franjaConfirmadaEn: _aFecha(json['franja_confirmada_en']),
      recolectorUbicacion: json['recolector_ubicacion'] != null
          ? UbicacionRecolector.fromJson(json['recolector_ubicacion'] as Map<String, dynamic>)
          : null,
      puntosAcreditados: json['puntos_acreditados'] as int?,
      pesoKg: _aDouble(json['peso_kg']),
      miCalificacion: json['mi_calificacion'] != null
          ? MiCalificacion.fromJson(json['mi_calificacion'] as Map<String, dynamic>)
          : null,
      actualizadoEn: _aFecha(json['actualizado_en']),
    );
  }
}

DateTime? _aFecha(Object? valor) {
  if (valor == null) return null;
  return DateTime.parse(valor as String);
}

double? _aDouble(Object? valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString());
}
