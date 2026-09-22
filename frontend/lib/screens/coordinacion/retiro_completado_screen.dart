import 'package:flutter/material.dart';

import '../../models/solicitud.dart';
import '../../services/api_client.dart';
import '../../services/solicitudes_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/fecha_es.dart';
import '../../widgets/coordinacion/calificacion_estrellas.dart';
import '../../widgets/picker/eco_chips.dart';

const _etiquetasDisponibles = ['Puntual', 'Amable y respetuoso', 'Cuidado del material'];

/// Screen 4 — Retiro completado y calificación (versión "solo calificación",
/// ver `retiro-completado-rediseno-prompt.md`).
///
/// Los EcoPuntos ya se acreditaron cuando el Recolector completó el retiro
/// (`completar()`, sin cambios respecto al Flujo 3) — esta pantalla no
/// confirma ni condiciona nada, solo informa y ofrece calificar.
class RetiroCompletadoScreen extends StatefulWidget {
  const RetiroCompletadoScreen({super.key, required this.solicitud});

  final Solicitud solicitud;

  @override
  State<RetiroCompletadoScreen> createState() => _RetiroCompletadoScreenState();
}

class _RetiroCompletadoScreenState extends State<RetiroCompletadoScreen> {
  final _service = SolicitudesService(ApiClient.instance);
  final _comentarioController = TextEditingController();

  int _estrellas = 0;
  final Set<String> _etiquetas = {};
  bool _enviando = false;
  MiCalificacion? _yaCalificado;

  @override
  void initState() {
    super.initState();
    _yaCalificado = widget.solicitud.miCalificacion;
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _enviarCalificacion() async {
    if (_estrellas == 0 || _enviando) return;

    setState(() => _enviando = true);
    try {
      final asignacion = await _service.calificar(
        widget.solicitud.id,
        estrellas: _estrellas,
        etiquetas: _etiquetas.toList(),
        comentario: _comentarioController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _yaCalificado = MiCalificacion(
          estrellas: asignacion.calificacion!,
          etiquetas: asignacion.calificacionEtiquetas,
          comentario: asignacion.calificacionComentario,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Gracias por tu calificación!')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar la calificación: $error')),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final solicitud = widget.solicitud;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Retiro completado'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            EcoSpacing.container, EcoSpacing.section, EcoSpacing.container, EcoSpacing.section,
          ),
          children: [
            const _Hero(),
            const SizedBox(height: EcoSpacing.section),
            _ResumenRetiro(solicitud: solicitud),
            const SizedBox(height: EcoSpacing.stack),
            if (solicitud.puntosAcreditados != null)
              _BloqueEcoPuntos(puntos: solicitud.puntosAcreditados!),
            const SizedBox(height: EcoSpacing.section),
            _Calificacion(
              nombreRecolector: solicitud.recolector?.nombre ?? 'tu recolector',
              yaCalificado: _yaCalificado,
              estrellas: _estrellas,
              etiquetas: _etiquetas,
              comentarioController: _comentarioController,
              enviando: _enviando,
              onEstrellas: (valor) => setState(() => _estrellas = valor),
              onToggleEtiqueta: (etiqueta) => setState(() {
                _etiquetas.contains(etiqueta) ? _etiquetas.remove(etiqueta) : _etiquetas.add(etiqueta);
              }),
              onEnviar: _enviarCalificacion,
            ),
            if (_yaCalificado == null) ...[
              const SizedBox(height: EcoSpacing.stack),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Ahora no'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Column(
      children: [
        Container(
          width: 72, height: 72,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: EcoColors.mintLight),
          child: const Icon(Icons.check_circle, size: 40, color: EcoColors.primary),
        ),
        const SizedBox(height: EcoSpacing.stack),
        Text('¡Tu material ya fue recogido!', textAlign: TextAlign.center, style: textos.headlineLarge),
        const SizedBox(height: EcoSpacing.element),
        Text(
          'Gracias por darle una nueva vida a tus reciclables.',
          textAlign: TextAlign.center,
          style: textos.bodyMedium,
        ),
      ],
    );
  }
}

class _ResumenRetiro extends StatelessWidget {
  const _ResumenRetiro({required this.solicitud});

