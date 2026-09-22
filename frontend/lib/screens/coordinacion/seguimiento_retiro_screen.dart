import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../../models/solicitud.dart';
import '../../services/api_client.dart';
import '../../services/solicitudes_service.dart';
import '../../services/whatsapp_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/fecha_es.dart';
import '../../utils/sondeo.dart';
import '../../widgets/coordinacion/timeline_paso.dart';
import '../../widgets/picker/eco_chips.dart';
import '../../widgets/picker/eco_map.dart';
import '../solicitud_detalle_screen.dart';
import 'retiro_completado_screen.dart';

/// Screen 3 — Seguimiento del retiro.
///
/// Destino persistente mientras `estado == en_camino`: el ciudadano puede
/// volver a esta pantalla desde Inicio sin reiniciar el flujo. El mapa es
/// contextual (destino + última posición conocida del recolector), no
/// navegación ni ruteo real — ver `design-prompt.md`.
class SeguimientoRetiroScreen extends StatefulWidget {
  const SeguimientoRetiroScreen({super.key, required this.solicitud});

  final Solicitud solicitud;

  @override
  State<SeguimientoRetiroScreen> createState() => _SeguimientoRetiroScreenState();
}

class _SeguimientoRetiroScreenState extends State<SeguimientoRetiroScreen> {
  final _service = SolicitudesService(ApiClient.instance);
  late Solicitud _solicitud = widget.solicitud;
  bool _actualizando = false;

  /// Mantiene la ubicación del recolector y el timeline al día sin que el
  /// ciudadano tenga que deslizar para refrescar — el pull-to-refresh manual
  /// sigue disponible como respaldo si el sondeo falla.
  late final _sondeo = Sondeo(intervalo: const Duration(seconds: 15), accion: _sondear);

  @override
  void initState() {
    super.initState();
    _sondeo.iniciar();
  }

  @override
  void dispose() {
    _sondeo.detener();
    super.dispose();
  }

