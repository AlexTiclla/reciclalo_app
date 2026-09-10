import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

const _etiquetasPorEstrella = {
  1: 'Mala',
  2: 'Regular',
  3: 'Buena',
  4: 'Muy buena',
  5: '¡Excelente!',
};

/// Cinco estrellas grandes (≥48×48 px) con etiqueta de apoyo, usadas en la
/// pantalla de calificación de Screen 4 (`retiro_completado_y_calificaci_n`).
///
/// Con `onChanged == null` se muestra en modo solo lectura (retiro ya
/// calificado, reabierto desde Historial).
class CalificacionEstrellas extends StatelessWidget {
  const CalificacionEstrellas({
    super.key,
    required this.valor,
    required this.onChanged,
  });

  final int valor;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final soloLectura = onChanged == null;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (indice) {
            final numero = indice + 1;
            final llena = numero <= valor;
            return Semantics(
              button: !soloLectura,
              label: '$numero de 5 estrellas',
              child: IconButton(
                onPressed: soloLectura ? null : () => onChanged!(numero),
                iconSize: 32,
                constraints: const BoxConstraints(
                  minWidth: EcoSpacing.touchTarget,
                  minHeight: EcoSpacing.touchTarget,
                ),
                icon: Icon(
                  llena ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: llena ? EcoColors.warningAmber : EcoColors.outlineVariant,
                ),
              ),
            );
          }),
        ),
        if (valor > 0) ...[
          const SizedBox(height: EcoSpacing.element),
          Text(
            '${_etiquetasPorEstrella[valor]} ($valor/5)',
            style: textos.labelLarge?.copyWith(color: EcoColors.primary),
          ),
        ],
      ],
    );
  }
}
