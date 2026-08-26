import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  const WhatsAppService._();

  /// Abre el chat de WhatsApp con el ciudadano y un mensaje ya escrito.
  ///
  /// Se usa `wa.me`, que funciona tanto con la app instalada como con
  /// WhatsApp Web, en vez de un esquema propio de plataforma.
  static Future<void> contactar(String telefono, String mensaje) async {
    final numero = telefono.replaceAll(RegExp(r'[^\d]'), '');
    if (numero.isEmpty) {
      throw Exception('El ciudadano no dejó un número de contacto.');
    }

    final url = Uri.https('wa.me', '/$numero', {'text': mensaje});

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir WhatsApp.');
    }
  }
}
