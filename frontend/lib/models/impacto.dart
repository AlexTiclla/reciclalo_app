class Impacto {
  Impacto({
    required this.co2Kg,
    required this.aguaL,
    required this.totalRecicladoKg,
    required this.retirosCompletados,
  });

  final double co2Kg;
  final double aguaL;
  final double totalRecicladoKg;
  final int retirosCompletados;

  factory Impacto.fromJson(Map<String, dynamic> json) {
    return Impacto(
      co2Kg: double.parse(json['co2_kg'].toString()),
      aguaL: double.parse(json['agua_l'].toString()),
      totalRecicladoKg: double.parse(json['total_reciclado_kg'].toString()),
      retirosCompletados: json['retiros_completados'] as int,
    );
  }
}
