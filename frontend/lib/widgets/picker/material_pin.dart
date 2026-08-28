import 'package:flutter/material.dart';

import '../../models/solicitud.dart';
import '../../theme/app_theme.dart';

/// Pin de una solicitud sobre el mapa.
///
/// El pin seleccionado se dibuja en verde con la etiqueta de precio y un pulso
/// que lo separa del resto; los demás quedan en blanco con solo el material,
/// para que el mapa no se sature cuando hay varias solicitudes juntas.
class MaterialPin extends StatefulWidget {
  const MaterialPin({
    super.key,
    required this.solicitud,
    required this.seleccionado,
    required this.onTap,
  });

  final Solicitud solicitud;
  final bool seleccionado;
  final VoidCallback onTap;

  /// Tamaño reservado al marcador en el mapa. Debe alcanzar para la etiqueta
  /// más larga, porque `flutter_map` recorta lo que se salga de esta caja.
  static const Size tamano = Size(160, 76);

  @override
  State<MaterialPin> createState() => _MaterialPinState();
}

class _MaterialPinState extends State<MaterialPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.seleccionado) _pulso.repeat();
  }

  @override
  void didUpdateWidget(MaterialPin anterior) {
    super.didUpdateWidget(anterior);
    if (widget.seleccionado && !_pulso.isAnimating) {
      _pulso.repeat();
    } else if (!widget.seleccionado && _pulso.isAnimating) {
      _pulso.stop();
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seleccionado = widget.seleccionado;

    return Semantics(
      button: true,
      selected: seleccionado,
      label:
          '${widget.solicitud.tipoMaterial.label}, '
          '${widget.solicitud.precioLabel}, '
          'a ${widget.solicitud.distanciaLabel}',
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Etiqueta(solicitud: widget.solicitud, seleccionado: seleccionado),
            _Punta(seleccionado: seleccionado),
            _Base(seleccionado: seleccionado, pulso: _pulso),
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.solicitud, required this.seleccionado});

  final Solicitud solicitud;
  final bool seleccionado;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.labelMedium!;

    if (!seleccionado) {
      return _Contenedor(
        color: EcoColors.surface,
        borde: EcoColors.surfaceVariant,
        child: Text(
          solicitud.tipoMaterial.label,
          style: estilo.copyWith(color: EcoColors.onSurface),
        ),
      );
    }

    final resumen = solicitud.esGratis
        ? solicitud.tipoMaterial.label
        : '${solicitud.tipoMaterial.label} · ${solicitud.precioLabel.split(' ').first}';

    return _Contenedor(
      color: EcoColors.primary,
      borde: EcoColors.leafDark,
      sombra: EcoShadows.raised,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.recycling, size: 18, color: EcoColors.onPrimary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              resumen,
              overflow: TextOverflow.ellipsis,
              style: estilo.copyWith(color: EcoColors.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Contenedor extends StatelessWidget {
  const _Contenedor({
    required this.color,
    required this.borde,
    required this.child,
    this.sombra,
  });

  final Color color;
  final Color borde;
  final Widget child;
  final List<BoxShadow>? sombra;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borde),
        borderRadius: BorderRadius.circular(EcoRadius.xl),
        boxShadow: sombra ?? EcoShadows.ambient,
      ),
      child: child,
    );
  }
}

/// Triángulo que une la etiqueta con el punto exacto del mapa.
class _Punta extends StatelessWidget {
  const _Punta({required this.seleccionado});

  final bool seleccionado;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -4),
      child: Transform.rotate(
        angle: 0.785398, // 45° — el cuadrado rotado del diseño.
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: seleccionado ? EcoColors.primary : EcoColors.surface,
            border: Border.all(
              color: seleccionado ? EcoColors.leafDark : EcoColors.surfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Punto anclado a la coordenada real, con el pulso del pin seleccionado.
class _Base extends StatelessWidget {
  const _Base({required this.seleccionado, required this.pulso});

  final bool seleccionado;
  final Animation<double> pulso;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      width: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (seleccionado)
            AnimatedBuilder(
              animation: pulso,
              builder: (context, _) {
                return Container(
                  width: 12 + 28 * pulso.value,
                  height: 12 + 28 * pulso.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: EcoColors.primary.withValues(
                      alpha: 0.25 * (1 - pulso.value),
                    ),
                  ),
                );
              },
            ),
          Container(
            width: seleccionado ? 14 : 10,
            height: seleccionado ? 14 : 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: seleccionado ? EcoColors.primary : EcoColors.outline,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: EcoShadows.ambient,
            ),
          ),
        ],
      ),
    );
  }
}
