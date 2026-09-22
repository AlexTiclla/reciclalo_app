import 'package:flutter/material.dart';

import 'models/solicitud.dart';
import 'screens/coordinacion/elegir_franja_screen.dart';
import 'screens/coordinacion/retiro_completado_screen.dart';
import 'screens/coordinacion/retiro_confirmado_screen.dart';
import 'screens/coordinacion/seguimiento_retiro_screen.dart';
import 'screens/solicitud_detalle_screen.dart';

/// Único punto de entrada a las pantallas del Flujo 4 (coordinación y
/// seguimiento del retiro) desde Inicio/Historial — evita repetir esta
/// lógica de enrutamiento en cada punto de entrada.
///
/// ```text
/// estado == pendiente                                    -> detalle simple
/// estado == aceptada, coordinacion == pendiente           -> Screen 1
/// estado == aceptada, coordinacion == propuesta_ciudadano -> Screen 2 (espera)
/// estado == aceptada, coordinacion == propuesta_recolector-> Screen 1 (propuesta)
/// estado == aceptada, coordinacion == confirmada          -> Screen 2 (confirmada)
/// estado == en_camino                                     -> Screen 3
/// estado == completada                                    -> Screen 4 (calificación)
/// ```
Future<void> abrirCoordinacion(BuildContext context, Solicitud solicitud) async {
  final Widget pantalla;
  switch (solicitud.estado) {
    case EstadoSolicitud.pendiente:
      pantalla = SolicitudDetalleScreen(solicitudId: solicitud.id);
    case EstadoSolicitud.aceptada:
      pantalla = switch (solicitud.estadoCoordinacion) {
        EstadoCoordinacion.pendiente || EstadoCoordinacion.propuestaRecolector =>
          ElegirFranjaScreen(solicitud: solicitud),
        EstadoCoordinacion.propuestaCiudadano || EstadoCoordinacion.confirmada =>
          RetiroConfirmadoScreen(solicitud: solicitud),
      };
    case EstadoSolicitud.enCamino:
      pantalla = SeguimientoRetiroScreen(solicitud: solicitud);
    case EstadoSolicitud.completada:
      pantalla = RetiroCompletadoScreen(solicitud: solicitud);
  }

  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
}
