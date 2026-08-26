import 'package:flutter/material.dart';

import '../../models/solicitud.dart';
import '../../theme/app_theme.dart';

/// Confirmación previa a aceptar una solicitud.
///
/// Devuelve `true` si el recolector confirma. Resume material, pago y distancia
/// para que no tenga que volver atrás a revisarlos.
Future<bool> confirmarAceptacion(BuildContext context, Solicitud solicitud) async {
  final confirmado = await showDialog<bool>(
    context: context,
    barrierColor: EcoColors.onSurface.withValues(alpha: 0.4),
    builder: (context) => _ConfirmAcceptDialog(solicitud: solicitud),
  );
  return confirmado ?? false;
}

class _ConfirmAcceptDialog extends StatelessWidget {
  const _ConfirmAcceptDialog({required this.solicitud});

  final Solicitud solicitud;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: EcoColors.surface,
      insetPadding: const EdgeInsets.all(EcoSpacing.container),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EcoRadius.x2l),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 384),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: EcoColors.secondaryContainer,
                  border: Border.all(color: EcoColors.surface, width: 4),
                ),
                child: const Icon(
                  Icons.handshake,
                  size: 30,
                  color: EcoColors.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '¿Aceptar esta solicitud?',
                textAlign: TextAlign.center,
                style: textos.headlineMedium,
              ),
              const SizedBox(height: EcoSpacing.stack),
              _Resumen(solicitud: solicitud),
              const SizedBox(height: EcoSpacing.section),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sí, aceptar'),
              ),
              const SizedBox(height: EcoSpacing.element),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: EcoColors.primary,
                  minimumSize: const Size.fromHeight(EcoSpacing.touchTarget),
                  textStyle: textos.labelLarge,
                ),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.solicitud});

  final Solicitud solicitud;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: EcoSpacing.stack, vertical: 12),
      decoration: BoxDecoration(
        color: EcoColors.surfaceContainerLow,
        border: Border.all(color: EcoColors.surfaceVariant),
        borderRadius: BorderRadius.circular(EcoRadius.lg),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          _Dato(
            icono: Icons.recycling,
            texto: solicitud.tipoMaterial.label,
            colorIcono: EcoColors.primary,
          ),
          _Dato(
            icono: solicitud.esGratis
                ? Icons.volunteer_activism_outlined
                : Icons.payments_outlined,
            texto: solicitud.esGratis
                ? 'Gratis'
                : solicitud.precioLabel.split(' ').first,
            colorIcono: EcoColors.primary,
            colorTexto: EcoColors.primary,
          ),
          _Dato(
            icono: Icons.route_outlined,
            texto: solicitud.distanciaLabel,
            colorIcono: EcoColors.onSurfaceVariant,
            colorTexto: EcoColors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.texto,
    required this.colorIcono,
    this.colorTexto = EcoColors.onSurface,
  });

  final IconData icono;
  final String texto;
  final Color colorIcono;
  final Color colorTexto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 18, color: colorIcono),
        const SizedBox(width: 6),
        Text(
          texto,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorTexto),
        ),
      ],
    );
  }
}
