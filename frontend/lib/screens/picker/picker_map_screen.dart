import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../models/solicitud.dart';
import '../../services/api_client.dart';
import '../../services/location_service.dart';
import '../../services/picker_events.dart';
import '../../services/picker_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/picker/confirm_accept_dialog.dart';
import '../../widgets/picker/eco_chips.dart';
import '../../widgets/picker/eco_map.dart';
import '../../widgets/picker/material_pin.dart';
import '../../widgets/picker/request_preview_sheet.dart';
import 'post_accept_screen.dart';
import 'request_details_screen.dart';

/// Pantalla principal del recolector: mapa con las solicitudes cercanas.
///
/// Al tocar un pin se abre la vista previa; desde ahí se entra al detalle o se
/// acepta directamente.
class PickerMapScreen extends StatefulWidget {
  const PickerMapScreen({super.key, this.radioKm = 5});

  final double radioKm;

  @override
  State<PickerMapScreen> createState() => _PickerMapScreenState();
}

class _PickerMapScreenState extends State<PickerMapScreen> {
  final _mapController = MapController();
  final _pickerService = PickerService(ApiClient.instance);
  final _locationService = LocationService();

  StreamSubscription<Position>? _suscripcionUbicacion;

  LatLng? _miUbicacion;
  List<Solicitud> _solicitudes = const [];
  Solicitud? _seleccionada;
  bool _cargando = true;
  bool _aceptando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _suscripcionUbicacion?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    try {
      final posicion = await _locationService.obtenerUbicacionActual();
      if (!mounted) return;
      setState(() => _miUbicacion = LatLng(posicion.latitude, posicion.longitude));

      await _cargarSolicitudes();
      _escucharUbicacion();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _cargando = false;
      });
    }
  }

  /// Reporta la posición al backend mientras el recolector se desplaza, para
  /// que las distancias que ve sigan siendo ciertas.
  void _escucharUbicacion() {
    _suscripcionUbicacion = _locationService.flujoUbicacion().listen((posicion) {
      if (!mounted) return;
      setState(() => _miUbicacion = LatLng(posicion.latitude, posicion.longitude));
      _pickerService
          .actualizarUbicacion(posicion.latitude, posicion.longitude)
          .ignore();
    });
  }

  Future<void> _cargarSolicitudes() async {
    final ubicacion = _miUbicacion;
    if (ubicacion == null) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final solicitudes = await _pickerService.solicitudesCercanas(
        latitud: ubicacion.latitude,
        longitud: ubicacion.longitude,
        radioKm: widget.radioKm,
      );
      if (!mounted) return;

      setState(() {
        _solicitudes = solicitudes;
        // Si la solicitud abierta ya no está disponible, se cierra la vista previa.
        _seleccionada = solicitudes
            .where((s) => s.id == _seleccionada?.id)
            .firstOrNull;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _cargando = false;
      });
    }
  }

  void _seleccionar(Solicitud solicitud) {
    setState(() => _seleccionada = solicitud);
    _mapController.move(
      LatLng(solicitud.latitud, solicitud.longitud),
      _mapController.camera.zoom,
    );
  }

  void _centrarEnMiUbicacion() {
    final ubicacion = _miUbicacion;
    if (ubicacion != null) _mapController.move(ubicacion, 15);
  }

  Future<void> _abrirDetalle(Solicitud solicitud) async {
    final aceptada = await Navigator.of(context).push<Solicitud>(
      MaterialPageRoute(
        builder: (_) => RequestDetailsScreen(solicitud: solicitud),
      ),
    );

    if (!mounted) return;
    if (aceptada != null) {
      await _irARuta(aceptada);
    } else {
      await _cargarSolicitudes();
    }
  }

  Future<void> _aceptarDesdeElMapa(Solicitud solicitud) async {
    if (!await confirmarAceptacion(context, solicitud)) return;
    if (!mounted) return;

    setState(() => _aceptando = true);
    try {
      final asignacion = await _pickerService.aceptar(solicitud.id);
      PickerEvents.instance.notificarCambio();
      if (!mounted) return;
      await _irARuta(asignacion.solicitud);
    } on SolicitudYaTomadaException catch (error) {
      if (!mounted) return;
      _avisar('$error');
      await _cargarSolicitudes();
    } catch (error) {
      if (!mounted) return;
      _avisar('No se pudo aceptar la solicitud: $error');
    } finally {
      if (mounted) setState(() => _aceptando = false);
    }
  }

  Future<void> _irARuta(Solicitud solicitud) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostAcceptScreen(solicitud: solicitud)),
    );
    if (!mounted) return;
    setState(() => _seleccionada = null);
    await _cargarSolicitudes();
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final seleccionada = _seleccionada;

    return Scaffold(
      backgroundColor: EcoColors.surface,
      body: Stack(
        children: [
          Positioned.fill(child: _construirMapa()),

          // Píldora de estado sobre el mapa.
          Positioned(
            top: MediaQuery.of(context).padding.top + EcoSpacing.element,
            left: 0,
            right: 0,
            child: Center(
              child: StatusPill(
                titulo: 'Solicitudes cerca',
                cantidad: _solicitudes.length,
              ),
            ),
          ),

          if (_error != null) _MensajeError(mensaje: _error!, onReintentar: _inicializar),

          // Botón de recentrado, elevado cuando la vista previa está abierta
          // para que no quede tapado por ella.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            right: EcoSpacing.container,
            bottom: seleccionada == null ? EcoSpacing.section : 180,
            child: _BotonUbicacion(onPressed: _centrarEnMiUbicacion),
          ),

          // Vista previa de la solicitud seleccionada.
          //
          // AnimatedSwitcher necesita límites explícitos: como hijo directo de
          // un Stack (sin Positioned) que también contiene un FlutterMap, deja
          // de componer cualquier frame y la pantalla completa se queda en
          // blanco en algunos dispositivos, aunque Flutter siga construyendo
          // y pintando el árbol con normalidad.
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animacion) => SlideTransition(
                position: Tween(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(animacion),
                child: child,
              ),
              child: seleccionada == null
                  ? const SizedBox.shrink()
                  : Align(
                      key: ValueKey(seleccionada.id),
                      alignment: Alignment.bottomCenter,
                      child: RequestPreviewSheet(
                        solicitud: seleccionada,
                        aceptando: _aceptando,
                        onAbrirDetalle: () => _abrirDetalle(seleccionada),
                        onAceptar: () => _aceptarDesdeElMapa(seleccionada),
                      ),
                    ),
            ),
          ),

          if (_cargando)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }

  Widget _construirMapa() {
    final ubicacion = _miUbicacion;
    if (ubicacion == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: ubicacion,
        initialZoom: 15,
        // Tocar el mapa fuera de un pin cierra la vista previa.
        onTap: (_, _) => setState(() => _seleccionada = null),
      ),
      children: [
        openStreetMapTiles(),
        MarkerLayer(markers: [_marcadorPropio(ubicacion)]),
        MarkerLayer(markers: _solicitudes.map(_marcadorSolicitud).toList()),
      ],
    );
  }

  Marker _marcadorPropio(LatLng ubicacion) {
    return Marker(
      point: ubicacion,
      width: 24,
      height: 24,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: EcoColors.statusBlue,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: EcoShadows.ambient,
        ),
      ),
    );
  }

  Marker _marcadorSolicitud(Solicitud solicitud) {
    return Marker(
      point: LatLng(solicitud.latitud, solicitud.longitud),
      width: MaterialPin.tamano.width,
      height: MaterialPin.tamano.height,
      // El pin apunta hacia abajo: su base debe caer sobre la coordenada.
      alignment: Alignment.topCenter,
      child: MaterialPin(
        solicitud: solicitud,
        seleccionado: solicitud.id == _seleccionada?.id,
        onTap: () => _seleccionar(solicitud),
      ),
    );
  }
}

class _BotonUbicacion extends StatelessWidget {
  const _BotonUbicacion({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: EcoColors.surface,
      foregroundColor: EcoColors.primary,
      elevation: 4,
      shape: const CircleBorder(),
      tooltip: 'Centrar en mi ubicación',
      child: const Icon(Icons.my_location),
    );
  }
}

class _MensajeError extends StatelessWidget {
  const _MensajeError({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(EcoSpacing.container),
        padding: const EdgeInsets.all(EcoSpacing.container),
        decoration: BoxDecoration(
          color: EcoColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(EcoRadius.xl),
          boxShadow: EcoShadows.ambient,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: EcoColors.outline, size: 32),
            const SizedBox(height: EcoSpacing.element),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: EcoSpacing.stack),
            FilledButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
