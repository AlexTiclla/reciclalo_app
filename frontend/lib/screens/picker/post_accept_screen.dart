import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/solicitud.dart';
import '../../services/api_client.dart';
import '../../services/location_service.dart';
import '../../services/maps_service.dart';
import '../../services/picker_events.dart';
import '../../services/picker_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/fecha_es.dart';
import '../../utils/sondeo.dart';
import '../../widgets/picker/eco_chips.dart';
import '../../widgets/picker/eco_map.dart';
import '../../widgets/picker/whatsapp_button.dart';

/// Ruta de recolección: confirmación de que la solicitud quedó aceptada, con
/// los accesos a navegación y contacto, y el cierre del retiro.
///
/// Esta pantalla no está rediseñada por el `design-prompt.md` del Flujo 4
/// (es exclusivo del Ciudadano) — la sección de coordinación de franja y el
/// botón "Voy en camino" son agregados deliberadamente utilitarios, para que
/// el otro lado de la conversación del Ciudadano exista.
class PostAcceptScreen extends StatefulWidget {
  const PostAcceptScreen({super.key, required this.solicitud});

  final Solicitud solicitud;

  @override
  State<PostAcceptScreen> createState() => _PostAcceptScreenState();
}

class _PostAcceptScreenState extends State<PostAcceptScreen>
    with SingleTickerProviderStateMixin {
  final _pickerService = PickerService(ApiClient.instance);
  final _locationService = LocationService();

  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..forward();

  late Solicitud _solicitud = widget.solicitud;
  bool _completando = false;
  bool _coordinando = false;
  Timer? _pingUbicacion;

  /// El ciudadano puede proponer/aceptar una franja mientras esta pantalla
  /// sigue abierta — sin esto, el recolector solo se enteraba al salir y
  /// volver a entrar (a veces dos veces, según qué tan viejo estaba el caché
  /// de la lista anterior).
  late final _sondeoEstado = Sondeo(
    intervalo: const Duration(seconds: 8),
    accion: _refrescarEstado,
  );

  @override
  void initState() {
    super.initState();
    if (_solicitud.estado == EstadoSolicitud.enCamino) _iniciarPingUbicacion();
    _sondeoEstado.iniciar();
  }

  @override
  void dispose() {
    _entrada.dispose();
    _pingUbicacion?.cancel();
    _sondeoEstado.detener();
    super.dispose();
  }

  /// A diferencia de las acciones del usuario, un sondeo fallido no debe
  /// interrumpir nada — se reintenta solo en el próximo ciclo.
  Future<void> _refrescarEstado() async {
    if (_completando || _coordinando || _solicitud.estado == EstadoSolicitud.completada) return;
    try {
      final actualizada = await _pickerService.obtenerDetalle(_solicitud.id);
      if (!mounted) return;
      final estadoAnterior = _solicitud.estado;
      if (actualizada.estado != estadoAnterior ||
          actualizada.estadoCoordinacion != _solicitud.estadoCoordinacion) {
        setState(() => _solicitud = actualizada);
        if (actualizada.estado == EstadoSolicitud.enCamino &&
            estadoAnterior != EstadoSolicitud.enCamino) {
          _iniciarPingUbicacion();
        }
      }
    } catch (_) {
      // silencioso — no molestar con un sondeo de fondo.
    }
  }

  void _iniciarPingUbicacion() {
    _pingUbicacion?.cancel();
    _pingUbicacion = Timer.periodic(const Duration(seconds: 45), (_) async {
      try {
        final posicion = await _locationService.obtenerUbicacionActual();
        await _pickerService.actualizarUbicacion(posicion.latitude, posicion.longitude);
      } catch (_) {
        // Un ping fallido no debe interrumpir la ruta; se reintenta en el próximo ciclo.
      }
    });
  }

  Future<double?> _pedirPesoKg() {
    final controlador = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Peso entregado'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Peso (kg)',
            hintText: 'Ej. 3.5',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final peso = double.tryParse(controlador.text.replaceAll(',', '.'));
              Navigator.of(context).pop(peso != null && peso > 0 ? peso : null);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
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
    final pesoKg = await _pedirPesoKg();
    if (pesoKg == null) return;

    setState(() => _completando = true);
    try {
      await _pickerService.completar(widget.solicitud.id, pesoKg: pesoKg);
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

  Future<void> _proponerHorario() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (fecha == null || !mounted) return;

    final horaInicio = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Hora de inicio',
    );
    if (horaInicio == null || !mounted) return;

    final horaFin = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (horaInicio.hour + 2) % 24, minute: horaInicio.minute),
      helpText: 'Hora de fin',
    );
    if (horaFin == null) return;

    final inicio = DateTime(fecha.year, fecha.month, fecha.day, horaInicio.hour, horaInicio.minute);
    var fin = DateTime(fecha.year, fecha.month, fecha.day, horaFin.hour, horaFin.minute);
    if (!fin.isAfter(inicio)) fin = fin.add(const Duration(days: 1));

    setState(() => _coordinando = true);
    try {
      final actualizada = await _pickerService.proponerFranja(
        _solicitud.id, inicio: inicio, fin: fin,
      );
      if (!mounted) return;
      setState(() => _solicitud = actualizada);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo proponer el horario: $error')),
      );
    } finally {
      if (mounted) setState(() => _coordinando = false);
    }
  }

  Future<void> _aceptarFranja() async {
    setState(() => _coordinando = true);
    try {
      final actualizada = await _pickerService.aceptarFranja(_solicitud.id);
      if (!mounted) return;
      setState(() => _solicitud = actualizada);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo aceptar el horario: $error')),
      );
    } finally {
      if (mounted) setState(() => _coordinando = false);
    }
  }

  Future<void> _irEnCamino() async {
    setState(() => _coordinando = true);
    try {
      final actualizada = await _pickerService.enCamino(_solicitud.id);
      PickerEvents.instance.notificarCambio();
      if (!mounted) return;
      setState(() => _solicitud = actualizada);
      _iniciarPingUbicacion();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo iniciar la ruta: $error')),
      );
    } finally {
      if (mounted) setState(() => _coordinando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final solicitud = _solicitud;
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EcoRecicla Recolector'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: EcoSpacing.container),
            child: Center(
              child: EstadoChip(
                texto: solicitud.estado == EstadoSolicitud.enCamino ? 'En camino' : 'Aceptado',
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
                _BannerCoordinacion(
                  solicitud: solicitud,
                  procesando: _coordinando,
                  onProponer: _proponerHorario,
                  onAceptar: _aceptarFranja,
                  onIrEnCamino: _irEnCamino,
                ),
                const SizedBox(height: EcoSpacing.stack),
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
                if (solicitud.estado == EstadoSolicitud.enCamino)
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
          child: solicitud.estado == EstadoSolicitud.enCamino
              ? FilledButton.icon(
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
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_clock_outlined, size: 18, color: EcoColors.outline),
                    const SizedBox(width: EcoSpacing.element),
                    Flexible(
                      child: Text(
                        'Coordina el horario y toca "Voy en camino" para poder completar el retiro.',
                        textAlign: TextAlign.center,
                        style: textos.bodySmall,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Estado de la coordinación de franja + el botón "Voy en camino" — ver nota
/// de la clase sobre por qué esto es utilitario y no un rediseño.
class _BannerCoordinacion extends StatelessWidget {
  const _BannerCoordinacion({
    required this.solicitud,
    required this.procesando,
    required this.onProponer,
    required this.onAceptar,
    required this.onIrEnCamino,
  });

  final Solicitud solicitud;
  final bool procesando;
  final VoidCallback onProponer;
  final VoidCallback onAceptar;
  final VoidCallback onIrEnCamino;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    if (solicitud.estado == EstadoSolicitud.enCamino) {
      return Container(
        padding: const EdgeInsets.all(EcoSpacing.stack),
        decoration: BoxDecoration(
          color: EcoColors.mintLight,
          borderRadius: BorderRadius.circular(EcoRadius.lg),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_shipping, color: EcoColors.primary),
            const SizedBox(width: EcoSpacing.stack),
            Expanded(
              child: Text('Estás en camino. Tu ubicación se comparte con el ciudadano.', style: textos.bodySmall),
            ),
          ],
        ),
      );
    }

    switch (solicitud.estadoCoordinacion) {
      case EstadoCoordinacion.confirmada:
        final inicio = solicitud.ventanaInicio;
        final fin = solicitud.ventanaFin;
        return Container(
          padding: const EdgeInsets.all(EcoSpacing.stack),
          decoration: BoxDecoration(
            color: EcoColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(EcoRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Franja confirmada', style: textos.labelLarge),
              if (inicio != null && fin != null)
                Text(
                  '${fechaLarga(inicio)} · ${horaCorta(inicio)} – ${horaCorta(fin)}',
                  style: textos.bodySmall,
                ),
              const SizedBox(height: EcoSpacing.stack),
              FilledButton.icon(
                onPressed: procesando ? null : onIrEnCamino,
                icon: const Icon(Icons.directions_run, size: 18),
                label: const Text('Voy en camino'),
              ),
            ],
          ),
        );

      case EstadoCoordinacion.propuestaCiudadano:
        final inicio = solicitud.ventanaInicio;
        final fin = solicitud.ventanaFin;
        return Container(
          padding: const EdgeInsets.all(EcoSpacing.stack),
          decoration: BoxDecoration(
            color: EcoColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(EcoRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('El ciudadano propone una franja', style: textos.labelLarge),
              if (inicio != null && fin != null)
                Text(
                  '${fechaLarga(inicio)} · ${horaCorta(inicio)} – ${horaCorta(fin)}',
                  style: textos.bodySmall,
                ),
              const SizedBox(height: EcoSpacing.stack),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: procesando ? null : onAceptar,
                      child: const Text('Aceptar'),
                    ),
                  ),
                  const SizedBox(width: EcoSpacing.stack),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: procesando ? null : onProponer,
                      child: const Text('Proponer otro'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case EstadoCoordinacion.propuestaRecolector:
        return Container(
          padding: const EdgeInsets.all(EcoSpacing.stack),
          decoration: BoxDecoration(
            color: EcoColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(EcoRadius.lg),
          ),
          child: Text(
            'Le propusiste una franja al ciudadano. Te avisaremos cuando la confirme.',
            style: textos.bodySmall,
          ),
        );

      case EstadoCoordinacion.pendiente:
        return OutlinedButton.icon(
          onPressed: procesando ? null : onProponer,
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: const Text('Proponer horario'),
        );
    }
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
