import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/app_theme.dart';

/// Capa de teselas de OpenStreetMap.
///
/// `userAgentPackageName` es obligatorio según la política de uso de las
/// teselas públicas de OSM: identifica a la app en cada petición.
TileLayer openStreetMapTiles() {
  return TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.reciclalo.app',
    maxNativeZoom: 19,
  );
}

/// Mapa pequeño y no interactivo que sitúa el punto de retiro.
///
/// Se usa dentro de pantallas con scroll, por eso ignora los gestos: si
/// respondiera al arrastre, capturaría el scroll de la pantalla.
class MapaUbicacion extends StatelessWidget {
  const MapaUbicacion({
    super.key,
    required this.latitud,
    required this.longitud,
    this.altura = 128,
    this.zoom = 16,
    this.overlay,
    this.ubicacionSecundaria,
  });

  final double latitud;
  final double longitud;
  final double altura;
  final double zoom;

  /// Tarjeta opcional superpuesta al mapa (dirección, distancia).
  final Widget? overlay;

  /// Última posición conocida del recolector (Flujo 4, Screen 3). Cuando se
  /// provee, se dibuja un segundo marcador y una línea recta entre ambos
  /// puntos — deliberadamente no una ruta por calles, para no fingir un dato
  /// de ruteo que la app no tiene.
  final LatLng? ubicacionSecundaria;

  @override
  Widget build(BuildContext context) {
    final punto = LatLng(latitud, longitud);
    final secundario = ubicacionSecundaria;

    return ClipRRect(
      borderRadius: BorderRadius.circular(EcoRadius.xl),
      child: Container(
        height: altura,
        decoration: BoxDecoration(
          border: Border.all(color: EcoColors.surfaceVariant),
          borderRadius: BorderRadius.circular(EcoRadius.xl),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: punto,
                  initialZoom: zoom,
                  initialCameraFit: secundario != null
                      ? CameraFit.bounds(
                          bounds: LatLngBounds(punto, secundario),
                          padding: const EdgeInsets.all(36),
                        )
                      : null,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  openStreetMapTiles(),
                  if (secundario != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [secundario, punto],
                          strokeWidth: 3,
                          color: EcoColors.primary.withValues(alpha: 0.5),
                          pattern: const StrokePattern.dotted(),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: punto,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: const _ChinchetaDestino(),
                      ),
                      if (secundario != null)
                        Marker(
                          point: secundario,
                          width: 36,
                          height: 36,
                          child: const _MarcadorRecolector(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (overlay != null)
              Positioned(
                left: EcoSpacing.element,
                right: EcoSpacing.element,
                bottom: EcoSpacing.element,
                child: overlay!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Marcador de la última posición conocida del recolector en Screen 3.
class _MarcadorRecolector extends StatelessWidget {
  const _MarcadorRecolector();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: EcoColors.primary,
        border: Border.all(color: EcoColors.surfaceContainerLowest, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6)],
      ),
      child: const Icon(Icons.local_shipping, size: 18, color: EcoColors.onPrimary),
    );
  }
}

class _ChinchetaDestino extends StatelessWidget {
  const _ChinchetaDestino();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.location_on,
      size: 36,
      color: EcoColors.primary,
      shadows: [Shadow(color: Color(0x33000000), blurRadius: 6)],
    );
  }
}

/// Tarjeta flotante con la dirección, usada como `overlay` de [MapaUbicacion].
class TarjetaDireccion extends StatelessWidget {
  const TarjetaDireccion({
    super.key,
    required this.direccion,
    required this.detalle,
  });

  final String direccion;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EcoColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(EcoRadius.lg),
        boxShadow: EcoShadows.ambient,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: EcoColors.primaryContainer,
            ),
            child: const Icon(
              Icons.location_on,
              color: EcoColors.onPrimaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  direccion,
                  style: textos.labelMedium?.copyWith(color: EcoColors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(detalle, style: textos.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
