import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Ajusta esta URL según dónde corra `python manage.py runserver` y desde dónde
/// se conecte la app:
/// - Emulador Android: 10.0.2.2 apunta al `localhost` de la máquina host.
/// - Web / desktop / iOS simulator: usar `http://localhost:8000`.
/// - Celular físico (Android/iOS) en la misma red WiFi que el PC: usar la IP
///   LAN del PC (ver `ip addr` / `hostname -I` en Linux, `ipconfig` en Windows),
///   y arrancar el backend con `python manage.py runserver 0.0.0.0:8000`.
const String backendBaseUrl = 'http://localhost:8000';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  bool get isAuthenticated => _token != null;

  Map<String, String> get _authHeaders =>
      _token != null ? {'Authorization': 'Token $_token'} : {};

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$backendBaseUrl$path').replace(queryParameters: query);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final response = await http.get(_uri(path, query), headers: _authHeaders);
    return _decode(response);
  }

  Future<dynamic> postJson(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      _uri(path),
      headers: {..._authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> postMultipart(
    String path,
    Map<String, String> fields,
    String fileField,
    Uint8List fileBytes,
    String fileName,
  ) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_authHeaders)
      ..fields.addAll(fields)
      ..files.add(http.MultipartFile.fromBytes(fileField, fileBytes, filename: fileName));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    throw ApiException(
      'Error de red (${response.statusCode}): ${response.body}',
      statusCode: response.statusCode,
    );
  }
}
