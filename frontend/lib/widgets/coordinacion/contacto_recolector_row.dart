import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/solicitud.dart';
import '../../services/whatsapp_service.dart';
import '../../theme/app_theme.dart';

/// Botones "WhatsApp" / "Llamar" para que el Ciudadano contacte al Recolector
/// asignado (Screens 2 y 3 del Flujo 4) — sentido inverso de
/// `widgets/picker/whatsapp_button.dart`, que es del Recolector al Ciudadano.
class ContactoRecolectorRow extends StatelessWidget {
  const ContactoRecolectorRow({
    super.key,
    required this.recolector,
    this.mensaje = '¡Hola! Te escribo por mi solicitud de retiro en EcoRecicla.',
  });

  final Recolector recolector;
  final String mensaje;

  Future<void> _whatsapp(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await WhatsAppService.contactar(recolector.telefono, mensaje);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _llamar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(scheme: 'tel', path: recolector.telefono);
    if (!await launchUrl(uri)) {
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo abrir el marcador.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!recolector.tieneTelefono) {
      return Container(
        padding: const EdgeInsets.all(EcoSpacing.stack),
        decoration: BoxDecoration(
          color: EcoColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(EcoRadius.lg),
        ),
        child: Text(
          'El recolector aún no registró un teléfono de contacto.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _whatsapp(context),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('WhatsApp'),
          ),
        ),
        const SizedBox(width: EcoSpacing.stack),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _llamar(context),
            icon: const Icon(Icons.call_outlined, size: 18),
            label: const Text('Llamar'),
          ),
        ),
      ],
    );
  }
}
