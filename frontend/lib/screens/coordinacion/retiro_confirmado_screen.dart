import 'package:flutter/material.dart';

import '../../models/solicitud.dart';
import '../../services/api_client.dart';
import '../../services/solicitudes_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/fecha_es.dart';
import '../../utils/sondeo.dart';
import '../../widgets/coordinacion/contacto_recolector_row.dart';
import '../../widgets/picker/eco_chips.dart';
import '../solicitud_detalle_screen.dart';
import 'elegir_franja_screen.dart';
import 'seguimiento_retiro_screen.dart';

/// Screen 2 — Retiro confirmado.
///
/// Dos variantes según `estadoCoordinacion`: "esperando confirmación" justo
/// después de que el ciudadano propone una franja, y "confirmada" una vez que
/// el recolector la acepta. Es una pantalla transicional: una vez que
/// `estado` pasa a `en_camino`, el destino persistente pasa a ser
/// `SeguimientoRetiroScreen` (Screen 3).
///
/// Sondea el backend mientras está abierta para reflejar lo que haga el
/// Recolector (aceptar la franja, contraproponer, salir en camino) sin que
/// el Ciudadano tenga que salir y volver a entrar.
class RetiroConfirmadoScreen extends StatefulWidget {
  const RetiroConfirmadoScreen({super.key, required this.solicitud});

  final Solicitud solicitud;

  @override
  State<RetiroConfirmadoScreen> createState() => _RetiroConfirmadoScreenState();
}

class _RetiroConfirmadoScreenState extends State<RetiroConfirmadoScreen> {
  final _service = SolicitudesService(ApiClient.instance);
  late Solicitud _solicitud = widget.solicitud;

  late final _sondeo = Sondeo(intervalo: const Duration(seconds: 8), accion: _refrescar);

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

  Future<void> _refrescar() async {
    try {
      final actualizada = await _service.obtener(_solicitud.id);
      if (!mounted) return;

      if (actualizada.estado == EstadoSolicitud.enCamino) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => SeguimientoRetiroScreen(solicitud: actualizada)),
        );
        return;
      }
      if (actualizada.estadoCoordinacion == EstadoCoordinacion.propuestaRecolector &&
          _solicitud.estadoCoordinacion != EstadoCoordinacion.propuestaRecolector) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ElegirFranjaScreen(solicitud: actualizada)),
        );
        return;
      }
      setState(() => _solicitud = actualizada);
    } catch (_) {
      // sondeo de fondo — un fallo puntual no debe interrumpir la pantalla.
    }
  }

  bool get _confirmada => _solicitud.estadoCoordinacion == EstadoCoordinacion.confirmada;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final solicitud = _solicitud;
    final recolector = solicitud.recolector;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de retiro'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: EcoSpacing.container),
            child: Center(
              child: EstadoChip(
                texto: _confirmada ? 'Confirmado' : 'Esperando confirmación',
                color: _confirmada ? EcoColors.primary : EcoColors.onSecondaryFixedVariant,
                fondo: _confirmada ? EcoColors.mintLight : EcoColors.warningAmber.withValues(alpha: 0.2),
                latente: !_confirmada,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            EcoSpacing.container, EcoSpacing.section, EcoSpacing.container, EcoSpacing.section,
          ),
          children: [
            _Hero(confirmada: _confirmada, solicitud: solicitud),
            const SizedBox(height: EcoSpacing.section),
            _TarjetaHorario(solicitud: solicitud, confirmada: _confirmada),
            const SizedBox(height: EcoSpacing.stack),
            if (recolector != null) ...[
              _TarjetaRecolector(recolector: recolector),
              const SizedBox(height: EcoSpacing.stack),
            ],
            _ResumenPedido(solicitud: solicitud),
            const SizedBox(height: EcoSpacing.stack),
            Container(
              padding: const EdgeInsets.all(EcoSpacing.stack),
              decoration: BoxDecoration(
                color: EcoColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(EcoRadius.lg),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 18, color: EcoColors.warningAmber),
                  const SizedBox(width: EcoSpacing.stack),
                  Expanded(
                    child: Text(
                      'Deja las botellas limpias, secas y aplastadas para facilitar la carga rápida.',
                      style: textos.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: EcoSpacing.section),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => ElegirFranjaScreen(solicitud: solicitud)),
              ),
              icon: const Icon(Icons.edit_calendar_outlined, size: 20),
              label: Text(_confirmada ? 'Cambiar horario' : 'Editar disponibilidad'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.confirmada, required this.solicitud});

  final bool confirmada;
  final Solicitud solicitud;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final inicio = solicitud.ventanaInicio;
    final fin = solicitud.ventanaFin;
    final nombre = solicitud.recolector?.nombre ?? 'El recolector';

    String subtitulo;
    if (!confirmada) {
      subtitulo = '$nombre confirmará el horario pronto.';
    } else if (inicio != null && fin != null) {
      final dia = etiquetaDia(inicio, DateTime.now()).split(',').first.toLowerCase();
      subtitulo = '$nombre pasará $dia entre las ${horaCorta(inicio)} y ${horaCorta(fin)}.';
    } else {
      subtitulo = 'Coordina el horario para tu retiro.';
    }

    return Column(
      children: [
        Container(
          width: 72, height: 72,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: EcoColors.mintLight),
          child: Icon(
            confirmada ? Icons.check_circle : Icons.mark_email_read_outlined,
            size: 40, color: EcoColors.primary,
          ),
        ),
        const SizedBox(height: EcoSpacing.stack),
        Text(
          confirmada ? '¡Todo listo para tu retiro!' : 'Disponibilidad enviada',
          textAlign: TextAlign.center,
          style: textos.headlineLarge,
        ),
        const SizedBox(height: EcoSpacing.element),
        Text(subtitulo, textAlign: TextAlign.center, style: textos.bodyMedium),
      ],
    );
  }
}

