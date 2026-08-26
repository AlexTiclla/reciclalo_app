import 'package:flutter/material.dart';

import 'models/user_model.dart';
import 'screens/home_screen.dart';
import 'screens/picker/picker_shell.dart';

/// Pantalla raíz de cada rol.
///
/// Ciudadano y Recolector usan la misma app pero no comparten navegación:
/// el ciudadano publica retiros, el recolector los atiende desde el mapa.
Widget pantallaInicialPara(RolUsuario rol) {
  return switch (rol) {
    RolUsuario.recolector => const PickerShell(),
    RolUsuario.ciudadano => const HomeScreen(),
  };
}
