// TSK-09 / TSK-11 · HU03: botón "Generar Nota de Turno" y envío de los
// datos del paciente a la IA.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notemed/core/ia/claude_servicio_ia.dart';
import 'package:notemed/core/ia/servicio_ia.dart';
import 'package:notemed/features/nota/servicio_notas.dart';
import 'package:notemed/features/paciente/infusion.dart';
import 'package:notemed/features/paciente/paciente.dart';
import 'package:notemed/features/paciente/paciente_screen.dart';
import 'package:notemed/features/paciente/signos_vitales.dart';
import 'package:notemed/features/riesgos/downton/downton_escala.dart';
import 'package:notemed/features/turno/generador_nota_turno.dart';

import 'apoyo/dobles.dart';

void main() {
  const signos = SignosVitales(
    taSistolica: 120,
    taDiastolica: 80,
    fc: 88,
    fr: 18,
    spo2: 94,
  );
  final datos = DatosTurno(
    paciente: pacienteEjemplo.conId(1),
    signos: signos,
    infusiones: const [
      Infusion(
        medicamento: 'Midazolam',
        dosis: 2,
        unidad: UnidadDosis.mgH,
        ritmoMlH: 4,
      ),
    ],
    downton: const EvaluacionDownton()
        .conFactor(FactorDownton.caidasPrevias, true)
        .conDeambulacion(DeambulacionDownton.normal),
    observaciones: 'La Sra. Gómez durmió bien.',
  );

  group('GeneradorNotaTurno (TSK-11)', () {
    test('la solicitud lleva todos los datos registrados', () {
      final s = construirSolicitudTurno(datos);
      expect(s, contains('María Fernanda Gómez'));
      expect(s, contains('TA 120/80 mmHg'));
      expect(s, contains('Midazolam 2 mg/h a 4 mL/h'));
      expect(s, contains('Escala de Downton: 1 puntos'));
      expect(s, contains('Escala de Braden: No registrada'));
      expect(s, contains('durmió bien'));
    });

    test('envía a la IA los datos sin información personal', () async {
      final ia = IASimulada();
      await GeneradorNotaTurno(ia).generar(datos);
      final enviado = ia.recibidas.single.usuario;
      expect(enviado, isNot(contains('María')));
      expect(enviado, isNot(contains('Gómez')));
      expect(enviado, isNot(contains('1085123456')));
      expect(enviado, isNot(contains('12B')));
      expect(enviado, contains('PAC-001'));
      expect(enviado, contains('TA 120/80 mmHg'));
    });

    test('las instrucciones exigen no inventar datos y formato SBAR', () async {
      final ia = IASimulada();
      await GeneradorNotaTurno(ia).generar(datos);
      final sistema = ia.recibidas.single.sistema;
      expect(sistema, contains('No inventes'));
      expect(sistema, contains('No registrado'));
      expect(sistema, contains('[S] Situación:'));
      expect(sistema, contains('SNG: sonda nasogástrica'));
    });

    test('restaura los datos reales y revisa la respuesta', () async {
      final ia = IASimulada(
        (_, _) =>
            '[S] Situación: PAC-001, CAMA-001, TA 120/80 mmHg, FC 90 lpm, '
            'FR 18, SpO2 94 %. Insulina 10 UI.',
      );
      final r = await GeneradorNotaTurno(ia).generar(datos);
      expect(
        r.texto,
        startsWith('[S] Situación: María Fernanda Gómez, cama 12B'),
      );
      expect(r.discrepancias.single.mensaje, contains('FC'));
      expect(r.bloqueaFirma, isTrue);
      expect(r.siglas.single.sigla, 'UI');
    });

    test('DatosTurno se puede guardar y recuperar (cola sin conexión)', () {
      final copia = DatosTurno.fromMap(
        jsonDecode(jsonEncode(datos.toMap())) as Map<String, Object?>,
      );
      expect(construirSolicitudTurno(copia), construirSolicitudTurno(datos));
    });
  });

  group('ClaudeServicioIA (TSK-11)', () {
    Map<String, Object?> respuesta(String texto, {String stop = 'end_turn'}) =>
        {
          'type': 'message',
          'stop_reason': stop,
          'content': [
            {'type': 'text', 'text': texto},
          ],
        };

    test('envía modelo, encabezados e instrucciones correctas', () async {
      late http.Request enviada;
      final cliente = MockClient((r) async {
        enviada = r;
        return http.Response.bytes(
          utf8.encode(jsonEncode(respuesta('Nota lista ñ'))),
          200,
        );
      });
      final ia = ClaudeServicioIA(apiKey: 'clave-prueba', cliente: cliente);

      final texto = await ia.generar(sistema: 'reglas', usuario: 'datos');

      expect(texto, 'Nota lista ñ');
      expect(enviada.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(enviada.headers['x-api-key'], 'clave-prueba');
      expect(enviada.headers['anthropic-version'], '2026-10-21');
      final cuerpo = jsonDecode(enviada.body) as Map<String, Object?>;
      expect(cuerpo['model'], 'claude-opus-5-5');
      expect(cuerpo['system'], 'reglas');
      expect(cuerpo['messages'], [
        {'role': 'user', 'content': 'datos'},
      ]);
      expect(cuerpo.containsKey('temperature'), isFalse);
    });

    test('une varios bloques de texto e ignora los demás', () async {
      final ia = ClaudeServicioIA(
        apiKey: 'k',
        cliente: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'stop_reason': 'end_turn',
              'content': [
                {'type': 'thinking', 'thinking': ''},
                {'type': 'text', 'text': 'Parte 1. '},
                {'type': 'text', 'text': 'Parte 2.'},
              ],
            }),
            200,
          ),
        ),
      );
      expect(await ia.generar(sistema: 's', usuario: 'u'), 'Parte 1. Parte 2.');
    });

    Future<ErrorIA> error(MockClient c) async {
      try {
        await ClaudeServicioIA(
          apiKey: 'k',
          cliente: c,
        ).generar(sistema: 's', usuario: 'u');
      } on ErrorIA catch (e) {
        return e;
      }
      fail('debía lanzar ErrorIA');
    }

    test('error 401: clave inválida, no se reintenta', () async {
      final e = await error(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'type': 'error',
              'error': {
                'type': 'authentication_error',
                'message': 'invalid x-api-key',
              },
            }),
            401,
          ),
        ),
      );
      expect(e.codigo, 401);
      expect(e.sinConexion, isFalse);
      expect(e.mensaje, contains('Clave de la API inválida'));
    });

    test('errores 429 y 5xx se pueden reintentar', () async {
      for (final codigo in [429, 500, 529]) {
        final e = await error(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                'error': {'message': 'x'},
              }),
              codigo,
            ),
          ),
        );
        expect(e.sinConexion, isTrue, reason: '$codigo');
      }
    });

    test('sin red lanza un error marcado como sin conexión', () async {
      final e = await error(
        MockClient(
          (_) async => throw http.ClientException('Failed host lookup'),
        ),
      );
      expect(e.sinConexion, isTrue);
    });

    test('una respuesta declinada o cortada no se usa como nota', () async {
      final rechazo = await error(
        MockClient(
          (_) async =>
              http.Response(jsonEncode(respuesta('', stop: 'refusal')), 200),
        ),
      );
      expect(rechazo.mensaje, contains('declinó'));
      final cortada = await error(
        MockClient(
          (_) async => http.Response(
            jsonEncode(respuesta('[S] Situ', stop: 'max_tokens')),
            200,
          ),
        ),
      );
      expect(cortada.mensaje, contains('incompleta'));
    });
  });

  group('Botón "Generar Nota de Turno" (TSK-09)', () {
    late RepositorioMemoria repo;
    late RedSimulada red;
    late IASimulada ia;
    late ServicioNotas servicio;
    late Paciente paciente;

    setUp(() async {
      repo = RepositorioMemoria();
      red = RedSimulada();
      ia = IASimulada(
        (_, _) =>
            '[S] Situación: PAC-001 en CAMA-001, TA 120/80 mmHg.\n'
            '[B] Antecedentes: No registrado.\n'
            '[A] Evaluación: Estable.\n'
            '[R] Recomendación: Control de signos.',
      );
      servicio = ServicioNotas(repositorio: repo, ia: ia, red: red);
      paciente = await repo.guardarPaciente(pacienteEjemplo);
      await repo.guardarSignos(
        paciente.id!,
        const SignosVitales(taSistolica: 120, taDiastolica: 80),
      );
    });

    tearDown(() => red.cerrar());

    Future<void> abrir(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PacienteScreen(
            paciente: paciente,
            repositorio: repo,
            servicioNotas: servicio,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('está en la pantalla del paciente', (tester) async {
      await abrir(tester);
      final boton = find.byKey(const Key('btn-generar-nota'));
      expect(boton, findsOneWidget);
      expect(find.text('Generar Nota de Turno'), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(boton).enabled, isTrue);
    });

    testWidgets('genera la nota y abre el borrador con los datos reales', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(find.byKey(const Key('btn-generar-nota')));
      await tester.pumpAndSettle();

      expect(ia.recibidas, hasLength(1));
      final campo = tester.widget<TextField>(
        find.byKey(const Key('borrador-texto')),
      );
      expect(
        campo.controller!.text,
        startsWith('[S] Situación: María Fernanda Gómez en cama 12B'),
      );
      expect(
        (await repo.notas(paciente.id!)).single.firma,
        isNull,
        reason: 'el borrador queda guardado antes de firmar',
      );
    });

    testWidgets('no genera si los signos vitales son inválidos', (
      tester,
    ) async {
      await abrir(tester);
      await tester.enterText(find.byKey(const Key('sv-spo2')), '120');
      await tester.tap(find.byKey(const Key('btn-generar-nota')));
      await tester.pumpAndSettle();
      expect(ia.recibidas, isEmpty);
      expect(
        find.text('Corrija los signos vitales antes de generar la nota'),
        findsOneWidget,
      );
    });

    testWidgets('sin red deja la solicitud en cola y lo avisa', (tester) async {
      red.conectada = false;
      await abrir(tester);
      await tester.tap(find.byKey(const Key('btn-generar-nota')));
      await tester.pumpAndSettle();

      expect(ia.recibidas, isEmpty);
      expect(find.textContaining('Sin conexión'), findsOneWidget);
      expect(find.byKey(const Key('aviso-pendientes')), findsOneWidget);
      expect(await repo.pendientes(), hasLength(1));
    });

    testWidgets('muestra el error de la IA sin cerrar la pantalla', (
      tester,
    ) async {
      ia.error = const ErrorIA('Clave de la API inválida (HTTP 401).');
      await abrir(tester);
      await tester.tap(find.byKey(const Key('btn-generar-nota')));
      await tester.pumpAndSettle();
      expect(find.text('Clave de la API inválida (HTTP 401).'), findsOneWidget);
      expect(find.byKey(const Key('btn-generar-nota')), findsOneWidget);
    });
  });
}
