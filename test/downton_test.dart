// TSK-06 / TSK-08 · HU02: escala de Downton y recomendaciones de cuidado.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notemed/features/riesgos/braden/braden_escala.dart';
import 'package:notemed/features/riesgos/braden/braden_screen.dart';
import 'package:notemed/features/riesgos/downton/downton_escala.dart';
import 'package:notemed/features/riesgos/downton/downton_screen.dart';
import 'package:notemed/features/riesgos/recomendaciones_riesgo.dart';

void main() {
  group('EvaluacionDownton (TSK-06)', () {
    test('está incompleta hasta elegir la deambulación', () {
      const e = EvaluacionDownton();
      expect(e.completa, isFalse);
      expect(e.riesgoAlto, isNull);
      expect(e.conDeambulacion(DeambulacionDownton.normal).completa, isTrue);
    });

    test('cada factor suma 1 punto y la deambulación normal 0', () {
      final e = const EvaluacionDownton()
          .conFactor(FactorDownton.diureticos, true)
          .conFactor(FactorDownton.alteracionesVisuales, true)
          .conDeambulacion(DeambulacionDownton.normal);
      expect(e.total, 2);
      expect(e.riesgoAlto, isFalse);
    });

    test('3 puntos o más es riesgo alto', () {
      final e = const EvaluacionDownton()
          .conFactor(FactorDownton.caidasPrevias, true)
          .conFactor(FactorDownton.tranquilizantes, true)
          .conDeambulacion(DeambulacionDownton.insegura);
      expect(e.total, 3);
      expect(e.riesgoAlto, isTrue);
      expect(e.etiquetaRiesgo, 'Riesgo alto de caídas');
    });

    test('desmarcar un factor lo resta', () {
      final e = const EvaluacionDownton()
          .conFactor(FactorDownton.confusion, true)
          .conFactor(FactorDownton.confusion, false)
          .conDeambulacion(DeambulacionDownton.imposible);
      expect(e.total, 1);
    });

    test('el puntaje máximo es 12', () {
      var e = const EvaluacionDownton().conDeambulacion(
        DeambulacionDownton.seguraConAyuda,
      );
      for (final f in FactorDownton.values) {
        e = e.conFactor(f, true);
      }
      expect(e.total, EvaluacionDownton.puntajeMaximo);
      expect(EvaluacionDownton.puntajeMaximo, 12);
    });

    test('toMap y fromMap conservan la evaluación', () {
      final e = const EvaluacionDownton()
          .conFactor(FactorDownton.antidepresivos, true)
          .conDeambulacion(DeambulacionDownton.seguraConAyuda);
      final copia = EvaluacionDownton.fromMap(e.toMap());
      expect(copia.factores, e.factores);
      expect(copia.deambulacion, e.deambulacion);
    });
  });

  group('Recomendaciones (TSK-08)', () {
    test('Downton solo recomienda con riesgo alto', () {
      final bajo = const EvaluacionDownton().conDeambulacion(
        DeambulacionDownton.normal,
      );
      final alto = const EvaluacionDownton()
          .conFactor(FactorDownton.caidasPrevias, true)
          .conFactor(FactorDownton.diureticos, true)
          .conDeambulacion(DeambulacionDownton.insegura);
      expect(recomendacionesDownton(bajo), isEmpty);
      expect(recomendacionesDownton(alto), recomendacionesCaidas);
    });

    test('Braden recomienda en riesgo alto y muy alto', () {
      expect(recomendacionesBraden(NivelRiesgoBraden.muyAlto), isNotEmpty);
      expect(recomendacionesBraden(NivelRiesgoBraden.alto), isNotEmpty);
      expect(recomendacionesBraden(NivelRiesgoBraden.moderado), isEmpty);
      expect(recomendacionesBraden(null), isEmpty);
    });
  });

  group('DowntonScreen', () {
    Future<void> marcar(WidgetTester tester, String key) async {
      final f = find.byKey(Key(key));
      await tester.scrollUntilVisible(
        f,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(f);
      await tester.pump();
    }

    testWidgets('muestra recomendaciones al llegar a riesgo alto', (
      tester,
    ) async {
      EvaluacionDownton? guardada;
      await tester.pumpWidget(
        MaterialApp(home: DowntonScreen(onGuardar: (e) => guardada = e)),
      );

      expect(find.text('Seleccione la deambulación'), findsOneWidget);
      expect(find.byKey(const Key('recomendaciones')), findsNothing);

      await marcar(tester, 'downton-caidasPrevias');
      await marcar(tester, 'downton-hipotensores');
      await marcar(tester, 'downton-deambulacion-normal');
      expect(find.text('Total: 2 / 12'), findsOneWidget);
      expect(find.text('Riesgo bajo de caídas'), findsOneWidget);

      await marcar(tester, 'downton-confusion');
      expect(find.text('Total: 3 / 12'), findsOneWidget);
      expect(find.text('Riesgo alto de caídas'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('recomendaciones')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('• ${recomendacionesCaidas.first}'), findsOneWidget);

      await tester.tap(find.byKey(const Key('downton-guardar')));
      expect(guardada?.total, 3);
    });

    testWidgets('BradenScreen muestra recomendaciones con riesgo alto', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: BradenScreen()));
      for (final s in SubescalaBraden.values) {
        final opcion = find.byKey(Key('braden-${s.name}-1'));
        await tester.scrollUntilVisible(
          opcion,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(opcion);
        await tester.pump();
      }
      await tester.scrollUntilVisible(
        find.byKey(const Key('recomendaciones')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('recomendaciones')), findsOneWidget);
    });
  });
}