  final Solicitud solicitud;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final recolector = solicitud.recolector;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EcoSpacing.stack),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recolector != null) ...[
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
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
                        Row(
                          children: [
                            Text(recolector.nombre, style: textos.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 16, color: EcoColors.primary),
                          ],
                        ),
                        Text('Recolector asignado', style: textos.bodySmall),
                      ],
                    ),
                  ),
                  const EstadoChip(texto: 'Verificado', color: EcoColors.primary, fondo: EcoColors.mintLight),
                ],
              ),
              const SizedBox(height: EcoSpacing.stack),
              const Divider(),
              const SizedBox(height: EcoSpacing.stack),
            ],
            Row(
              children: [
                Expanded(
                  child: _EstadisticaChica(
                    icono: Icons.recycling,
                    etiqueta: 'Material',
                    valor: solicitud.tipoMaterial.label,
                  ),
                ),
                const SizedBox(width: EcoSpacing.stack),
                Expanded(
                  child: _EstadisticaChica(
                    icono: Icons.scale_outlined,
                    etiqueta: 'Peso registrado',
                    valor: solicitud.pesoKg != null ? '${solicitud.pesoKg} kg' : 'Peso por validar',
                  ),
                ),
              ],
            ),
            const SizedBox(height: EcoSpacing.stack),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 15, color: EcoColors.outline),
                const SizedBox(width: 6),
                if (solicitud.actualizadoEn != null)
                  Text(fechaHoraCorta(solicitud.actualizadoEn!), style: textos.bodySmall),
                const SizedBox(width: EcoSpacing.stack),
                const Icon(Icons.location_on_outlined, size: 15, color: EcoColors.outline),
                const SizedBox(width: 6),
                Text('Retiro domiciliario', style: textos.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadisticaChica extends StatelessWidget {
  const _EstadisticaChica({required this.icono, required this.etiqueta, required this.valor});

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(EcoSpacing.element),
      decoration: BoxDecoration(
        color: EcoColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(EcoRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 14, color: EcoColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(etiqueta, style: textos.labelSmall),
            ],
          ),
          const SizedBox(height: 2),
          Text(valor, style: textos.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: EcoColors.primary)),
        ],
      ),
    );
  }
}

class _BloqueEcoPuntos extends StatelessWidget {
  const _BloqueEcoPuntos({required this.puntos});

  final int puntos;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(EcoSpacing.stack),
      decoration: BoxDecoration(
        color: EcoColors.mintLight,
        borderRadius: BorderRadius.circular(EcoRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: EcoColors.primary, size: 20),
          const SizedBox(width: EcoSpacing.stack),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+$puntos EcoPuntos acreditados a tu cuenta',
                  style: textos.labelLarge?.copyWith(color: EcoColors.primary),
                ),
                Text('Disponibles ahora mismo en tu balance', style: textos.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Calificacion extends StatelessWidget {
  const _Calificacion({
    required this.nombreRecolector,
    required this.yaCalificado,
    required this.estrellas,
    required this.etiquetas,
    required this.comentarioController,
    required this.enviando,
    required this.onEstrellas,
    required this.onToggleEtiqueta,
    required this.onEnviar,
  });

  final String nombreRecolector;
  final MiCalificacion? yaCalificado;
  final int estrellas;
  final Set<String> etiquetas;
  final TextEditingController comentarioController;
  final bool enviando;
  final ValueChanged<int> onEstrellas;
  final ValueChanged<String> onToggleEtiqueta;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final soloLectura = yaCalificado != null;
    final etiquetasMostradas = soloLectura ? yaCalificado!.etiquetas.toSet() : etiquetas;
    final valorEstrellas = soloLectura ? yaCalificado!.estrellas : estrellas;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EcoSpacing.stack),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EstadoChip(
              texto: 'Valoración ciudadana',
              color: EcoColors.primary,
              fondo: EcoColors.mintLight,
            ),
            const SizedBox(height: EcoSpacing.stack),
            Text('¿Cómo fue tu experiencia con $nombreRecolector?', style: textos.headlineMedium),
            const SizedBox(height: EcoSpacing.element),
            Text(
              'Tu opinión reconoce el trabajo del reciclador de tu barrio.',
              style: textos.bodySmall,
            ),
            const SizedBox(height: EcoSpacing.stack),
            CalificacionEstrellas(
              valor: valorEstrellas,
              onChanged: soloLectura ? null : onEstrellas,
            ),
            const SizedBox(height: EcoSpacing.stack),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: EcoSpacing.element,
              runSpacing: EcoSpacing.element,
              children: _etiquetasDisponibles.map((etiqueta) {
                final seleccionada = etiquetasMostradas.contains(etiqueta);
                return ChoiceChip(
                  label: Text(etiqueta),
                  selected: seleccionada,
                  onSelected: soloLectura ? null : (_) => onToggleEtiqueta(etiqueta),
                  selectedColor: EcoColors.secondaryContainer,
                  labelStyle: textos.labelMedium?.copyWith(
                    color: seleccionada ? EcoColors.primary : EcoColors.onSurfaceVariant,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: EcoSpacing.stack),
            if (soloLectura)
              if (yaCalificado!.comentario.isNotEmpty) Text(yaCalificado!.comentario, style: textos.bodySmall)
              else const SizedBox.shrink()
            else
              TextField(
                controller: comentarioController,
                minLines: 2,
                maxLines: 3,
                maxLength: 200,
                decoration: const InputDecoration(hintText: 'Cuéntanos más (opcional)'),
              ),
            if (!soloLectura) ...[
              const SizedBox(height: EcoSpacing.stack),
              FilledButton.icon(
                onPressed: estrellas == 0 || enviando ? null : onEnviar,
                icon: enviando
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: EcoColors.onPrimary),
                      )
                    : const Icon(Icons.send, size: 18),
                label: const Text('Enviar calificación'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
