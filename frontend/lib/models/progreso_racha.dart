class ProgresoRacha {
  ProgresoRacha({
    required this.rachaActual,
    required this.rachaMaxima,
    required this.protectoresDisponibles,
    required this.protectoresTotales,
    this.proximoHito,
    this.puntosProximoHito,
  });

  final int rachaActual;
  final int rachaMaxima;
  final int protectoresDisponibles;
  final int protectoresTotales;
  final int? proximoHito;
  final int? puntosProximoHito;

  factory ProgresoRacha.fromJson(Map<String, dynamic> json) {
    return ProgresoRacha(
      rachaActual: json['racha_actual'] as int,
      rachaMaxima: json['racha_maxima'] as int,
      protectoresDisponibles: json['protectores_disponibles'] as int,
      protectoresTotales: json['protectores_totales'] as int,
      proximoHito: json['proximo_hito'] as int?,
      puntosProximoHito: json['puntos_proximo_hito'] as int?,
    );
  }
}
