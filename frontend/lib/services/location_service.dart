import 'package:geolocator/geolocator.dart';

class LocationException implements Exception {
  LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocationService {
  Future<Position> obtenerUbicacionActual() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException('Activa el GPS para confirmar tu ubicación.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('Permiso de ubicación denegado.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Permiso de ubicación denegado permanentemente. Habilítalo desde ajustes.',
      );
    }

    return Geolocator.getCurrentPosition();
  }

  /// Emite la posición del recolector mientras se mueve.
  ///
  /// El filtro por distancia (en vez de un temporizador) evita despertar el GPS
  /// cuando está parado, que es lo que más batería consume en una jornada.
  Stream<Position> flujoUbicacion({int metrosMinimos = 50}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: metrosMinimos,
      ),
    );
  }
}
