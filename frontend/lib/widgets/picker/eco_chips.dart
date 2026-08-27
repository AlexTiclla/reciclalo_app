import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Píldora flotante del mapa: "Solicitudes cerca · N activas".
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.titulo, required this.cantidad});

  final String titulo;
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: EcoColors.surface.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.all(EcoRadius.full),
        border: Border.all(color: EcoColors.surfaceVariant),
        boxShadow: EcoShadows.ambient,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(titulo, style: textos.labelMedium?.copyWith(color: EcoColors.onSurface)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: const BoxDecoration(
              color: EcoColors.primaryContainer,
              borderRadius: BorderRadius.all(EcoRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _PuntoLatente(),
                const SizedBox(width: 6),
                Text(
                  '$cantidad ${cantidad == 1 ? 'activa' : 'activas'}',
                  style: textos.labelSmall?.copyWith(
                    color: EcoColors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Punto que late para indicar que el listado se mantiene al día.
class _PuntoLatente extends StatefulWidget {
  const _PuntoLatente();

  @override
  State<_PuntoLatente> createState() => _PuntoLatenteState();
}

class _PuntoLatenteState extends State<_PuntoLatente>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controlador),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: EcoColors.mintLight,
        ),
      ),
    );
  }
}

/// Etiqueta del pago acordado: verde menta con monto, o gris si es gratis.
class PrecioChip extends StatelessWidget {
  const PrecioChip({super.key, required this.texto, required this.esGratis});

  final String texto;
  final bool esGratis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: esGratis ? EcoColors.surfaceContainerHigh : EcoColors.mintLight,
        border: Border.all(
          color: esGratis ? EcoColors.surfaceVariant : EcoColors.secondaryContainer,
        ),
        borderRadius: const BorderRadius.all(EcoRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            esGratis ? Icons.volunteer_activism_outlined : Icons.payments_outlined,
            size: 14,
            color: esGratis ? EcoColors.onSurfaceVariant : EcoColors.onSecondaryFixedVariant,
          ),
          const SizedBox(width: 5),
          Text(
            texto,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: esGratis
                      ? EcoColors.onSurfaceVariant
                      : EcoColors.onSecondaryFixedVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// Chip de estado del encabezado ("Disponible", "Aceptado").
class EstadoChip extends StatelessWidget {
  const EstadoChip({
    super.key,
    required this.texto,
    required this.color,
    required this.fondo,
    this.latente = false,
  });

  final String texto;
  final Color color;
  final Color fondo;
  final bool latente;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: const BorderRadius.all(EcoRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (latente) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            texto,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
