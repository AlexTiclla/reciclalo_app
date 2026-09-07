import 'recompensa.dart';

class Canje {
  Canje({
    required this.id,
    required this.recompensa,
    required this.puntosGastados,
    required this.codigo,
    required this.creadoEn,
  });

  final int id;
  final Recompensa recompensa;
  final int puntosGastados;
  final String codigo;
  final DateTime creadoEn;

  factory Canje.fromJson(Map<String, dynamic> json) {
    return Canje(
      id: json['id'] as int,
      recompensa: Recompensa.fromJson(json['recompensa'] as Map<String, dynamic>),
      puntosGastados: json['puntos_gastados'] as int,
      codigo: json['codigo'] as String,
      creadoEn: DateTime.parse(json['creado_en'] as String),
    );
  }
}
