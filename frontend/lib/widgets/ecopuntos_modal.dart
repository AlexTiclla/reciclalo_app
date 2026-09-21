import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Modal de acreditación de EcoPuntos, mostrado tras completar un retiro
/// (ver `acreditaci_n_ecopuntos_equilibrado` en stitch_ecorecicla_ciudadano/).
class EcoPuntosModal extends StatelessWidget {
  const EcoPuntosModal({
    super.key,
    required this.puntos,
    required this.saldoTotal,
    required this.onVerRecompensas,
  });

  final int puntos;
  final int saldoTotal;
  final VoidCallback onVerRecompensas;

  static Future<void> mostrar(
    BuildContext context, {
    required int puntos,
    required int saldoTotal,
    required VoidCallback onVerRecompensas,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EcoPuntosModal(
        puntos: puntos,
        saldoTotal: saldoTotal,
        onVerRecompensas: onVerRecompensas,
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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: EcoColors.mintLight.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: EcoColors.primary, size: 28),
            ),
            const SizedBox(height: EcoSpacing.stack),
            Text(
              '¡Retiro completado!',
              textAlign: TextAlign.center,
              style: textos.headlineMedium,
            ),
            const SizedBox(height: EcoSpacing.element),
            Text(
              'Tus materiales reciclables han sido acreditados correctamente.',
              textAlign: TextAlign.center,
              style: textos.bodySmall,
            ),
            const SizedBox(height: EcoSpacing.section),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '+$puntos',
                  style: textos.headlineLarge?.copyWith(
                    color: EcoColors.primary,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: EcoSpacing.element),
                Text(
                  'EcoPuntos',
                  style: textos.headlineMedium?.copyWith(color: EcoColors.primary),
                ),
              ],
            ),
            const SizedBox(height: EcoSpacing.element),
            Text.rich(
              TextSpan(
                text: 'Saldo total: ',
                style: textos.labelSmall?.copyWith(color: EcoColors.outline),
                children: [
                  TextSpan(
                    text: '$saldoTotal pts',
                    style: textos.labelSmall?.copyWith(
                      color: EcoColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: EcoSpacing.section),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onVerRecompensas();
                },
                child: const Text('Ver recompensas'),
              ),
            ),
            const SizedBox(height: EcoSpacing.element),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
