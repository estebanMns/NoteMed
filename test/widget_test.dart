import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:notemed/main.dart';

void main() {
  testWidgets('el menú principal abre la escala de Braden', (tester) async {
    await tester.pumpWidget(const NoteMedApp());

    expect(find.text('Escala de Braden'), findsOneWidget);
    expect(find.text('Entrega de turno'), findsOneWidget);

    await tester.tap(find.byKey(const Key('menu-braden')));
    await tester.pumpAndSettle();
    expect(find.text('Faltan 6 de 6 subescalas'), findsOneWidget);
  });

  testWidgets('el menú principal abre la entrega de turno', (tester) async {
    await tester.pumpWidget(const NoteMedApp());
    await tester.tap(find.byKey(const Key('menu-turno')));
    await tester.pumpAndSettle();
    expect(find.text('Balance de líquidos'), findsOneWidget);
    expect(find.text('Ingresos'), findsOneWidget);
  });
}
