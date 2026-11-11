// TSK-14 / TSK-15 · HU04: procedimientos invasivos y nota de fallecimiento.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notemed/features/fallecimiento/fallecimiento_screen.dart';
import 'package:notemed/features/fallecimiento/nota_fallecimiento.dart';
import 'package:notemed/features/procedimientos/procedimiento_form.dart';
import 'package:notemed/features/procedimientos/procedimiento_invasivo.dart';

import 'apoyo/dobles.dart';

void main() {
  final ahora = DateTime(2026, 11, 11, 10, 0);

  group('ProcedimientoInvasivo (TSK-14)', () {
    ProcedimientoInvasivo proc({
      TipoProcedimiento tipo = TipoProcedimiento.sondaVesical,
      DateTime? fecha,
      String sitio = 'meato urinario',
      int intentos = 1,
      String responsable = 'enfermera jefe',
      String? otro,
    }) => ProcedimientoInvasivo(
      tipo: tipo,
      fechaHora: fecha ?? DateTime(2026, 11, 11, 8, 30),
      sitio: sitio,
      calibre: '16 Fr',
      intentos: intentos,
      responsable: responsable,
      descripcionOtro: otro,
    );

    test('un procedimiento completo es válido', () {
      expect(proc().validar(ahora: ahora), isEmpty);
    });

    test('exige sitio, responsable e intentos entre 1 y 10', () {
      final errores = proc(
        sitio: ' ',
        responsable: '',
        intentos: 0,
      ).validar(ahora: ahora);
      expect(errores, hasLength(3));
    });

    test('"otro" exige describir el procedimiento', () {
      expect(
        proc(tipo: TipoProcedimiento.otro).validar(ahora: ahora),
        contains('Describa el procedimiento'),
      );
      expect(
        proc(
          tipo: TipoProcedimiento.otro,
          otro: 'Toracostomía',
        ).validar(ahora: ahora),
        isEmpty,
      );
    });

    test('no acepta fecha futura', () {
      expect(
        proc(fecha: ahora.add(const Duration(hours: 1))).validar(ahora: ahora),
        contains('La fecha y hora no puede ser futura'),
      );
    });

    test('toTexto y serialización', () {
      final p = proc();
      expect(
        p.toTexto(),
        'Sonda vesical (calibre 16 Fr) en meato urinario, 11/11/2026 08:30, '
        '1 intento, por enfermera jefe',
      );
      expect(ProcedimientoInvasivo.fromMap(p.toMap()).toTexto(), p.toTexto());
    });

    testWidgets('el formulario valida y guarda', (tester) async {
      ProcedimientoInvasivo? guardado;
      await tester.pumpWidget(
        MaterialApp(
          home: ProcedimientoFormScreen(
            ahora: () => ahora,
            onGuardar: (p) => guardado = p,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('proc-guardar')));
      await tester.pump();
      expect(guardado, isNull);
      expect(find.text('El sitio es obligatorio'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('proc-sitio')),
        'antebrazo izquierdo',
      );
      await tester.enterText(find.byKey(const Key('proc-calibre')), '20 G');
      await tester.enterText(
        find.byKey(const Key('proc-responsable')),
        'auxiliar de enfermería',
      );
      await tester.ensureVisible(find.byKey(const Key('proc-guardar')));
      await tester.tap(find.byKey(const Key('proc-guardar')));
      await tester.pump();

      expect(guardado?.tipo, TipoProcedimiento.cateterVenosoPeriferico);
      expect(guardado?.sitio, 'antebrazo izquierdo');
      expect(guardado?.fechaHora, ahora);
    });
  });

  group('Nota de fallecimiento (TSK-15)', () {
    final datos = DatosFallecimiento(
      fechaHora: DateTime(2026, 11, 11, 3, 40),
      quienCertifica: 'médico de turno',
      signosObservados: const [
        'Ausencia de pulso central',
        'Ausencia de respiración espontánea',
      ],
      reanimacion: true,
      duracionReanimacionMin: 30,
      cuidadosRealizados: const ['Retiro de dispositivos invasivos'],
      entregaA: 'hija',
    );
    final paciente = pacienteEjemplo.conId(1);

    test('las instrucciones prohíben inventar datos y causas', () {
      expect(
        instruccionesNotaFallecimiento,
        contains('Usa únicamente los datos'),
      );
      expect(instruccionesNotaFallecimiento, contains('"No registrado"'));
      expect(instruccionesNotaFallecimiento, contains('No escribas la causa'));
      expect(
        instruccionesNotaFallecimiento,
        contains('Fecha y hora del fallecimiento:'),
      );
    });

    test('valida los datos mínimos', () {
      final incompleto = DatosFallecimiento(
        fechaHora: ahora,
        quienCertifica: '',
        reanimacion: true,
      );
      expect(incompleto.validar(), hasLength(3));
      expect(datos.validar(), isEmpty);
    });

    test('la solicitud tiene solo los datos registrados', () {
      final s = construirSolicitudFallecimiento(paciente, datos);
      expect(s, contains('11/11/2026 03:40'));
      expect(s, contains('Sí, durante 30 minutos'));
      expect(s, contains('Dispositivos invasivos presentes: No registrado'));
      expect(s, contains('Información y entrega a: hija'));
    });

    test('el validador rechaza horas, fechas y causas inventadas', () {
      final solicitud = construirSolicitudFallecimiento(paciente, datos);
      const v = ValidadorNotaFallecimiento();
      expect(
        v.problemas(
          'Fecha y hora del fallecimiento: 11/11/2026 03:40.',
          solicitud,
        ),
        isEmpty,
      );
      expect(
        v.problemas('Falleció a las 3:40.', solicitud),
        isEmpty,
        reason: '3:40 y 03:40 son la misma hora',
      );
      expect(
        v.problemas('A las 03:15 presentó bradicardia.', solicitud).single,
        contains('03:15'),
      );
      expect(
        v.problemas('Ingresó el 10/11/2026.', solicitud).single,
        contains('10/11/2026'),
      );
      expect(
        v.problemas('Falleció debido a un paro cardiaco.', solicitud).single,
        contains('causa de muerte'),
      );
    });

    test('genera la nota anonimizada y marca lo inventado', () async {
      final ia = IASimulada(
        (_, _) =>
            'Fecha y hora del fallecimiento: 11/11/2026 03:40\n'
            'Certificado por: médico de turno\n'
            'Hallazgos: PAC-001 sin pulso central. Causa de la muerte: sepsis.',
      );
      final r = await GeneradorNotaFallecimiento(ia).generar(paciente, datos);

      final enviado = ia.recibidas.single;
      expect(enviado.sistema, instruccionesNotaFallecimiento);
      expect(enviado.usuario, isNot(contains('Gómez')));
      expect(r.texto, contains('María Fernanda Gómez sin pulso central'));
      expect(r.problemas.single, contains('causa de muerte'));
      expect(r.bloqueaFirma, isTrue);
    });

    test('una nota fiel a los datos se puede firmar', () async {
      final ia = IASimulada(
        (_, _) =>
            'Fecha y hora del fallecimiento: 11/11/2026 03:40\n'
            'Certificado por: médico de turno\n'
            'Hallazgos: Ausencia de pulso central y de respiración espontánea.\n'
            'Maniobras de reanimación: Sí, durante 30 minutos.\n'
            'Dispositivos invasivos presentes: No registrado.\n'
            'Cuidados post mortem: Retiro de dispositivos invasivos.\n'
            'Información y entrega: hija.\n'
            'Observaciones: Ninguna.',
      );
      final r = await GeneradorNotaFallecimiento(ia).generar(paciente, datos);
      expect(r.mensajes, isEmpty);
      expect(r.bloqueaFirma, isFalse);
    });

    testWidgets('el formulario arma los datos y valida', (tester) async {
      DatosFallecimiento? recibidos;
      await tester.pumpWidget(
        MaterialApp(
          home: FallecimientoScreen(
            ahora: () => ahora,
            onGenerar: (d) async => recibidos = d,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('fall-generar')));
      await tester.pump();
      expect(recibidos, isNull);
      expect(find.text('Marque al menos un signo observado'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('fall-certifica')),
        'médico de turno',
      );
      await tester.tap(find.byKey(const Key('fall-signo-0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('fall-generar')));
      await tester.pump();

      expect(recibidos?.quienCertifica, 'médico de turno');
      expect(recibidos?.signosObservados, [signosDeMuerte.first]);
      expect(recibidos?.fechaHora, ahora);
      expect(recibidos?.reanimacion, isFalse);
    });
  });
}
