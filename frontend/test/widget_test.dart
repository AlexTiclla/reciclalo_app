import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('La app arranca en la pantalla de login', (WidgetTester tester) async {
    await tester.pumpWidget(const EcoReciclaApp());

    expect(find.text('¡Hola de nuevo!'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
