import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Flujo 5 — Paso 4: confirmación de éxito. Pantalla estática, sin llamadas
/// al backend — el cambio de contraseña ya ocurrió en el Paso 3A.
class ConfirmacionScreen extends StatelessWidget {
  const ConfirmacionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: EcoSpacing.container),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: EcoColors.mintLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 48,
                    color: EcoColors.leafDark,
                  ),
                ),
              ),
              const SizedBox(height: EcoSpacing.container),
              Text(
                '¡Contraseña actualizada!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: EcoSpacing.element),
              Text(
                'Ya puedes iniciar sesión con tu nueva contraseña.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: EcoColors.onSurfaceVariant),
              ),
              const SizedBox(height: EcoSpacing.section),
              FilledButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Ir a iniciar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
