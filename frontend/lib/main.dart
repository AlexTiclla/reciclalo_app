import 'package:flutter/material.dart';

import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/picker/picker_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const EcoReciclaApp());
}

class EcoReciclaApp extends StatelessWidget {
  const EcoReciclaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoRecicla',
      debugShowCheckedModeBanner: false,
      theme: buildEcoTheme(),
      home: const LoginScreen(),
      routes: {
        '/home-ciudadano': (_) => const HomeScreen(),
        '/home-recolector': (_) => const PickerShell(),
      },
    );
  }
}
