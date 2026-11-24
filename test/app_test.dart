import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoyo/dobles.dart';

void main() {
  testWidgets('el menú principal abre la escala de Braden', (tester) async {
    await tester.pumpWidget(conDependencias(repo: RepositorioMemoria()));

    expect(find.text('Escala de Braden'), findsOneWidget);
    expect(find.text('Entrega de turno'), findsOneWidget);

    await tester.tap(find.byKey(const Key('menu-braden')));
    await tester.pumpAndSettle();
    expect(find.text('Faltan 6 de 6 subescalas'), findsOneWidget);
  });

  testWidgets('el menú principal abre la entrega de turno', (tester) async {
    await tester.pumpWidget(conDependencias(repo: RepositorioMemoria()));
    await tester.tap(find.byKey(const Key('menu-turno')));
    await tester.pumpAndSettle();
    expect(find.text('Balance de líquidos'), findsOneWidget);
    expect(find.text('Ingresos'), findsOneWidget);
  });

  testWidgets('el menú principal abre la escala de Downton', (tester) async {
    await tester.pumpWidget(conDependencias(repo: RepositorioMemoria()));
    await tester.tap(find.byKey(const Key('menu-downton')));
    await tester.pumpAndSettle();
    expect(find.text('Seleccione la deambulación'), findsOneWidget);
  });

  testWidgets('registra un paciente y abre su pantalla', (tester) async {
    final repo = RepositorioMemoria();
    final red = RedSimulada();
    addTearDown(red.cerrar);
    await tester.pumpWidget(conDependencias(repo: repo, red: red));

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

  testWidgets('abre un paciente existente desde la lista', (tester) async {
    final repo = RepositorioMemoria();
    final p = await repo.guardarPaciente(pacienteEjemplo);
    await tester.pumpWidget(conDependencias(repo: repo));

    await tester.tap(find.byKey(const Key('menu-pacientes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('paciente-${p.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Cédula 1085123456 · 67 años · Cama 12B'), findsOneWidget);
    expect(find.byKey(const Key('btn-generar-nota')), findsOneWidget);
  });
}
