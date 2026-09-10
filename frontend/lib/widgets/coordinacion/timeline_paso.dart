import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum EstadoPaso { completado, activo, pendiente }

/// Un paso de la timeline vertical de Screen 3 (`seguimiento_del_retiro`).
///
/// Nunca depende solo del color para distinguir estados: el ícono, la
/// etiqueta de estado y el texto ya lo hacen (regla de accesibilidad del
/// `design-prompt.md`).
class TimelinePaso extends StatelessWidget {
  const TimelinePaso({
    super.key,
    required this.icono,
    required this.titulo,
    required this.estado,
    this.detalle,
    this.etiquetaEstado,
    this.esUltimo = false,
  });

  final IconData icono;
  final String titulo;
  final EstadoPaso estado;
  final String? detalle;

  /// Ej. "Completado", "Ahora" — si se omite, se infiere de [estado].
  final String? etiquetaEstado;
  final bool esUltimo;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final colorIcono = switch (estado) {
      EstadoPaso.completado => EcoColors.primary,
      EstadoPaso.activo => EcoColors.primary,
      EstadoPaso.pendiente => EcoColors.outlineVariant,
    };
    final colorTitulo = estado == EstadoPaso.pendiente ? EcoColors.outline : EcoColors.onSurface;
    final etiqueta = etiquetaEstado ??
        switch (estado) {
          EstadoPaso.completado => 'Completado',
          EstadoPaso.activo => 'Ahora',
          EstadoPaso.pendiente => null,
        };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: estado == EstadoPaso.pendiente
                      ? EcoColors.surfaceContainerLow
                      : EcoColors.mintLight,
                ),
                child: Icon(icono, size: 18, color: colorIcono),
              ),
              if (!esUltimo)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: estado == EstadoPaso.completado
                        ? EcoColors.primary.withValues(alpha: 0.4)
                        : EcoColors.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: EcoSpacing.stack),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: esUltimo ? 0 : EcoSpacing.container),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          titulo,
                          style: textos.labelLarge?.copyWith(color: colorTitulo),
                        ),
                      ),
                      if (etiqueta != null) ...[
                        const SizedBox(width: EcoSpacing.element),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: estado == EstadoPaso.activo
                                ? EcoColors.secondaryContainer
                                : EcoColors.mintLight,
                            borderRadius: BorderRadius.all(EcoRadius.full),
                          ),
                          child: Text(
                            etiqueta,
                            style: textos.labelSmall?.copyWith(color: EcoColors.primary),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (detalle != null) ...[
                    const SizedBox(height: 2),
                    Text(detalle!, style: textos.bodySmall),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
