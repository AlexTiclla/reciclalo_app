enum TipoTransaccion {
  acreditacion('acreditacion'),
  bonoRacha('bono_racha'),
  canje('canje');

  const TipoTransaccion(this.value);
  final String value;

  static TipoTransaccion fromValue(String value) {
    return TipoTransaccion.values.firstWhere((t) => t.value == value);
  }
}

class TransaccionEcoPuntos {
  TransaccionEcoPuntos({
    required this.id,
    required this.tipo,
    required this.tipoDisplay,
    required this.puntos,
    required this.referencia,
    required this.creadoEn,
  });

  final int id;
  final TipoTransaccion tipo;
  final String tipoDisplay;
  final int puntos;
  final String referencia;
  final DateTime creadoEn;

  factory TransaccionEcoPuntos.fromJson(Map<String, dynamic> json) {
    return TransaccionEcoPuntos(
      id: json['id'] as int,
      tipo: TipoTransaccion.fromValue(json['tipo'] as String),
      tipoDisplay: json['tipo_display'] as String,
      puntos: json['puntos'] as int,
      referencia: json['referencia'] as String? ?? '',
      creadoEn: DateTime.parse(json['creado_en'] as String),
    );
  }
}
