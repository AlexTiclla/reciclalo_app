import 'package:flutter/material.dart';

import '../../models/solicitud.dart';
import '../../theme/app_theme.dart';
import 'eco_chips.dart';

/// Vista previa de la solicitud seleccionada, anclada sobre el mapa.
///
/// Toda la tarjeta abre el detalle; el botón "Aceptar" es un atajo para el
/// recolector que ya vio suficiente y no necesita entrar.
class RequestPreviewSheet extends StatelessWidget {
  const RequestPreviewSheet({
    super.key,
    required this.solicitud,
    required this.onAbrirDetalle,
    required this.onAceptar,
    this.aceptando = false,
  });

  final Solicitud solicitud;
  final VoidCallback onAbrirDetalle;
  final VoidCallback onAceptar;
  final bool aceptando;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Material(
      color: EcoColors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(EcoRadius.x2l),
      ),
      child: InkWell(
        onTap: onAbrirDetalle,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(EcoRadius.x2l),
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: EcoColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(EcoRadius.x2l),
            ),
            boxShadow: EcoShadows.sheet,
          ),
          padding: const EdgeInsets.fromLTRB(
            EcoSpacing.container,
            EcoSpacing.element,
            EcoSpacing.container,
            EcoSpacing.stack,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(bottom: EcoSpacing.stack),
                decoration: const BoxDecoration(
                  color: EcoColors.surfaceVariant,
                  borderRadius: BorderRadius.all(EcoRadius.full),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Miniatura(url: solicitud.fotoUrl, material: solicitud.tipoMaterial),
                  const SizedBox(width: EcoSpacing.stack),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          solicitud.tipoMaterial.label,
                          style: textos.headlineMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: EcoColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                solicitud.distanciaLabel,
                                style: textos.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: EcoSpacing.element),
                        PrecioChip(
                          texto: solicitud.precioLabel,
                          esGratis: solicitud.esGratis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: EcoSpacing.element),
                  _BotonAceptar(cargando: aceptando, onPressed: onAceptar),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.url, required this.material});

  final String url;
  final TipoMaterial material;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(EcoRadius.xl),
      child: Container(
        width: 72,
        height: 72,
        color: EcoColors.surfaceContainerHigh,
        child: url.isEmpty
            ? Icon(material.icon, color: EcoColors.outline)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, _, _) =>
                    Icon(material.icon, color: EcoColors.outline),
              ),
      ),
    );
  }
}

class _BotonAceptar extends StatelessWidget {
  const _BotonAceptar({required this.cargando, required this.onPressed});

  final bool cargando;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: cargando ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: EcoColors.primary,
        minimumSize: const Size(0, EcoSpacing.touchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EcoRadius.xl),
        ),
      ),
      child: cargando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: EcoColors.onPrimary,
              ),
            )
          : const Text('Aceptar'),
    );
  }
}
