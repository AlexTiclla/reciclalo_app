class SaldoEcoPuntos {
  SaldoEcoPuntos({required this.saldo});

  final int saldo;

  factory SaldoEcoPuntos.fromJson(Map<String, dynamic> json) {
    return SaldoEcoPuntos(saldo: json['saldo'] as int);
  }
}
