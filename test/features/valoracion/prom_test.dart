import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:notemed/features/notas/application/generador_nota_turno.dart';
import 'package:notemed/features/notas/data/ia/servicio_ia_simulado.dart';
import 'package:notemed/features/notas/domain/turno/datos_turno.dart';
import 'package:notemed/features/pacientes/domain/signos_vitales.dart';
import 'package:notemed/features/valoracion/domain/prom/evaluacion_prom.dart';
import 'package:notemed/features/valoracion/presentation/prom_screen.dart';

import '../../apoyo/dobles.dart';

EvaluacionProm _completa({int dolor = 3}) {
  var e = const EvaluacionProm();
  for (final i in ItemProm.values) {
    e = e.conRespuesta(i, i == ItemProm.dolor ? dolor : 1);
  }
  return e;
}

void main() {
  group('EvaluacionProm', () {
    test('está completa cuando se responden todos los ítems', () {
      expect(const EvaluacionProm().completa, isFalse);
      expect(
        const EvaluacionProm().pendientes,
        hasLength(ItemProm.values.length),
      );
      expect(_completa().completa, isTrue);
    });

    test('rechaza valores fuera de 0 a 10', () {
      expect(
        () => const EvaluacionProm().conRespuesta(ItemProm.dolor, 11),
        throwsRangeError,
      );
      expect(
        () => const EvaluacionProm().conRespuesta(ItemProm.dolor, -1),
        throwsRangeError,
      );
    });

    test('si no puede responder, necesita el motivo', () {
      final e = const EvaluacionProm().conPuedeResponder(false);
      expect(e.completa, isFalse);
      final m = e.conMotivo(MotivoNoResponde.sedacion);
      expect(m.completa, isTrue);
      expect(m.toTexto(), contains('no valorables (bajo sedación)'));
      expect(m.alertas, isEmpty);
    });

    test('alerta con valores de 7 o más', () {
      final e = _completa(dolor: 8);
      expect(e.alertas, ['Dolor: 8/10']);
      expect(e.resumen, 'Alerta: Dolor: 8/10');
      expect(_completa().resumen, 'Sin valores altos');
    });

    test('toMap y fromMap', () {
      final e = _completa(dolor: 5);
      final c = EvaluacionProm.fromMap(e.toMap());
      expect(c.respuestas, e.respuestas);
      expect(c.puedeResponder, isTrue);
      final n = EvaluacionProm.fromMap(
        const EvaluacionProm().conMotivo(MotivoNoResponde.viaAerea).toMap(),
      );
      expect(n.motivo, MotivoNoResponde.viaAerea);
    });

    test('el texto no usa la sigla PROM', () {
      expect(_completa().toTexto(), isNot(contains('PROM')));
      expect(
        _completa().toTexto(),
        startsWith('Resultados reportados por el paciente: dolor 3/10'),
      );
    });
  });

  test('la nota con PROM no genera advertencias de signos ni siglas', () async {
    final datos = DatosTurno(
      paciente: pacienteEjemplo,
      signos: const SignosVitales(taSistolica: 120, taDiastolica: 80, fr: 18),
      prom: _completa(dolor: 8),
    );
    final copia = DatosTurno.fromMap(datos.toMap());
    expect(copia.prom!.respuestas[ItemProm.dolor], 8);

    final r = await GeneradorNotaTurno(
      const ServicioIASimulado(demora: Duration.zero),
    ).generar(datos);
    expect(r.texto, contains('dolor 8/10'));
    expect(r.mensajes, isEmpty, reason: r.mensajes.join('\n'));
  });

  testWidgets('la pantalla guarda cuando todo está respondido', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 4000)
      ..devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    EvaluacionProm? guardada;
    await tester.pumpWidget(
      MaterialApp(home: PromScreen(onGuardar: (e) async => guardada = e)),
    );

    final guardar = find.byKey(const Key('prom-guardar'));
    expect(tester.widget<ButtonStyleButton>(guardar).enabled, isFalse);
    for (final i in ItemProm.values) {
      final chip = find.byKey(
        Key('prom-${i.name}-${i == ItemProm.dolor ? 9 : 2}'),
      );
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();
    }
    expect(find.byKey(const Key('prom-alertas')), findsOneWidget);
    await tester.tap(guardar);
    await tester.pump();
    expect(guardada!.respuestas[ItemProm.dolor], 9);
  });

  testWidgets('si el paciente no puede responder pide el motivo', (
    tester,
  ) async {
    EvaluacionProm? guardada;
    await tester.pumpWidget(
      MaterialApp(home: PromScreen(onGuardar: (e) async => guardada = e)),
    );
    await tester.tap(find.byKey(const Key('prom-puede')));
    await tester.pump();
    expect(find.text('Seleccione el motivo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('prom-motivo-sedacion')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('prom-guardar')));
    await tester.pump();
    expect(guardada!.motivo, MotivoNoResponde.sedacion);
  });
}
