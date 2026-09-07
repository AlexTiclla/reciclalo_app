class Recompensa {
  Recompensa({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.imagenUrl,
    required this.costoPuntos,
    required this.categoria,
    required this.comercioNombre,
  });

  final int id;
  final String nombre;
  final String descripcion;
  final String imagenUrl;
  final int costoPuntos;
  final String categoria;
  final String comercioNombre;

  factory Recompensa.fromJson(Map<String, dynamic> json) {
    return Recompensa(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String? ?? '',
      imagenUrl: json['imagen'] as String? ?? '',
      costoPuntos: json['costo_puntos'] as int,
      categoria: json['categoria'] as String? ?? '',
      comercioNombre: json['comercio_nombre'] as String? ?? '',
    );
  }
}
