import 'dart:async';

/// Sondeo periódico simple mientras una pantalla está montada.
///
/// El proyecto no tiene WebSockets ni push (ver `CLAUDE.md`), así que las
/// pantallas de coordinación del Flujo 4 se mantienen al día pidiéndole al
/// backend su estado cada pocos segundos — es la forma más simple de que un
/// cambio hecho por la otra parte (Ciudadano/Recolector) se refleje sin que
/// haya que salir y volver a entrar a la pantalla.
class Sondeo {
  Sondeo({required this.intervalo, required this.accion});

  final Duration intervalo;
  final Future<void> Function() accion;
  Timer? _timer;

  void iniciar() {
    detener();
    _timer = Timer.periodic(intervalo, (_) => accion());
  }

  void detener() {
    _timer?.cancel();
    _timer = null;
  }
}
