// Prueba en un celular o emulador real: base cifrada con SQLCipher y flujo
// completo (login → paciente → valoración → borrador de IA → firma).
//   flutter test integration_test -d <dispositivo>
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:notemed/app/app.dart';
import 'package:notemed/app/providers.dart';
import 'package:notemed/core/datos/base_datos_local.dart';
import 'package:notemed/features/notas/domain/nota_clinica.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('base cifrada y flujo completo en el dispositivo', (
    tester,
  ) async {
    final db = await BaseDatosLocal.abrirCifrada();
    addTearDown(db.close);

    // El archivo no debe empezar con la cabecera de SQLite sin cifrar.
    final ruta = p.join(
      await cipher.getDatabasesPath(),
      BaseDatosLocal.nombreArchivo,
    );
    final cabecera = await File(ruta).openRead(0, 16).first;
    expect(
      ascii.decode(cabecera.take(15).toList(), allowInvalid: true),
      isNot('SQLite format 3'),
    );
    await db.delete('pacientes');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [baseDatosProvider.overrideWithValue(db)],
        child: const NoteMedApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Login
    await tester.enterText(
      find.byKey(const Key('login-usuario')),
      'enfermera1',
    );
    await tester.enterText(find.byKey(const Key('login-clave')), 'notemed123');
    await tester.tap(find.byKey(const Key('login-entrar')));
    await tester.pumpAndSettle();
    expect(find.text('IA simulada (sin internet)'), findsOneWidget);

    // Paciente sintético
    await tester.tap(find.byKey(const Key('menu-pacientes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pacientes-nuevo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pac-nombre')), 'Ana Ruiz');
    await tester.enterText(find.byKey(const Key('pac-cedula')), '52345678');
    await tester.enterText(find.byKey(const Key('pac-edad')), '45');
    await tester.enterText(find.byKey(const Key('pac-cama')), '7');
    await tester.tap(find.byKey(const Key('pac-guardar')));
    await tester.pumpAndSettle();

    // Signos vitales y nota de turno
    await tester.enterText(find.byKey(const Key('sv-tas')), '120');
    await tester.enterText(find.byKey(const Key('sv-tad')), '80');
    await tester.enterText(find.byKey(const Key('sv-fc')), '84');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn-generar-nota')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final borrador = tester.widget<TextField>(
      find.byKey(const Key('borrador-texto')),
    );
    expect(borrador.controller!.text, contains('Ana Ruiz'));
    expect(borrador.controller!.text, contains('TA 120/80 mmHg'));
    expect(find.byKey(const Key('borrador-advertencias')), findsNothing);

    // Firma
    await tester.tap(find.byKey(const Key('borrador-firmar')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('firma-lienzo')),
      const Offset(120, 30),
    );
    await tester.tap(find.byKey(const Key('firma-aceptar')));
    await tester.pumpAndSettle();

    final filas = await db.query('notas');
    expect(filas, hasLength(1));
    expect(filas.single['firma'], isNotNull);
    expect(filas.single['hash'], isNotNull);
    expect(filas.single['tipo'], TipoNota.turno.name);
    expect(await db.query('metricas'), hasLength(1));

    // El trigger de la base protege la nota firmada.
    await expectLater(
      db.update('notas', {'texto': 'x'}),
      throwsA(isA<cipher.DatabaseException>()),
    );
  });
}
