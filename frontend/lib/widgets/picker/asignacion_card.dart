import 'package:flutter/material.dart';

import '../../models/asignacion_retiro.dart';
import '../../theme/app_theme.dart';
import 'eco_chips.dart';

/// Fila de un retiro aceptado o completado, para las listas del recolector.
class AsignacionCard extends StatelessWidget {
  const AsignacionCard({super.key, required this.asignacion, this.onTap});

  final AsignacionRetiro asignacion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final solicitud = asignacion.solicitud;
    final textos = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EcoRadius.xl),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(EcoRadius.lg),
                child: Container(
                  width: 56,
                  height: 56,
                  color: EcoColors.surfaceContainerHigh,
                  child: solicitud.fotoUrl.isEmpty
                      ? Icon(solicitud.tipoMaterial.icon, color: EcoColors.outline)
                      : Image.network(
                          solicitud.fotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, _, _) => Icon(
                            solicitud.tipoMaterial.icon,
                            color: EcoColors.outline,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      solicitud.tipoMaterial.label,
                      style: textos.labelLarge?.copyWith(color: EcoColors.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      solicitud.direccionReferencia.isEmpty
                          ? 'Sin dirección de referencia'
                          : solicitud.direccionReferencia,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textos.bodySmall,
                    ),
                    const SizedBox(height: EcoSpacing.element),
                    PrecioChip(
                      texto: solicitud.precioLabel,
                      esGratis: solicitud.esGratis,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: EcoColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vacío consistente para las listas del recolector.
class ListaVacia extends StatelessWidget {
  const ListaVacia({super.key, required this.icono, required this.mensaje});

  final IconData icono;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(EcoSpacing.section),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: EcoColors.outlineVariant),
            const SizedBox(height: EcoSpacing.stack),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: EcoColors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
