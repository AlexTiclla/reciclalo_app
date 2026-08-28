import 'package:flutter/material.dart';

import '../../models/solicitud.dart';
import '../../services/api_client.dart';
import '../../services/picker_events.dart';
import '../../services/picker_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/picker/confirm_accept_dialog.dart';
import '../../widgets/picker/eco_chips.dart';
import '../../widgets/picker/eco_map.dart';
import '../../widgets/picker/whatsapp_button.dart';

/// Detalle de una solicitud disponible, con la acción de aceptar y un cierre
/// simple que no afecta la solicitud: sigue disponible para otro recolector.
///
/// Devuelve la [Solicitud] ya aceptada al hacer `pop` si el recolector la toma,
/// y `null` si simplemente cierra la pantalla.
class RequestDetailsScreen extends StatefulWidget {
  const RequestDetailsScreen({super.key, required this.solicitud});

  final Solicitud solicitud;

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  final _pickerService = PickerService(ApiClient.instance);

  late Solicitud _solicitud = widget.solicitud;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _cargarDetalleCompleto();
  }

  /// La lista del mapa no trae teléfono ni descripción completa: se refresca el
  /// detalle para tener todo antes de que el recolector decida.
  Future<void> _cargarDetalleCompleto() async {
    try {
      final completa = await _pickerService.obtenerDetalle(widget.solicitud.id);
      if (!mounted) return;
      setState(() {
        // La distancia solo la calcula el listado del mapa; se conserva.
        _solicitud = completa.distanciaKm == null && _solicitud.distanciaKm != null
            ? _conDistancia(completa, _solicitud.distanciaKm!)
            : completa;
      });
    } catch (_) {
      // Se sigue mostrando lo que llegó del mapa; no vale interrumpir por esto.
    }
  }

  Solicitud _conDistancia(Solicitud solicitud, double distanciaKm) {
    return Solicitud(
      id: solicitud.id,
      tipoMaterial: solicitud.tipoMaterial,
      fotoUrl: solicitud.fotoUrl,
      latitud: solicitud.latitud,
      longitud: solicitud.longitud,
      direccionReferencia: solicitud.direccionReferencia,
      estado: solicitud.estado,
      recolector: solicitud.recolector,
      creadoEn: solicitud.creadoEn,
      precio: solicitud.precio,
      telefonoContacto: solicitud.telefonoContacto,
      ciudadanoNombre: solicitud.ciudadanoNombre,
      distanciaKm: distanciaKm,
    );
  }

  Future<void> _aceptar() async {
    if (!await confirmarAceptacion(context, _solicitud)) return;
    if (!mounted) return;

    setState(() => _procesando = true);
    try {
      final asignacion = await _pickerService.aceptar(_solicitud.id);
      PickerEvents.instance.notificarCambio();
      if (!mounted) return;
      Navigator.of(context).pop(asignacion.solicitud);
    } on SolicitudYaTomadaException catch (error) {
      if (!mounted) return;
      _avisar('$error');
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      _avisar('No se pudo aceptar la solicitud: $error');
      setState(() => _procesando = false);
    }
  }

  /// Cierra la pantalla sin tocar la solicitud: sigue disponible en el mapa
  /// para que este u otro recolector la acepte más tarde.
  void _cerrar() => Navigator.of(context).pop();

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle'),
        centerTitle: false,
        titleTextStyle: textos.headlineMedium,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: EcoSpacing.container),
            child: Center(
              child: EstadoChip(
                texto: 'Disponible',
                color: EcoColors.onSecondaryContainer,
                fondo: EcoColors.secondaryContainer,
                latente: true,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            EcoSpacing.container,
            EcoSpacing.element,
            EcoSpacing.container,
            EcoSpacing.section,
          ),
          children: [
            _Foto(solicitud: _solicitud),
            const SizedBox(height: EcoSpacing.stack),
            _Encabezado(solicitud: _solicitud),
            const SizedBox(height: EcoSpacing.section),
            const Divider(),
            const SizedBox(height: EcoSpacing.stack),
            _Ubicacion(solicitud: _solicitud),
            const SizedBox(height: EcoSpacing.section),
            WhatsAppButton(solicitud: _solicitud),
          ],
        ),
      ),
      bottomNavigationBar: _AccionesInferiores(
        procesando: _procesando,
        onCerrar: _cerrar,
        onAceptar: _aceptar,
      ),
    );
  }
}

