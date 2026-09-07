import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Modal de celebración al cruzar un hito de racha (2/4/8/12/26/52 semanas).
/// No se muestra cada semana: solo cuando llega un evento `hito_racha`
/// (ver `hito_de_racha_equilibrado` en stitch_ecorecicla_ciudadano/).
class HitoRachaModal extends StatelessWidget {
  const HitoRachaModal({
    super.key,
    required this.rachaSemanas,
    required this.puntos,
    required this.onExplorarRecompensas,
  });

  final int rachaSemanas;
  final int puntos;
  final VoidCallback onExplorarRecompensas;

  static Future<void> mostrar(
    BuildContext context, {
    required int rachaSemanas,
    required int puntos,
    required VoidCallback onExplorarRecompensas,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HitoRachaModal(
        rachaSemanas: rachaSemanas,
        puntos: puntos,
        onExplorarRecompensas: onExplorarRecompensas,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: EcoColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcoRadius.x2l)),
      child: Padding(
        padding: const EdgeInsets.all(EcoSpacing.section),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: EcoColors.mintLight.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: EcoColors.primary,
                size: 38,
              ),
            ),
            const SizedBox(height: EcoSpacing.stack),
            Text(
              '¡$rachaSemanas semanas de racha!',
              textAlign: TextAlign.center,
              style: textos.headlineLarge,
            ),
            const SizedBox(height: EcoSpacing.element),
            Text(
              'Has mantenido tu hábito de reciclaje activo. ¡Sigue así!',
              textAlign: TextAlign.center,
              style: textos.bodySmall,
            ),
            const SizedBox(height: EcoSpacing.section),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: EcoSpacing.stack,
                vertical: EcoSpacing.stack,
              ),
              decoration: BoxDecoration(
                color: EcoColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(EcoRadius.xl),
              ),
              child: Row(
                children: [
                  const Icon(Icons.military_tech, color: EcoColors.primary, size: 20),
                  const SizedBox(width: EcoSpacing.stack),
                  Expanded(
                    child: Text(
                      '+$puntos EcoPuntos de bono',
                      style: textos.labelLarge?.copyWith(color: EcoColors.onSurface),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: EcoSpacing.section),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onExplorarRecompensas();
                },
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Explorar recompensas'),
              ),
            ),
            const SizedBox(height: EcoSpacing.element),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
