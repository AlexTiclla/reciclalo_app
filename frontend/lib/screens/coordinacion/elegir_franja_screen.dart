import 'package:flutter/material.dart';

import '../../models/solicitud.dart';
import '../../services/api_client.dart';
import '../../services/solicitudes_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/fecha_es.dart';
import '../../utils/sondeo.dart';
import 'retiro_confirmado_screen.dart';
import 'seguimiento_retiro_screen.dart';

class _FranjaFija {
  const _FranjaFija(this.icono, this.etiqueta, this.horaInicio, this.horaFin, {this.popular = false});

  final IconData icono;
  final String etiqueta;
  final int horaInicio;
  final int horaFin;
  final bool popular;

  String get horario =>
      '${horaInicio.toString().padLeft(2, '0')}:00 – ${horaFin.toString().padLeft(2, '0')}:00';
}

const _franjasFijas = [
  _FranjaFija(Icons.wb_sunny_outlined, 'Mañana', 8, 11),
  _FranjaFija(Icons.light_mode_outlined, 'Mediodía', 11, 14),
  _FranjaFija(Icons.wb_twilight_outlined, 'Tarde', 15, 18, popular: true),
  _FranjaFija(Icons.bedtime_outlined, 'Noche', 18, 20),
];

/// Screen 1 — Elegir franja de retiro.
///
/// También sirve como pantalla de "el recolector propuso otra franja"
/// (`estadoCoordinacion == propuestaRecolector`): en ese modo la grilla de
/// selección se reemplaza por una tarjeta destacada con la propuesta y las
/// acciones "Aceptar horario" / "Elegir otro" (ver `design-prompt.md`).
class ElegirFranjaScreen extends StatefulWidget {
  const ElegirFranjaScreen({super.key, required this.solicitud});

  final Solicitud solicitud;

  @override
  State<ElegirFranjaScreen> createState() => _ElegirFranjaScreenState();
}

class _ElegirFranjaScreenState extends State<ElegirFranjaScreen> {
  final _service = SolicitudesService(ApiClient.instance);
  final _notasController = TextEditingController();

  late final DateTime _hoy = DateTime.now();
  late final List<DateTime> _dias = [
    DateTime(_hoy.year, _hoy.month, _hoy.day),
    DateTime(_hoy.year, _hoy.month, _hoy.day + 1),
    DateTime(_hoy.year, _hoy.month, _hoy.day + 2),
  ];

  int _diaIndice = 1;
  int? _franjaIndice = 2;
  DateTime? _inicioPersonalizado;
  DateTime? _finPersonalizado;

  /// `false` mientras se muestre la tarjeta "el recolector propone…".
  bool _modoSeleccionLibre = false;

  bool _enviando = false;

  late Solicitud _solicitud = widget.solicitud;

  /// Sondea mientras el ciudadano decide, para reflejar si el recolector
  /// contrapropone una franja (o directamente confirma/sale en camino)
  /// mientras esta pantalla sigue abierta.
  late final _sondeo = Sondeo(intervalo: const Duration(seconds: 8), accion: _refrescar);

  @override
  void initState() {
    super.initState();
    _modoSeleccionLibre =
        _solicitud.estadoCoordinacion != EstadoCoordinacion.propuestaRecolector;
    _sondeo.iniciar();
  }

  @override
  void dispose() {
    _notasController.dispose();
    _sondeo.detener();
    super.dispose();
  }

