enum TipoEventoPendiente {
  acreditacion('acreditacion'),
  hitoRacha('hito_racha');

  const TipoEventoPendiente(this.value);
  final String value;

  static TipoEventoPendiente fromValue(String value) {
    return TipoEventoPendiente.values.firstWhere((t) => t.value == value);
  }
}

/// Evento in-app aún no visto (acreditación de puntos o hito de racha).
/// `payload` trae ya resueltos los datos que necesita el modal correspondiente.
class EventoPendiente {
  EventoPendiente({required this.id, required this.tipo, required this.payload});

  final int id;
  final TipoEventoPendiente tipo;
  final Map<String, dynamic> payload;

  factory EventoPendiente.fromJson(Map<String, dynamic> json) {
    return EventoPendiente(
      id: json['id'] as int,
      tipo: TipoEventoPendiente.fromValue(json['tipo'] as String),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
    );
  }
}