  Future<void> _sondear() async {
    if (_actualizando) return;
    try {
      final actualizada = await _service.obtener(_solicitud.id);
      if (!mounted) return;

      if (actualizada.estado == EstadoSolicitud.completada) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => RetiroCompletadoScreen(solicitud: actualizada)),
        );
        return;
      }
      setState(() => _solicitud = actualizada);
    } catch (_) {
      // sondeo de fondo — un fallo puntual no debe interrumpir la pantalla.
    }
  }

  Future<void> _actualizar() async {
    setState(() => _actualizando = true);
    try {
      final actualizada = await _service.obtener(_solicitud.id);
      if (!mounted) return;

      if (actualizada.estado == EstadoSolicitud.completada) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => RetiroCompletadoScreen(solicitud: actualizada)),
        );
        return;
      }
      setState(() => _solicitud = actualizada);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos actualizar el estado. Intenta de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _actualizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recolector = _solicitud.recolector;
    final ubicacion = _solicitud.recolectorUbicacion;
    final nombre = recolector?.nombre ?? 'El recolector';

    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento del retiro')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _actualizar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              EcoSpacing.container, EcoSpacing.stack, EcoSpacing.container, EcoSpacing.section,
            ),
            children: [
              _TarjetaEstado(solicitud: _solicitud, nombre: nombre, actualizando: _actualizando),
              const SizedBox(height: EcoSpacing.stack),
              if (recolector != null) _MiniPerfilRecolector(recolector: recolector),
              const SizedBox(height: EcoSpacing.stack),
              _MapaTrayecto(solicitud: _solicitud, ubicacion: ubicacion),
              const SizedBox(height: EcoSpacing.stack),
              _Progreso(solicitud: _solicitud, nombre: nombre),
              const SizedBox(height: EcoSpacing.stack),
              _DatosDelRetiro(solicitud: _solicitud),
              const SizedBox(height: EcoSpacing.section),
              if (recolector != null) _AccionesContacto(recolector: recolector, nombre: nombre),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaEstado extends StatelessWidget {
  const _TarjetaEstado({required this.solicitud, required this.nombre, required this.actualizando});

  final Solicitud solicitud;
  final String nombre;
  final bool actualizando;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final actualizadoEn = solicitud.recolectorUbicacion?.actualizadoEn;

    return Card(
      color: EcoColors.mintLight.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(EcoSpacing.stack),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const EstadoChip(
                  texto: 'En tránsito',
                  color: EcoColors.primary,
                  fondo: EcoColors.mintLight,
                  latente: true,
                ),
                if (actualizando)
                  const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (actualizadoEn != null)
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: EcoColors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('Actualizado ${haceTiempo(actualizadoEn)}', style: textos.labelSmall),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: EcoSpacing.stack),
            Text('$nombre está en camino', style: textos.headlineMedium),
            const SizedBox(height: EcoSpacing.element),
            Text('Ten listas tus bolsas para una entrega rápida y segura.', style: textos.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MiniPerfilRecolector extends StatelessWidget {
  const _MiniPerfilRecolector({required this.recolector});

  final Recolector recolector;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: EcoSpacing.stack, vertical: EcoSpacing.element),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: EcoColors.secondaryContainer,
              backgroundImage: recolector.fotoUrl != null && recolector.fotoUrl!.isNotEmpty
                  ? NetworkImage(recolector.fotoUrl!)
                  : null,
              child: recolector.fotoUrl == null || recolector.fotoUrl!.isEmpty
                  ? const Icon(Icons.person, size: 20, color: EcoColors.onSecondaryContainer)
                  : null,
            ),
            const SizedBox(width: EcoSpacing.stack),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(recolector.nombre, style: textos.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(width: EcoSpacing.element),
                      const Icon(Icons.verified, size: 16, color: EcoColors.primary),
                    ],
                  ),
                  if (recolector.calificacionPromedio != null)
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: EcoColors.warningAmber),
                        const SizedBox(width: 2),
                        Text(
                          '${recolector.calificacionPromedio} (${recolector.totalCompletadas} retiros completados)',
                          style: textos.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapaTrayecto extends StatelessWidget {
  const _MapaTrayecto({required this.solicitud, required this.ubicacion});

  final Solicitud solicitud;
  final UbicacionRecolector? ubicacion;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final puntoRecolector = ubicacion != null ? ll.LatLng(ubicacion!.latitud, ubicacion!.longitud) : null;
    final distanciaKm = puntoRecolector != null
        ? const ll.Distance().as(
            ll.LengthUnit.Kilometer,
            puntoRecolector,
            ll.LatLng(solicitud.latitud, solicitud.longitud),
          )
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EcoSpacing.element),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: EcoSpacing.element, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Trayecto de retiro', style: textos.labelLarge),
                  if (puntoRecolector != null)
                    Text('Aproximación en vivo', style: textos.labelSmall),
                ],
              ),
            ),
            const SizedBox(height: EcoSpacing.element),
            MapaUbicacion(
              latitud: solicitud.latitud,
              longitud: solicitud.longitud,
              altura: 176,
              ubicacionSecundaria: puntoRecolector,
              overlay: TarjetaDireccion(
                direccion: solicitud.direccionReferencia.isEmpty
                    ? 'Punto de retiro'
                    : solicitud.direccionReferencia,
                detalle: distanciaKm == null
                    ? 'Sin ubicación reciente del recolector'
                    : 'A ${distanciaKm < 1 ? '${(distanciaKm * 1000).round()} m' : '${distanciaKm.toStringAsFixed(1)} km'}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Progreso extends StatelessWidget {
  const _Progreso({required this.solicitud, required this.nombre});

  final Solicitud solicitud;
  final String nombre;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final inicio = solicitud.ventanaInicio;
    final fin = solicitud.ventanaFin;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EcoSpacing.stack),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ESTADO DEL PROGRESO',
              style: textos.labelSmall?.copyWith(color: EcoColors.outline, letterSpacing: 1.1),
            ),
            const SizedBox(height: EcoSpacing.stack),
            const TimelinePaso(
              icono: Icons.check,
              titulo: 'Solicitud aceptada',
              estado: EstadoPaso.completado,
            ),
            TimelinePaso(
              icono: Icons.check,
              titulo: 'Horario confirmado',
              estado: EstadoPaso.completado,
              detalle: inicio != null && fin != null
                  ? '${fechaLarga(inicio)} · ${horaCorta(inicio)} – ${horaCorta(fin)}'
                  : null,
            ),
            TimelinePaso(
              icono: Icons.local_shipping_outlined,
              titulo: 'En camino',
              estado: EstadoPaso.activo,
              detalle: 'Te avisaremos con una alerta en cuanto toque tu timbre.',
            ),
            const TimelinePaso(
              icono: Icons.inventory_2_outlined,
              titulo: 'Material recogido',
              estado: EstadoPaso.pendiente,
              detalle: 'Confirmación de pesaje y entrega final',
              esUltimo: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _DatosDelRetiro extends StatelessWidget {
  const _DatosDelRetiro({required this.solicitud});

  final Solicitud solicitud;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final inicio = solicitud.ventanaInicio;
    final fin = solicitud.ventanaFin;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EcoSpacing.stack),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Datos del retiro', style: textos.labelLarge),
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SolicitudDetalleScreen(solicitudId: solicitud.id),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text('Ver detalle', style: textos.labelMedium?.copyWith(color: EcoColors.primary)),
                      const Icon(Icons.chevron_right, size: 16, color: EcoColors.primary),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: EcoSpacing.stack),
            Wrap(
              spacing: EcoSpacing.element,
              runSpacing: EcoSpacing.element,
              children: [
                _EtiquetaDato(icono: Icons.recycling, texto: solicitud.tipoMaterial.label),
                if (inicio != null && fin != null)
                  _EtiquetaDato(
                    icono: Icons.schedule,
                    texto: '${horaCorta(inicio)} – ${horaCorta(fin)}',
                  ),
              ],
            ),
            const SizedBox(height: EcoSpacing.stack),
            _EtiquetaDato(
              icono: Icons.location_on_outlined,
              texto: solicitud.direccionReferencia.isEmpty
                  ? 'Sin dirección de referencia'
                  : solicitud.direccionReferencia,
              expandir: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Botones apilados "Contactar (WhatsApp)" / "Llamar" — solo visibles cuando
/// `estado == en_camino` (regla del `design-prompt.md`), lo que ya se cumple
/// siempre en esta pantalla.
class _AccionesContacto extends StatelessWidget {
  const _AccionesContacto({required this.recolector, required this.nombre});

  final Recolector recolector;
  final String nombre;

  Future<void> _whatsapp(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await WhatsAppService.contactar(
        recolector.telefono,
        '¡Hola $nombre! Te escribo por el retiro que está en camino.',
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _llamar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await launchUrl(Uri(scheme: 'tel', path: recolector.telefono))) {
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

    return Column(
      children: [
        FilledButton.icon(
          onPressed: () => _whatsapp(context),
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: Text('Contactar a $nombre (WhatsApp)'),
        ),
        const SizedBox(height: EcoSpacing.stack),
        OutlinedButton.icon(
          onPressed: () => _llamar(context),
          icon: const Icon(Icons.call_outlined, size: 18),
          label: Text('Llamar a $nombre'),
        ),
      ],
    );
  }
}

class _EtiquetaDato extends StatelessWidget {
  const _EtiquetaDato({required this.icono, required this.texto, this.expandir = false});

  final IconData icono;
  final String texto;
  final bool expandir;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expandir ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: EcoSpacing.stack, vertical: EcoSpacing.element),
      decoration: BoxDecoration(
        color: EcoColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(EcoRadius.lg),
      ),
      child: Row(
        mainAxisSize: expandir ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: EcoColors.onSurfaceVariant),
          const SizedBox(width: EcoSpacing.element),
          Flexible(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: EcoColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
