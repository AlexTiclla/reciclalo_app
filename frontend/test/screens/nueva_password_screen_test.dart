import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/recuperacion/nueva_password_screen.dart';
import 'package:frontend/theme/app_theme.dart';

void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          theme: buildEcoTheme(),
          home: const NuevaPasswordScreen(token: 'token-de-prueba'),
        ),
      );

  Finder botonGuardar() => find.widgetWithText(FilledButton, 'Guardar contraseña');

  testWidgets('el botón está deshabilitado sin contraseña', (tester) async {
    await pump(tester);

    final boton = tester.widget<FilledButton>(botonGuardar());
    expect(boton.onPressed, isNull);
  });

  testWidgets('el botón sigue deshabilitado si las contraseñas no coinciden',
      (tester) async {
    await pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nueva contraseña'),
      'contrasenaLarga1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirmar contraseña'),
      'otraDistinta1',
    );
    await tester.pump();

    final boton = tester.widget<FilledButton>(botonGuardar());
    expect(boton.onPressed, isNull);
  });

  testWidgets('el botón sigue deshabilitado si no llega a 8 caracteres',
      (tester) async {
    await pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nueva contraseña'),
      '123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirmar contraseña'),
      '123',
    );
    await tester.pump();

    final boton = tester.widget<FilledButton>(botonGuardar());
    expect(boton.onPressed, isNull);
  });

  testWidgets('el botón se habilita cuando ambas validaciones pasan',
      (tester) async {
    await pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nueva contraseña'),
      'contrasenaLarga1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirmar contraseña'),
      'contrasenaLarga1',
    );
    await tester.pump();

    final boton = tester.widget<FilledButton>(botonGuardar());
    expect(boton.onPressed, isNotNull);
  });
}
