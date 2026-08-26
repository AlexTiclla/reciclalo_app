import 'package:flutter/material.dart';

import '../../models/solicitud.dart';
import '../../services/whatsapp_service.dart';
import '../../theme/app_theme.dart';

/// Botón de contacto por WhatsApp con los colores de marca.
///
/// Queda deshabilitado cuando el ciudadano no dejó teléfono, en lugar de
/// fallar al pulsarlo.
class WhatsAppButton extends StatelessWidget {
  const WhatsAppButton({
    super.key,
    required this.solicitud,
    this.mensaje = '¡Hola! Soy tu recolector de EcoRecicla. '
        '¿Dónde exactamente está el material para el retiro?',
    this.compacto = false,
  });

  final Solicitud solicitud;
  final String mensaje;

  /// `true` dibuja el botón cuadrado de la pantalla de ruta (icono sobre texto).
  final bool compacto;

  Future<void> _contactar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await WhatsAppService.contactar(solicitud.telefonoContacto, mensaje);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final habilitado = solicitud.tieneTelefono;
    final onPressed = habilitado ? () => _contactar(context) : null;
    final textos = Theme.of(context).textTheme;

    if (compacto) {
      return BotonAccionCuadrado(
        icono: Icons.chat_bubble_outline,
        colorIcono: habilitado ? EcoColors.whatsapp : EcoColors.outline,
        etiqueta: 'Contactar por WhatsApp',
        onPressed: onPressed,
      );
    }

    return Tooltip(
      message: habilitado
          ? 'Abrir WhatsApp con el ciudadano'
          : 'El ciudadano no dejó un número de contacto',
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.chat_bubble_outline, size: 20),
        label: const Text('Contactar por WhatsApp'),
        style: OutlinedButton.styleFrom(
          foregroundColor: EcoColors.whatsappDark,
          disabledForegroundColor: EcoColors.outline,
          backgroundColor: habilitado
              ? EcoColors.whatsapp.withValues(alpha: 0.1)
              : EcoColors.surfaceContainerHigh,
          minimumSize: const Size.fromHeight(EcoSpacing.touchTarget),
          textStyle: textos.labelLarge,
          side: BorderSide(
            color: habilitado
                ? EcoColors.whatsapp.withValues(alpha: 0.3)
                : EcoColors.surfaceVariant,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EcoRadius.lg),
          ),
        ),
      ),
    );
  }
}

/// Celda de acción del bento: icono grande sobre etiqueta a dos líneas.
class BotonAccionCuadrado extends StatelessWidget {
  const BotonAccionCuadrado({
    super.key,
    required this.icono,
    required this.colorIcono,
    required this.etiqueta,
    required this.onPressed,
  });

  final IconData icono;
  final Color colorIcono;
  final String etiqueta;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Material(
        color: EcoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(EcoRadius.xl),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(EcoRadius.xl),
          child: Container(
            height: 96,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: EcoColors.surfaceVariant),
              borderRadius: BorderRadius.circular(EcoRadius.xl),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono, size: 26, color: colorIcono),
                const SizedBox(height: EcoSpacing.element),
                Text(
                  etiqueta,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: onPressed == null
                            ? EcoColors.outline
                            : EcoColors.onSurface,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
