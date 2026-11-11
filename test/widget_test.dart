import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:notemed/features/nota/servicio_notas.dart';
import 'package:notemed/main.dart';

import 'apoyo/dobles.dart';

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

  testWidgets('el menú principal abre la escala de Downton', (tester) async {
    await tester.pumpWidget(const NoteMedApp());
    await tester.tap(find.byKey(const Key('menu-downton')));
    await tester.pumpAndSettle();
    expect(find.text('Seleccione la deambulación'), findsOneWidget);
  });

  testWidgets('Pacientes se desactiva si no hay base de datos', (tester) async {
    await tester.pumpWidget(const NoteMedApp());
    final tile = tester.widget<ListTile>(
      find.byKey(const Key('menu-pacientes')),
    );
    expect(tile.enabled, isFalse);
  });

  testWidgets('registra un paciente y abre su pantalla', (tester) async {
    final repo = RepositorioMemoria();
    final red = RedSimulada();
    addTearDown(red.cerrar);
    await tester.pumpWidget(
      NoteMedApp(
        dependencias: Dependencias(
          repositorio: repo,
          servicioNotas: ServicioNotas(
            repositorio: repo,
            ia: IASimulada(),
            red: red,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('menu-pacientes')));
    await tester.pumpAndSettle();
    expect(find.text('No hay pacientes registrados.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pacientes-nuevo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pac-nombre')), 'Ana Ruiz');
    await tester.enterText(find.byKey(const Key('pac-cedula')), '52345678');
    await tester.enterText(find.byKey(const Key('pac-edad')), '45');
    await tester.enterText(find.byKey(const Key('pac-cama')), '7');
    await tester.tap(find.byKey(const Key('pac-guardar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('btn-generar-nota')), findsOneWidget);
    expect((await repo.pacientes()).single.nombre, 'Ana Ruiz');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Ana Ruiz'), findsOneWidget);
  });
}
