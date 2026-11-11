// TSK-10 / TSK-12 · HU03: plantilla SBAR y balance de líquidos.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notemed/features/turno/balance_liquidos.dart';
import 'package:notemed/features/turno/sbar_form.dart';
import 'package:notemed/features/turno/sbar_plantilla.dart';

void main() {
  group('NotaSbar (TSK-10)', () {
    test('una nota vacía no es válida: faltan las 4 secciones', () {
      expect(const NotaSbar().validar(), SeccionSbar.values);
      expect(const NotaSbar().esValida, isFalse);
    });

    test('una sección con solo espacios cuenta como vacía', () {
      final n = const NotaSbar(
        situacion: 'Estable',
        antecedentes: 'HTA',
        evaluacion: '   ',
        recomendacion: 'Control de TA',
      );
      expect(n.validar(), [SeccionSbar.evaluacion]);
    });

    test('con() cambia solo la sección indicada', () {
      final n = const NotaSbar(turnoEntrega: 'Enf. noche')
          .con(SeccionSbar.recomendacion, 'Vigilar diuresis');
      expect(n.recomendacion, 'Vigilar diuresis');
      expect(n.situacion, isEmpty);
      expect(n.turnoEntrega, 'Enf. noche');
    });

    test('toTexto() respeta el orden S-B-A-R', () {
      final texto = const NotaSbar(
        situacion: ' Estable ',
        antecedentes: 'HTA',
        evaluacion: 'Braden 14',
        recomendacion: 'Cambios de posición cada 2 h',
        turnoEntrega: 'Enf. noche',
        turnoRecibe: 'Enf. día',
      ).toTexto();
      expect(
        texto,
        'NOTA DE ENTREGA DE TURNO (SBAR)\n'
        'Entrega: Enf. noche\n'
        'Recibe: Enf. día\n'
        '[S] Situación: Estable\n'
        '[B] Antecedentes: HTA\n'
        '[A] Evaluación: Braden 14\n'
        '[R] Recomendación: Cambios de posición cada 2 h',
      );
    });

    testWidgets('SbarForm no guarda si faltan secciones', (tester) async {
      NotaSbar? guardada;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SbarForm(onGuardar: (n) => guardada = n),
          ),
        ),
      ));
      await tester.enterText(find.byKey(const Key('sbar-situacion')), 'Estable');
      await tester.ensureVisible(find.byKey(const Key('sbar-guardar')));
      await tester.tap(find.byKey(const Key('sbar-guardar')));
      await tester.pump();
      expect(guardada, isNull);
      expect(find.text('Antecedentes es obligatoria'), findsOneWidget);

      for (final s in SeccionSbar.values.skip(1)) {
        await tester.enterText(find.byKey(Key('sbar-${s.name}')), 'Dato ${s.letra}');
      }
      await tester.ensureVisible(find.byKey(const Key('sbar-guardar')));
      await tester.tap(find.byKey(const Key('sbar-guardar')));
      await tester.pump();
      expect(guardada?.esValida, isTrue);
      expect(guardada?.recomendacion, 'Dato R');
    });
  });

  group('RegistroLiquidos (TSK-12)', () {
    test('suma ingresos, egresos, insensibles y balance', () {
      final r = RegistroLiquidos(horasTurno: 12, pesoKg: 70)
        ..agregarIngreso(TipoIngreso.oral, 500)
        ..agregarIngreso(TipoIngreso.intravenoso, 1000)
        ..agregarIngreso(TipoIngreso.intravenoso, 500)
        ..agregarEgreso(TipoEgreso.diuresis, 1200)
        ..agregarEgreso(TipoEgreso.drenajes, 100);
      expect(r.totalIngresos, 2000);
      expect(r.ingresos[TipoIngreso.intravenoso], 1500);
      expect(r.perdidasInsensibles, 420); // 70 × 0,5 × 12
      expect(r.totalEgresos, 1720);
      expect(r.balance, 280);
      expect(r.gastoUrinario, closeTo(1.43, 0.01));
      expect(r.oliguria, isFalse);
      expect(r.resumen(), contains('Balance: +280 mL'));
    });

    test('sin peso no calcula insensibles ni gasto urinario', () {
      final r = RegistroLiquidos(horasTurno: 8)
        ..agregarIngreso(TipoIngreso.oral, 300)
        ..agregarEgreso(TipoEgreso.diuresis, 500);
      expect(r.perdidasInsensibles, 0);
      expect(r.balance, -200);
      expect(r.gastoUrinario, isNull);
      expect(r.resumen(), contains('Balance: -200 mL'));
    });

    test('alerta de oliguria con < 0,5 mL/kg/h', () {
      final r = RegistroLiquidos(horasTurno: 8, pesoKg: 80)
        ..agregarEgreso(TipoEgreso.diuresis, 200); // 0,31 mL/kg/h
      expect(r.oliguria, isTrue);
      expect(r.resumen(), contains('oliguria'));
    });

    test('rechaza valores inválidos', () {
      final r = RegistroLiquidos(horasTurno: 6);
      expect(() => r.agregarIngreso(TipoIngreso.oral, -1), throwsArgumentError);
      expect(() => r.agregarEgreso(TipoEgreso.vomito, double.nan),
          throwsArgumentError);
      expect(() => RegistroLiquidos(horasTurno: 0), throwsArgumentError);
      expect(() => RegistroLiquidos(horasTurno: 12, pesoKg: -5),
          throwsArgumentError);
    });

    test('las vistas de ingresos y egresos son de solo lectura', () {
      final r = RegistroLiquidos(horasTurno: 6);
      expect(() => r.ingresos[TipoIngreso.oral] = 1, throwsUnsupportedError);
    });
  });
}