class _TarjetaHorario extends StatelessWidget {
  const _TarjetaHorario({required this.solicitud, required this.confirmada});

  final Solicitud solicitud;
  final bool confirmada;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final inicio = solicitud.ventanaInicio;
    final fin = solicitud.ventanaFin;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EcoSpacing.stack),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: EcoColors.mintLight),
              child: const Icon(Icons.calendar_month, color: EcoColors.primary, size: 22),
            ),
            const SizedBox(width: EcoSpacing.stack),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    confirmada ? 'HORARIO ESTIMADO' : 'FRANJA PROPUESTA',
                    style: textos.labelSmall?.copyWith(color: EcoColors.outline, letterSpacing: 1.1),
                  ),
                  const SizedBox(height: 4),
                  if (inicio != null)
                    Text(fechaLarga(inicio), style: textos.headlineMedium)
                  else
                    Text('Sin franja todavía', style: textos.headlineMedium),
                  if (inicio != null && fin != null) ...[
                    const SizedBox(height: EcoSpacing.element),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: EcoColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(EcoRadius.lg),
                      ),
                      child: Text(
                        '${horaCorta(inicio)} – ${horaCorta(fin)}',
                        style: textos.labelLarge?.copyWith(color: EcoColors.onSurface),
                      ),
                    ),
                  ],
                  const SizedBox(height: EcoSpacing.stack),
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, size: 15, color: EcoColors.outline),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Te avisaremos cuando esté en camino.', style: textos.bodySmall),
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

class _TarjetaRecolector extends StatelessWidget {
  const _TarjetaRecolector({required this.recolector});

  final Recolector recolector;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EcoSpacing.stack),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tu recolector asignado', style: textos.labelLarge),
                const EstadoChip(
                  texto: 'Verificado',
                  color: EcoColors.primary,
                  fondo: EcoColors.mintLight,
                ),
              ],
            ),
            const SizedBox(height: EcoSpacing.stack),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: EcoColors.secondaryContainer,
                  backgroundImage: recolector.fotoUrl != null && recolector.fotoUrl!.isNotEmpty
                      ? NetworkImage(recolector.fotoUrl!)
                      : null,
                  child: recolector.fotoUrl == null || recolector.fotoUrl!.isEmpty
                      ? const Icon(Icons.person, color: EcoColors.onSecondaryContainer)
                      : null,
                ),
                const SizedBox(width: EcoSpacing.stack),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recolector.nombre, style: textos.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      if (recolector.calificacionPromedio != null)
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 16, color: EcoColors.warningAmber),
                            const SizedBox(width: 2),
                            Text(
                              '${recolector.calificacionPromedio} · ${recolector.totalCompletadas} retiros exitosos',
                              style: textos.bodySmall,
                            ),
                          ],
                        )
                      else
                        Text('Sin calificaciones aún', style: textos.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: EcoSpacing.stack),
            ContactoRecolectorRow(recolector: recolector),
          ],
        ),
      ),
    );
  }
}

class _ResumenPedido extends StatelessWidget {
  const _ResumenPedido({required this.solicitud});

  final Solicitud solicitud;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EcoSpacing.stack),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen del pedido', style: textos.labelLarge),
            const SizedBox(height: EcoSpacing.stack),
            _FilaResumen(
              icono: Icons.inventory_2_outlined,
              titulo: 'Material registrado',
              valor: solicitud.tipoMaterial.label,
            ),
            const SizedBox(height: EcoSpacing.stack),
            _FilaResumen(
              icono: Icons.location_on_outlined,
              titulo: 'Punto de retiro',
              valor: solicitud.direccionReferencia.isEmpty
                  ? 'Sin dirección de referencia'
                  : solicitud.direccionReferencia,
            ),
            const SizedBox(height: EcoSpacing.stack),
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SolicitudDetalleScreen(solicitudId: solicitud.id),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Ver detalle de solicitud',
                    style: textos.labelLarge?.copyWith(color: EcoColors.primary),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: EcoColors.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({required this.icono, required this.titulo, required this.valor});

  final IconData icono;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 20, color: EcoColors.outline),
        const SizedBox(width: EcoSpacing.stack),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: textos.bodySmall),
              Text(valor, style: textos.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
