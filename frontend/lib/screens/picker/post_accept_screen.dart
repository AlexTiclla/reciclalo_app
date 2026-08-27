import 'package:flutter/material.dart';

import '../../models/solicitud.dart';
import '../../services/api_client.dart';
import '../../services/maps_service.dart';
import '../../services/picker_events.dart';
import '../../services/picker_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/picker/eco_chips.dart';
import '../../widgets/picker/eco_map.dart';
import '../../widgets/picker/whatsapp_button.dart';

/// Ruta de recolección: confirmación de que la solicitud quedó aceptada, con
/// los accesos a navegación y contacto, y el cierre del retiro.
class PostAcceptScreen extends StatefulWidget {
  const PostAcceptScreen({super.key, required this.solicitud});

  final Solicitud solicitud;

  @override
  State<PostAcceptScreen> createState() => _PostAcceptScreenState();
}

class _PostAcceptScreenState extends State<PostAcceptScreen>
    with SingleTickerProviderStateMixin {
  final _pickerService = PickerService(ApiClient.instance);

  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..forward();

  bool _completando = false;

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  Future<void> _navegar() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await MapsService.navegarHacia(
        widget.solicitud.latitud,
        widget.solicitud.longitud,
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _completar() async {
    setState(() => _completando = true);
    try {
      await _pickerService.completar(widget.solicitud.id);
      PickerEvents.instance.notificarCambio();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Retiro completado! Gracias por reciclar.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo completar el retiro: $error')),
      );
      setState(() => _completando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final solicitud = widget.solicitud;
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EcoRecicla Recolector'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: EcoSpacing.container),
            child: Center(
              child: EstadoChip(
                texto: 'Aceptado',
                color: EcoColors.statusBlue,
                fondo: EcoColors.statusBlue.withValues(alpha: 0.1),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _entrada,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: _entrada, curve: Curves.easeOut)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                EcoSpacing.container,
                EcoSpacing.section,
                EcoSpacing.container,
                EcoSpacing.section,
              ),
              children: [
                _Exito(solicitud: solicitud, animacion: _entrada),
                const SizedBox(height: EcoSpacing.section),
                MapaUbicacion(
                  latitud: solicitud.latitud,
                  longitud: solicitud.longitud,
                  altura: 256,
                  overlay: TarjetaDireccion(
                    direccion: solicitud.direccionReferencia.isEmpty
                        ? 'Punto de retiro'
                        : solicitud.direccionReferencia,
                    detalle: solicitud.distanciaKm == null
                        ? 'Toca "Ir a Google Maps" para navegar'
                        : 'A ${solicitud.distanciaLabel} de distancia',
                  ),
                ),
                const SizedBox(height: EcoSpacing.stack),
                Row(
                  children: [
                    Expanded(
                      child: BotonAccionCuadrado(
                        icono: Icons.directions,
                        colorIcono: EcoColors.primary,
                        etiqueta: 'Ir a Google Maps',
                        onPressed: _navegar,
                      ),
                    ),
                    const SizedBox(width: EcoSpacing.element),
                    Expanded(
                      child: WhatsAppButton(
                        solicitud: solicitud,
                        compacto: true,
                        mensaje: '¡Hola! Ya acepté tu solicitud de '
                            '${solicitud.tipoMaterial.label} y voy en camino. '
                            '¿Dónde exactamente está el material?',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: EcoSpacing.stack),
                Text(
                  'Cuando termines el retiro, márcalo como completado para '
                  'que el ciudadano vea que ya pasaste.',
                  textAlign: TextAlign.center,
                  style: textos.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: EcoColors.surface,
          border: Border(top: BorderSide(color: EcoColors.surfaceVariant)),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.all(EcoSpacing.container),
          child: FilledButton.icon(
            onPressed: _completando ? null : _completar,
            icon: _completando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: EcoColors.onPrimary,
                    ),
                  )
                : const Icon(Icons.check),
            label: const Text('Marcar como completado'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(EcoRadius.xl),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Exito extends StatelessWidget {
  const _Exito({required this.solicitud, required this.animacion});

  final Solicitud solicitud;
  final Animation<double> animacion;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Column(
      children: [
        ScaleTransition(
          scale: CurvedAnimation(parent: animacion, curve: Curves.elasticOut),
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: EcoColors.mintLight,
            ),
            child: const Icon(Icons.check_circle, size: 36, color: EcoColors.primary),
          ),
        ),
        const SizedBox(height: EcoSpacing.stack),
        Text(
          '¡Solicitud aceptada!',
          textAlign: TextAlign.center,
          style: textos.headlineLarge,
        ),
        const SizedBox(height: EcoSpacing.stack),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: EcoSpacing.stack, vertical: 8),
          decoration: BoxDecoration(
            color: EcoColors.surfaceContainer,
            borderRadius: BorderRadius.circular(EcoRadius.lg),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(solicitud.tipoMaterial.label, style: textos.bodyLarge),
              const SizedBox(width: EcoSpacing.element),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: EcoColors.outline,
                ),
              ),
              const SizedBox(width: EcoSpacing.element),
              Text(
                solicitud.esGratis ? 'Gratis' : solicitud.precioLabel.split(' ').first,
                style: textos.bodyLarge?.copyWith(
                  color: EcoColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
