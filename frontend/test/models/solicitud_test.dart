import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/solicitud.dart';

Map<String, dynamic> jsonBase({Map<String, dynamic> extra = const {}}) {
  return {
    'id': 7,
    'tipo_material': 'carton',
    'foto': 'http://localhost:8000/media/solicitudes/caja.jpg',
    'latitud': '-17.393700',
    'longitud': '-66.157000',
    'direccion_referencia': 'Av. Siempre Viva 742',
    'estado': 'pendiente',
    'creado_en': '2026-08-24T10:00:00Z',
    ...extra,
  };
}

void main() {
  group('Solicitud.fromJson', () {
    test('lee los campos del serializer del recolector', () {
      final solicitud = Solicitud.fromJson(jsonBase(extra: {
        'precio': '5.00',
        'telefono_contacto': '+591 70000000',
        'ciudadano_nombre': 'vecina',
        'distancia_km': 0.85,
      }));

      expect(solicitud.id, 7);
      expect(solicitud.tipoMaterial, TipoMaterial.carton);
      expect(solicitud.precio, 5.0);
      expect(solicitud.telefonoContacto, '+591 70000000');
      expect(solicitud.ciudadanoNombre, 'vecina');
      expect(solicitud.distanciaKm, 0.85);
    });

    test('acepta el recolector bajo `recolector` o bajo `recolector_info`', () {
      final delCiudadano = Solicitud.fromJson(jsonBase(extra: {
        'recolector': {'id': 3, 'nombre': 'Juan'},
      }));
      final delRecolector = Solicitud.fromJson(jsonBase(extra: {
        'recolector_info': {'id': 3, 'nombre': 'Juan'},
      }));

      expect(delCiudadano.recolector?.nombre, 'Juan');
      expect(delRecolector.recolector?.nombre, 'Juan');
    });

    test('sin precio ni distancia deja los campos nulos', () {
      final solicitud = Solicitud.fromJson(jsonBase());

      expect(solicitud.precio, isNull);
      expect(solicitud.distanciaKm, isNull);
      expect(solicitud.esGratis, isTrue);
      expect(solicitud.tieneTelefono, isFalse);
    });
  });

  group('etiquetas', () {
    Solicitud conPrecioYDistancia(double? precio, double? km) {
      return Solicitud.fromJson(jsonBase(extra: {
        'precio': precio?.toString(),
        'distancia_km': km,
      }));
    }

    test('el precio entero se muestra sin decimales', () {
      expect(conPrecioYDistancia(5, null).precioLabel, r'$5 en efectivo');
    });

    test('el precio con centavos conserva dos decimales', () {
      expect(conPrecioYDistancia(7.5, null).precioLabel, r'$7.50 en efectivo');
    });

    test('sin precio la solicitud se anuncia como gratis', () {
      expect(conPrecioYDistancia(null, null).precioLabel, 'Gratis');
    });

    test('por debajo de 1 km la distancia se muestra en metros', () {
      expect(conPrecioYDistancia(null, 0.85).distanciaLabel, '850 m');
    });

    test('a partir de 1 km la distancia se muestra en kilómetros', () {
      expect(conPrecioYDistancia(null, 2.54).distanciaLabel, '2.5 km');
    });

    test('sin distancia se avisa en vez de mostrar un número falso', () {
      expect(conPrecioYDistancia(null, null).distanciaLabel,
          'Distancia no disponible');
    });
  });
}
