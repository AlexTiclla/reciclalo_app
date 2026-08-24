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

  factory Solicitud.fromJson(Map<String, dynamic> json) {
    return Solicitud(
      id: json['id'] as int,
      tipoMaterial: TipoMaterial.fromValue(json['tipo_material'] as String),
      fotoUrl: json['foto'] as String? ?? '',
      latitud: double.parse(json['latitud'].toString()),
      longitud: double.parse(json['longitud'].toString()),
      direccionReferencia: json['direccion_referencia'] as String? ?? '',
      estado: EstadoSolicitud.fromValue(json['estado'] as String),
      recolector: json['recolector'] != null
          ? Recolector.fromJson(json['recolector'] as Map<String, dynamic>)
          : null,
      creadoEn: DateTime.parse(json['creado_en'] as String),
    );
  }
}
