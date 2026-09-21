import 'package:flutter/material.dart';

import '../../services/whatsapp_service.dart';
import '../../theme/app_theme.dart';

/// Flujo 5 — Paso 3B: escape hatch para quien no tiene acceso a su correo.
/// No llama al backend — solo abre WhatsApp con un mensaje prellenado, o
/// vuelve a Login.
class ContingenciaScreen extends StatefulWidget {
  const ContingenciaScreen({super.key});

  @override
  State<ContingenciaScreen> createState() => _ContingenciaScreenState();
}

class _ContingenciaScreenState extends State<ContingenciaScreen> {
  // TODO(soporte): reemplazar por el número real de soporte de EcoRecicla
  // antes de salir a producción — no hay uno configurado en el proyecto hoy.
  static const _numeroSoporte = '59169033500';

  String? _error;

  Future<void> _contactarPorWhatsApp() async {
    setState(() => _error = null);
    try {
      await WhatsAppService.contactar(
        _numeroSoporte,
        'Hola, necesito ayuda para recuperar el acceso a mi cuenta de EcoRecicla.',
      );
    } catch (_) {
      setState(() => _error = 'No pudimos abrir WhatsApp.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: EcoSpacing.container),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: EcoSpacing.section),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: EcoColors.mintLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.help_outline,
                    size: 36,
                    color: EcoColors.leafDark,
                  ),
                ),
              ),
              const SizedBox(height: EcoSpacing.container),
              Text(
                '¿No tienes acceso a tu correo?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: EcoSpacing.element),
              Text(
                'Contáctanos por WhatsApp y te ayudamos a recuperar el acceso a tu cuenta.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: EcoColors.onSurfaceVariant),
              ),
              if (_error != null) ...[
                const SizedBox(height: EcoSpacing.stack),
                Text(
                  _error!,
                  style: const TextStyle(color: EcoColors.dangerRed),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: EcoSpacing.section),
              FilledButton(
                onPressed: _contactarPorWhatsApp,
                child: const Text('Contactar por WhatsApp'),
              ),
              const SizedBox(height: EcoSpacing.stack),
              TextButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Volver a Login'),
              ),
              const SizedBox(height: EcoSpacing.container),
            ],
          ),
        ),
      ),
    );
  }
}
