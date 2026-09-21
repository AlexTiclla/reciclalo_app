import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/widgets/otp_input.dart';

Widget _envolver(Widget child) {
  return MaterialApp(
    theme: buildEcoTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('OtpInput', () {
    testWidgets('escribir 6 dígitos uno por uno reporta el código completo',
        (tester) async {
      String? ultimoValor;
      await tester.pumpWidget(
        _envolver(OtpInput(onChanged: (valor) => ultimoValor = valor)),
      );

      final campos = find.byType(TextField);
      expect(campos, findsNWidgets(6));

      const digitos = ['4', '8', '2', '9', '1', '3'];
      for (var i = 0; i < digitos.length; i++) {
        await tester.enterText(campos.at(i), digitos[i]);
        await tester.pump();
      }

      expect(ultimoValor, '482913');
    });

    testWidgets('pegar un código de 6 dígitos en una casilla lo distribuye',
        (tester) async {
      String? ultimoValor;
      await tester.pumpWidget(
        _envolver(OtpInput(onChanged: (valor) => ultimoValor = valor)),
      );

      await tester.enterText(find.byType(TextField).first, '482913');
      await tester.pump();

      expect(ultimoValor, '482913');
    });

    testWidgets('limpiar() vacía todas las casillas', (tester) async {
      String? ultimoValor;
      final key = GlobalKey<OtpInputState>();
      await tester.pumpWidget(
        _envolver(OtpInput(key: key, onChanged: (valor) => ultimoValor = valor)),
      );

      await tester.enterText(find.byType(TextField).first, '482913');
      await tester.pump();
      expect(ultimoValor, '482913');

      key.currentState?.limpiar();
      await tester.pump();

      expect(ultimoValor, '');
    });
  });
}