  Future<void> _refrescar() async {
    if (_enviando) return;
    try {
      final actualizada = await _service.obtener(_solicitud.id);
      if (!mounted) return;

      if (actualizada.estado == EstadoSolicitud.enCamino) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => SeguimientoRetiroScreen(solicitud: actualizada)),
        );
        return;
      }
      if (actualizada.estadoCoordinacion == EstadoCoordinacion.confirmada) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => RetiroConfirmadoScreen(solicitud: actualizada)),
        );
        return;
      }
      if (actualizada.estadoCoordinacion != _solicitud.estadoCoordinacion) {
        setState(() {
          _solicitud = actualizada;
          _modoSeleccionLibre =
              actualizada.estadoCoordinacion != EstadoCoordinacion.propuestaRecolector;
        });
      } else {
        _solicitud = actualizada;
      }
    } catch (_) {
      // sondeo de fondo — un fallo puntual no debe interrumpir la pantalla.
    }
  }

  DateTime? get _inicioElegido {
    if (_inicioPersonalizado != null) return _inicioPersonalizado;
    if (_franjaIndice == null) return null;
    final dia = _dias[_diaIndice];
    final franja = _franjasFijas[_franjaIndice!];
    return DateTime(dia.year, dia.month, dia.day, franja.horaInicio);
  }

  DateTime? get _finElegido {
    if (_finPersonalizado != null) return _finPersonalizado;
    if (_franjaIndice == null) return null;
    final dia = _dias[_diaIndice];
    final franja = _franjasFijas[_franjaIndice!];
    return DateTime(dia.year, dia.month, dia.day, franja.horaFin);
  }

  String get _etiquetaCta {
    final inicio = _inicioElegido;
    if (inicio == null) return 'Elige una franja';
    final etiquetaDiaTexto = etiquetaDia(inicio, _hoy).split(',').first.toLowerCase();
    final fin = _finElegido!;
    return 'Confirmar: $etiquetaDiaTexto, ${horaCorta(inicio)}–${horaCorta(fin)}';
  }

  Future<void> _proponerHorarioPersonalizado() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _hoy,
      firstDate: _hoy,
      lastDate: _hoy.add(const Duration(days: 30)),
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

    setState(() {
      _inicioPersonalizado = inicio;
      _finPersonalizado = fin;
      _franjaIndice = null;
    });
  }

  Future<void> _confirmar() async {
    final inicio = _inicioElegido;
    final fin = _finElegido;
    if (inicio == null || fin == null || _enviando) return;

    setState(() => _enviando = true);
    try {
      final actualizada = await _service.proponerFranja(
        _solicitud.id,
        inicio: inicio,
        fin: fin,
        notas: _notasController.text.trim(),
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disponibilidad enviada. Te avisaremos cuando el recolector confirme.'),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RetiroConfirmadoScreen(solicitud: actualizada)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar la disponibilidad: $error')),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _aceptarPropuestaDelRecolector() async {
    setState(() => _enviando = true);
    try {
      final actualizada = await _service.aceptarFranja(_solicitud.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RetiroConfirmadoScreen(solicitud: actualizada)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo aceptar el horario: $error')),
      );
      setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('¿Cuándo puedes entregar?')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            EcoSpacing.container, EcoSpacing.stack, EcoSpacing.container, EcoSpacing.section,
          ),
          children: [
            _TarjetaSolicitud(solicitud: _solicitud),
            const SizedBox(height: EcoSpacing.section),
            if (!_modoSeleccionLibre)
              _PropuestaDelRecolector(
                solicitud: _solicitud,
                enviando: _enviando,
                onAceptar: _aceptarPropuestaDelRecolector,
                onElegirOtro: () => setState(() => _modoSeleccionLibre = true),
              )
            else ...[
              Text(
                'Elige una franja en la que alguien pueda entregar el material.',
                style: textos.headlineMedium,
              ),
              const SizedBox(height: EcoSpacing.element),
              Text(
                'El recolector sabrá con certeza cuándo pasar a recogerlo sin esperas.',
                style: textos.bodySmall,
              ),
              const SizedBox(height: EcoSpacing.section),
              Text('¿Qué día prefieres?', style: textos.labelLarge),
              const SizedBox(height: EcoSpacing.stack),
              Row(
                children: List.generate(_dias.length, (indice) {
                  final seleccionado = _franjaIndice != null && _diaIndice == indice;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: indice == _dias.length - 1 ? 0 : EcoSpacing.element),
                      child: _ChipDia(
                        texto: etiquetaDia(_dias[indice], _hoy),
                        seleccionado: seleccionado,
                        onTap: () => setState(() {
                          _diaIndice = indice;
                          _franjaIndice ??= 2;
                          _inicioPersonalizado = null;
                          _finPersonalizado = null;
                        }),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: EcoSpacing.section),
              Text('Franja horaria disponible', style: textos.labelLarge),
              const SizedBox(height: EcoSpacing.stack),
              ...List.generate(_franjasFijas.length, (indice) {
                final franja = _franjasFijas[indice];
                final seleccionada = _franjaIndice == indice;
                return Padding(
                  padding: const EdgeInsets.only(bottom: EcoSpacing.element),
                  child: _OpcionFranja(
                    franja: franja,
                    seleccionada: seleccionada,
                    onTap: () => setState(() {
                      _franjaIndice = indice;
                      _inicioPersonalizado = null;
                      _finPersonalizado = null;
                    }),
                  ),
                );
              }),
              const SizedBox(height: EcoSpacing.stack),
              OutlinedButton.icon(
                onPressed: _proponerHorarioPersonalizado,
                icon: const Icon(Icons.calendar_month_outlined, size: 20),
                label: const Text('Proponer otro horario'),
              ),
              const SizedBox(height: EcoSpacing.section),
              Text('Indicaciones para el recolector', style: textos.labelLarge),
              const SizedBox(height: EcoSpacing.stack),
              TextField(
                controller: _notasController,
                minLines: 2,
                maxLines: 3,
                maxLength: 280,
                decoration: const InputDecoration(
                  hintText: 'Ej: Tocar timbre del portón azul, preguntar por Carlos...',
                  prefixIcon: Icon(Icons.speaker_notes_outlined),
                ),
              ),
              const SizedBox(height: EcoSpacing.element),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: EcoColors.statusBlue),
                  const SizedBox(width: EcoSpacing.element),
                  Expanded(
                    child: Text(
                      'El recolector verificará tus notas antes de aproximarse.',
                      style: textos.labelSmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _modoSeleccionLibre
          ? Container(
              decoration: const BoxDecoration(
                color: EcoColors.surface,
                border: Border(top: BorderSide(color: EcoColors.surfaceVariant)),
              ),
              child: SafeArea(
                minimum: const EdgeInsets.all(EcoSpacing.container),
                child: FilledButton.icon(
                  onPressed: _inicioElegido == null || _enviando ? null : _confirmar,
                  icon: _enviando
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: EcoColors.onPrimary),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_etiquetaCta),
                ),
              ),
            )
          : null,
    );
  }
}

class _TarjetaSolicitud extends StatelessWidget {
  const _TarjetaSolicitud({required this.solicitud});

  final Solicitud solicitud;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EcoSpacing.element),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(EcoRadius.lg),
              child: Container(
                width: 56, height: 56,
                color: EcoColors.surfaceContainer,
                child: solicitud.fotoUrl.isNotEmpty
                    ? Image.network(solicitud.fotoUrl, fit: BoxFit.cover)
                    : Icon(solicitud.tipoMaterial.icon, color: EcoColors.outline),
              ),
            ),
            const SizedBox(width: EcoSpacing.stack),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(solicitud.tipoMaterial.label, style: textos.labelLarge),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: EcoColors.primary),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          solicitud.direccionReferencia.isEmpty
                              ? 'Sin dirección de referencia'
                              : solicitud.direccionReferencia,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textos.bodySmall,
                        ),
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

