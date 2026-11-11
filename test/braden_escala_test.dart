// TSK-05 / TSK-07 · HU02: escala de Braden.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notemed/features/riesgos/braden/braden_escala.dart';
import 'package:notemed/features/riesgos/braden/braden_screen.dart';

EvaluacionBraden _todas(int Function(SubescalaBraden) puntos) {
  var e = const EvaluacionBraden();
  for (final s in SubescalaBraden.values) {
    e = e.conPuntaje(s, puntos(s));
  }
  return e;
}

void main() {
  group('EvaluacionBraden (TSK-07)', () {
    test('no hay total ni nivel hasta completar las 6 subescalas', () {
      final e = const EvaluacionBraden()
          .conPuntaje(SubescalaBraden.humedad, 2);
      expect(e.completa, isFalse);
      expect(e.total, isNull);
      expect(e.nivel, isNull);
      expect(e.pendientes, hasLength(5));
    });

    test('mínimo 6 = riesgo muy alto; máximo 23 = sin riesgo', () {
      final min = _todas((s) => s.minimo);
      final max = _todas((s) => s.maximo);
      expect(min.total, 6);
      expect(min.nivel, NivelRiesgoBraden.muyAlto);
      expect(max.total, 23);
      expect(max.nivel, NivelRiesgoBraden.sinRiesgo);
    });

    test('suma un caso típico', () {
      // 2+2+1+2+3+2 = 12 → alto
      const p = {
        SubescalaBraden.percepcionSensorial: 2,
        SubescalaBraden.humedad: 2,
        SubescalaBraden.actividad: 1,
        SubescalaBraden.movilidad: 2,
        SubescalaBraden.nutricion: 3,
        SubescalaBraden.friccionCizallamiento: 2,
      };
      final e = _todas((s) => p[s]!);
      expect(e.total, 12);
      expect(e.nivel, NivelRiesgoBraden.alto);
    });

    test('puntos de corte de cada nivel', () {
      const esperado = {
        9: NivelRiesgoBraden.muyAlto,
        10: NivelRiesgoBraden.alto,
        12: NivelRiesgoBraden.alto,
        13: NivelRiesgoBraden.moderado,
        14: NivelRiesgoBraden.moderado,
        15: NivelRiesgoBraden.bajo,
        18: NivelRiesgoBraden.bajo,
        19: NivelRiesgoBraden.sinRiesgo,
      };
      esperado.forEach((total, nivel) {
        expect(EvaluacionBraden.nivelPara(total), nivel, reason: '$total');
      });
    });

    test('rechaza puntajes fuera de rango', () {
      expect(
          () => const EvaluacionBraden()
              .conPuntaje(SubescalaBraden.friccionCizallamiento, 4),
          throwsRangeError);
      expect(() => const EvaluacionBraden()
          .conPuntaje(SubescalaBraden.nutricion, 0), throwsRangeError);
      expect(() => EvaluacionBraden.nivelPara(5), throwsRangeError);
      expect(() => EvaluacionBraden.nivelPara(24), throwsRangeError);
    });

    test('es inmutable', () {
      const base = EvaluacionBraden();
      base.conPuntaje(SubescalaBraden.humedad, 3);
      expect(base.puntajes, isEmpty);
    });

    test('fricción tiene 3 opciones y las demás 4', () {
      for (final s in SubescalaBraden.values) {
        expect(s.opciones.length,
            s == SubescalaBraden.friccionCizallamiento ? 3 : 4);
      }
    });
  });

  group('BradenScreen (TSK-05)', () {
    testWidgets('muestra las subescalas pendientes y se actualiza al elegir',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BradenScreen()));
      expect(find.text('Faltan 6 de 6 subescalas'), findsOneWidget);
      expect(find.byKey(const Key('braden-nivel')), findsNothing);

      await tester.tap(find.byKey(const Key('braden-percepcionSensorial-1')));
      await tester.pump();
      expect(find.text('Faltan 5 de 6 subescalas'), findsOneWidget);
    });

    testWidgets('al completar muestra el total, el nivel y permite guardar',
        (tester) async {
      EvaluacionBraden? guardada;
      await tester.pumpWidget(MaterialApp(
        home: BradenScreen(onGuardar: (e) => guardada = e),
      ));
      for (final s in SubescalaBraden.values) {
        final opcion = find.byKey(Key('braden-${s.name}-${s.maximo}'));
        await tester.scrollUntilVisible(opcion, 200,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(opcion);
        await tester.pump();
      }
      expect(find.text('Total: 23 / 23'), findsOneWidget);
      expect(find.text('Sin riesgo'), findsOneWidget);

      await tester.tap(find.text('Guardar'));
      expect(guardada?.total, 23);
    });
  });
}