class _Foto extends StatelessWidget {
  const _Foto({required this.solicitud});

  final Solicitud solicitud;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(EcoRadius.xl),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          color: EcoColors.surfaceContainerHigh,
          child: solicitud.fotoUrl.isEmpty
              ? Icon(solicitud.tipoMaterial.icon, size: 56, color: EcoColors.outline)
              : Image.network(
                  solicitud.fotoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, _) => Icon(
                    solicitud.tipoMaterial.icon,
                    size: 56,
                    color: EcoColors.outline,
                  ),
                ),
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.solicitud});

  final Solicitud solicitud;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(solicitud.tipoMaterial.label, style: textos.headlineLarge),
            ),
            const SizedBox(width: EcoSpacing.element),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: solicitud.esGratis
                    ? EcoColors.surfaceContainerHigh
                    : EcoColors.mintLight,
                borderRadius: BorderRadius.circular(EcoRadius.lg),
              ),
              child: Text(
                solicitud.precioLabel,
                style: textos.headlineMedium?.copyWith(
                  color: solicitud.esGratis
                      ? EcoColors.onSurfaceVariant
                      : EcoColors.primary,
                ),
              ),
            ),
          ],
        ),
        if (solicitud.ciudadanoNombre.isNotEmpty) ...[
          const SizedBox(height: EcoSpacing.element),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 18, color: EcoColors.outline),
              const SizedBox(width: 6),
              Text('Publicado por ${solicitud.ciudadanoNombre}', style: textos.bodySmall),
            ],
          ),
        ],
      ],
    );
  }
}

class _Ubicacion extends StatelessWidget {
  const _Ubicacion({required this.solicitud});

  final Solicitud solicitud;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final direccion = solicitud.direccionReferencia.isEmpty
        ? 'Sin dirección de referencia'
        : solicitud.direccionReferencia;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UBICACIÓN',
          style: textos.labelMedium?.copyWith(
            color: EcoColors.outline,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: EcoSpacing.stack),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: EcoColors.surfaceContainerLow,
            border: Border.all(color: EcoColors.surfaceVariant),
            borderRadius: BorderRadius.circular(EcoRadius.lg),
          ),
          child: Row(
            children: [
              Container(
                width: EcoSpacing.touchTarget,
                height: EcoSpacing.touchTarget,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: EcoColors.surfaceContainerHigh,
                ),
                child: const Icon(Icons.location_on, color: EcoColors.primary),
              ),
              const SizedBox(width: EcoSpacing.stack),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      direccion,
                      style: textos.labelMedium?.copyWith(color: EcoColors.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      solicitud.distanciaKm == null
                          ? 'Distancia no disponible'
                          : 'A ${solicitud.distanciaLabel} de tu ubicación actual',
                      style: textos.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: EcoSpacing.stack),
        MapaUbicacion(latitud: solicitud.latitud, longitud: solicitud.longitud),
      ],
    );
  }
}

/// Barra fija con las dos decisiones posibles, siempre al alcance del pulgar.
class _AccionesInferiores extends StatelessWidget {
  const _AccionesInferiores({
    required this.procesando,
    required this.onCerrar,
    required this.onAceptar,
  });

  final bool procesando;
  final VoidCallback onCerrar;
  final VoidCallback onAceptar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EcoColors.surface,
        border: Border(top: BorderSide(color: EcoColors.surfaceVariant)),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          EcoSpacing.container,
          EcoSpacing.stack,
          EcoSpacing.container,
          EcoSpacing.stack,
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: procesando ? null : onCerrar,
                child: const Text('Cerrar'),
              ),
            ),
            const SizedBox(width: EcoSpacing.stack),
            Expanded(
              child: FilledButton(
                onPressed: procesando ? null : onAceptar,
                style: FilledButton.styleFrom(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(EcoRadius.full),
                  ),
                ),
                child: procesando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: EcoColors.onPrimary,
                        ),
                      )
                    : const Text('Aceptar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
