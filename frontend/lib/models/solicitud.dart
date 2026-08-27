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

class Recolector {
  Recolector({required this.id, required this.nombre});

  final int id;
  final String nombre;

  factory Recolector.fromJson(Map<String, dynamic> json) {
    return Recolector(id: json['id'] as int, nombre: json['nombre'] as String);
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
    );
  }
}

double? _aDouble(Object? valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString());
}
