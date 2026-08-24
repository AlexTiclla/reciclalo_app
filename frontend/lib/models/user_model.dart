enum RolUsuario {
  ciudadano('Ciudadano', 'Ciudadano'),
  recolector('Recolector', 'Recolector');

  final String value;
  final String label;
  const RolUsuario(this.value, this.label);

  static RolUsuario fromValue(String value) {
    return RolUsuario.values.firstWhere(
      (r) => r.value.toLowerCase() == value.toLowerCase(),
      orElse: () => RolUsuario.ciudadano,
    );
  }
}

class Usuario {
  final int id;
  final String username;
  final String email;
  final RolUsuario rol;
  final String token;

  Usuario({
    required this.id,
    required this.username,
    required this.email,
    required this.rol,
    required this.token,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['user_id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      rol: RolUsuario.fromValue(json['rol'] ?? 'Ciudadano'),
      token: json['token'] ?? '',
    );
  }
}