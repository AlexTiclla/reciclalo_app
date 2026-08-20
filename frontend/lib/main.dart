import 'package:flutter/material.dart';

import 'screens/login_screen.dart';

void main() {
  runApp(const EcoReciclaApp());
}

class EcoReciclaApp extends StatelessWidget {
  const EcoReciclaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0F5238);
    const secondaryContainer = Color(0xFFB0F1CC);

    return MaterialApp(
      title: 'EcoRecicla Ciudadano',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondaryContainer: secondaryContainer,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
