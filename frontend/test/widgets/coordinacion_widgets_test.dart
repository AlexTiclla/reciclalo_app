import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/widgets/coordinacion/calificacion_estrellas.dart';
import 'package:frontend/widgets/coordinacion/timeline_paso.dart';

Widget envolver(Widget child) {
  return MaterialApp(
    theme: buildEcoTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('TimelinePaso', () {
    testWidgets('un paso completado muestra la etiqueta "Completado", no solo color',
        (tester) async {
      await tester.pumpWidget(envolver(
        const TimelinePaso(
          icono: Icons.check,
          titulo: 'Solicitud aceptada',
          estado: EstadoPaso.completado,
        ),
      ));

      expect(find.text('Solicitud aceptada'), findsOneWidget);
      expect(find.text('Completado'), findsOneWidget);
    });

    testWidgets('un paso activo muestra la etiqueta "Ahora"', (tester) async {
      await tester.pumpWidget(envolver(
        const TimelinePaso(
          icono: Icons.local_shipping_outlined,
          titulo: 'En camino',
          estado: EstadoPaso.activo,
        ),
      ));

      expect(find.text('Ahora'), findsOneWidget);
    });

    testWidgets('un paso pendiente no muestra ninguna etiqueta de estado', (tester) async {
      await tester.pumpWidget(envolver(
        const TimelinePaso(
          icono: Icons.inventory_2_outlined,
          titulo: 'Material recogido',
          estado: EstadoPaso.pendiente,
        ),
      ));

      expect(find.text('Completado'), findsNothing);
      expect(find.text('Ahora'), findsNothing);
    });
  });

  group('CalificacionEstrellas', () {
    testWidgets('en modo interactivo, tocar una estrella dispara onChanged', (tester) async {
      int? seleccionado;
      await tester.pumpWidget(envolver(
        CalificacionEstrellas(valor: 0, onChanged: (v) => seleccionado = v),
      ));

      await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
      expect(seleccionado, 4);
    });

    testWidgets('con onChanged nulo, las estrellas no son interactivas', (tester) async {
      await tester.pumpWidget(envolver(
        const CalificacionEstrellas(valor: 5, onChanged: null),
      ));

      final boton = tester.widget<IconButton>(find.byType(IconButton).first);
      expect(boton.onPressed, isNull);
      expect(find.text('¡Excelente! (5/5)'), findsOneWidget);
    });
  });
}