class _ChipDia extends StatelessWidget {
  const _ChipDia({required this.texto, required this.seleccionado, required this.onTap});

  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionado ? EcoColors.primary : EcoColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(EcoRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(EcoRadius.xl),
        onTap: onTap,
        child: Container(
          height: EcoSpacing.touchTarget,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: EcoSpacing.element),
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: seleccionado ? EcoColors.onPrimary : EcoColors.onSurfaceVariant,
                ),
          ),
        ),
      ),
    );
  }
}

class _OpcionFranja extends StatelessWidget {
  const _OpcionFranja({required this.franja, required this.seleccionada, required this.onTap});

  final _FranjaFija franja;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Material(
      color: seleccionada ? EcoColors.mintLight : EcoColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(EcoRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(EcoRadius.xl),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: EcoSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: EcoSpacing.stack, vertical: EcoSpacing.element),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: seleccionada ? EcoColors.primary : EcoColors.surfaceContainer,
                ),
                child: Icon(
                  franja.icono, size: 18,
                  color: seleccionada ? EcoColors.onPrimary : EcoColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: EcoSpacing.stack),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          franja.etiqueta,
                          style: textos.bodyMedium?.copyWith(
                            color: seleccionada ? EcoColors.primary : EcoColors.onSurface,
                            fontWeight: seleccionada ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        if (franja.popular) ...[
                          const SizedBox(width: EcoSpacing.element),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: EcoColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(EcoRadius.lg),
                            ),
                            child: Text('Popular', style: textos.labelSmall?.copyWith(color: EcoColors.primary)),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      franja.horario,
                      style: textos.bodySmall?.copyWith(
                        color: seleccionada ? EcoColors.leafDark : EcoColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: seleccionada ? EcoColors.primary : EcoColors.surfaceContainer,
                ),
                child: seleccionada
                    ? const Icon(Icons.check, size: 16, color: EcoColors.onPrimary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropuestaDelRecolector extends StatelessWidget {
  const _PropuestaDelRecolector({
    required this.solicitud,
    required this.enviando,
    required this.onAceptar,
    required this.onElegirOtro,
  });

  final Solicitud solicitud;
  final bool enviando;
  final VoidCallback onAceptar;
  final VoidCallback onElegirOtro;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final inicio = solicitud.ventanaInicio;
    final fin = solicitud.ventanaFin;
    final nombre = solicitud.recolector?.nombre ?? 'El recolector';

    return Card(
      color: EcoColors.mintLight,
      child: Padding(
        padding: const EdgeInsets.all(EcoSpacing.container),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$nombre propone:', style: textos.labelLarge?.copyWith(color: EcoColors.primary)),
            const SizedBox(height: EcoSpacing.element),
            if (inicio != null && fin != null)
              Text(
                '${etiquetaDia(inicio, DateTime.now())}, ${horaCorta(inicio)}–${horaCorta(fin)}',
                style: textos.headlineMedium,
              ),
            const SizedBox(height: EcoSpacing.section),
            FilledButton(
              onPressed: enviando ? null : onAceptar,
              child: const Text('Aceptar horario'),
            ),
            const SizedBox(height: EcoSpacing.stack),
            OutlinedButton(
              onPressed: enviando ? null : onElegirOtro,
              child: const Text('Elegir otro'),
            ),
          ],
        ),
      ),
    );
  }
}
