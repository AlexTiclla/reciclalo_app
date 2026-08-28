import 'package:url_launcher/url_launcher.dart';

class MapsService {
  const MapsService._();

  /// Abre la navegación hacia el punto de retiro en la app de mapas del
  /// dispositivo (Google Maps si está instalada) usando el esquema universal.
  static Future<void> navegarHacia(double latitud, double longitud) async {
    final url = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitud,$longitud',
      'travelmode': 'driving',
    });

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir la app de mapas.');
    }
  }
}
