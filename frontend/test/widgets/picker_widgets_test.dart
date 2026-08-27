import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/solicitud.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/widgets/picker/confirm_accept_dialog.dart';
import 'package:frontend/widgets/picker/material_pin.dart';
import 'package:frontend/widgets/picker/request_preview_sheet.dart';

Solicitud solicitudDePrueba({Object? precio = '5.00', Object? distancia = 0.85}) {
  return Solicitud.fromJson({
    'id': 7,
    'tipo_material': 'carton',
    'foto': '',
    'latitud': '-17.393700',
    'longitud': '-66.157000',
    'direccion_referencia': 'Av. Siempre Viva 742',
    'estado': 'pendiente',
    'creado_en': '2026-08-24T10:00:00Z',
    'precio': precio,
    'distancia_km': distancia,
    'telefono_contacto': '+59170000000',
  });
}

Widget envolver(Widget child) {
  return MaterialApp(
    theme: buildEcoTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('RequestPreviewSheet', () {
    testWidgets('muestra material, distancia y pago', (tester) async {
      await tester.pumpWidget(envolver(
        RequestPreviewSheet(
          solicitud: solicitudDePrueba(),
          onAbrirDetalle: () {},
          onAceptar: () {},
        ),
      ));

      expect(find.text('Cartón'), findsOneWidget);
      expect(find.text('850 m'), findsOneWidget);
      expect(find.text(r'$5 en efectivo'), findsOneWidget);
      expect(find.text('Aceptar'), findsOneWidget);
    });

    testWidgets('el botón aceptar no dispara la apertura del detalle',
        (tester) async {
      var abrioDetalle = false;
      var acepto = false;

      await tester.pumpWidget(envolver(
        RequestPreviewSheet(
          solicitud: solicitudDePrueba(),
          onAbrirDetalle: () => abrioDetalle = true,
          onAceptar: () => acepto = true,
        ),
      ));

      await tester.tap(find.text('Aceptar'));
      await tester.pump();

      expect(acepto, isTrue);
      expect(abrioDetalle, isFalse);
    });

    testWidgets('mientras acepta deshabilita el botón y muestra progreso',
        (tester) async {
      await tester.pumpWidget(envolver(
        RequestPreviewSheet(
          solicitud: solicitudDePrueba(),
          aceptando: true,
          onAbrirDetalle: () {},
          onAceptar: () {},
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
    });
  });

  group('confirmarAceptacion', () {
    Future<bool?> abrirDialogo(WidgetTester tester, Solicitud solicitud) async {
      bool? resultado;

      await tester.pumpWidget(MaterialApp(
        theme: buildEcoTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                resultado = await confirmarAceptacion(context, solicitud);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return resultado;
    }

    testWidgets('resume material, pago y distancia', (tester) async {
      await abrirDialogo(tester, solicitudDePrueba());

      expect(find.text('¿Aceptar esta solicitud?'), findsOneWidget);
      expect(find.text('Cartón'), findsOneWidget);
      expect(find.text(r'$5'), findsOneWidget);
      expect(find.text('850 m'), findsOneWidget);
    });

    testWidgets('confirmar devuelve true', (tester) async {
      await abrirDialogo(tester, solicitudDePrueba());

      await tester.tap(find.text('Sí, aceptar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Aceptar esta solicitud?'), findsNothing);
    });

    testWidgets('una solicitud sin precio se resume como gratis',
        (tester) async {
      await abrirDialogo(tester, solicitudDePrueba(precio: null));

      expect(find.text('Gratis'), findsOneWidget);
    });
  });

  group('MaterialPin', () {
    testWidgets('el pin seleccionado muestra material y monto', (tester) async {
      await tester.pumpWidget(envolver(
        Center(
          child: MaterialPin(
            solicitud: solicitudDePrueba(),
            seleccionado: true,
            onTap: () {},
          ),
        ),
      ));
      await tester.pump();

      expect(find.text(r'Cartón · $5'), findsOneWidget);
    });

    testWidgets('el pin no seleccionado solo muestra el material',
        (tester) async {
      await tester.pumpWidget(envolver(
        Center(
          child: MaterialPin(
            solicitud: solicitudDePrueba(),
            seleccionado: false,
            onTap: () {},
          ),
        ),
      ));

      expect(find.text('Cartón'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('tocarlo lo selecciona', (tester) async {
      var tocado = false;

      await tester.pumpWidget(envolver(
        Center(
          child: MaterialPin(
            solicitud: solicitudDePrueba(),
            seleccionado: false,
            onTap: () => tocado = true,
          ),
        ),
      ));

      await tester.tap(find.byType(MaterialPin));
      expect(tocado, isTrue);
    });
  });
}
