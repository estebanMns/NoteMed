import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notemed/features/notas/application/generador_nota_fallecimiento.dart';
import 'package:notemed/features/notas/application/generador_nota_turno.dart';
import 'package:notemed/features/notas/application/servicio_notas.dart';
import 'package:notemed/features/notas/data/ia/servicio_ia_remoto.dart';
import 'package:notemed/features/notas/data/ia/servicio_ia_simulado.dart';
import 'package:notemed/features/notas/domain/fallecimiento/datos_fallecimiento.dart';
import 'package:notemed/features/notas/domain/prompts/version_prompts.dart';
import 'package:notemed/features/notas/domain/servicio_ia.dart';
import 'package:notemed/features/notas/domain/turno/datos_turno.dart';
import 'package:notemed/features/pacientes/domain/infusion.dart';
import 'package:notemed/features/pacientes/domain/signos_vitales.dart';
import 'package:notemed/features/valoracion/domain/downton/downton_escala.dart';

import '../../apoyo/dobles.dart';

const _ia = ServicioIASimulado(demora: Duration.zero);

final _datos = DatosTurno(
  paciente: pacienteEjemplo,
  signos: const SignosVitales(
    taSistolica: 118,
    taDiastolica: 76,
    fc: 92,
    fr: 20,
    spo2: 94,
    temperatura: 37.2,
  ),
  infusiones: const [
    Infusion(
      medicamento: 'Noradrenalina',
      dosis: 0.1,
      unidad: UnidadDosis.mcgKgMin,
      ritmoMlH: 8,
    ),
  ],
  downton: const EvaluacionDownton()
      .conFactor(FactorDownton.tranquilizantes, true)
      .conDeambulacion(DeambulacionDownton.imposible),
  observaciones: 'La señora Gómez refiere dolor leve.',
);

void main() {
  group('ServicioIASimulado', () {
    test('funciona sin red', () => expect(_ia.funcionaSinRed, isTrue));

    test('lee los campos de la solicitud, con listas', () {
      final c = ServicioIASimulado.leerCampos(
        'Paciente: PAC-001, 60 años\nInfusiones: \n- A 1 mg\n- B 2 mg\n'
        'Observaciones: Ninguna',
      );
      expect(c['Paciente'], 'PAC-001, 60 años');
      expect(c['Infusiones'], 'A 1 mg; B 2 mg');
      expect(c['Observaciones'], 'Ninguna');
    });

    test('la nota de turno sale en SBAR, con datos reales y sin '
        'advertencias', () async {
      final r = await GeneradorNotaTurno(_ia).generar(_datos);
      final lineas = r.texto.split('\n');
      expect(lineas, hasLength(4));
      expect(lineas[0], startsWith('[S] Situación: Paciente María Fernanda'));
      expect(lineas[1], startsWith('[B] Antecedentes:'));
      expect(lineas[2], startsWith('[A] Evaluación:'));
      expect(lineas[3], startsWith('[R] Recomendación:'));
      expect(r.texto, contains('cama 12B'));
      expect(r.texto, contains('TA 118/76 mmHg'));
      expect(r.texto, contains('Noradrenalina 0.1 mcg/kg/min a 8 mL/h'));
      expect(r.texto, contains('Escala de Braden: No registrada'));
      expect(
        r.texto,
        contains('señora María Fernanda Gómez refiere dolor leve'),
      );
      expect(r.texto, isNot(contains('PAC-')));
      expect(r.texto, isNot(contains('1085123456')));
      expect(r.mensajes, isEmpty, reason: r.mensajes.join('\n'));
      expect(r.bloqueaFirma, isFalse);
    });

    test(
      'la nota de fallecimiento no agrega horas, fechas ni causas',
      () async {
        final r = await GeneradorNotaFallecimiento(_ia).generar(
          pacienteEjemplo,
          DatosFallecimiento(
            fechaHora: DateTime(2026, 11, 20, 3, 40),
            quienCertifica: 'médico de turno',
            signosObservados: [signosDeMuerte.first],
            cuidadosRealizados: [cuidadosPostMortem.first],
          ),
        );
        expect(
          r.texto,
          contains('Fecha y hora del fallecimiento: 20/11/2026 03:40'),
        );
        expect(r.texto, contains('Certificado por: médico de turno'));
        expect(r.texto, contains('Información y entrega: No registrado'));
        expect(r.problemas, isEmpty);
        expect(r.bloqueaFirma, isFalse);
      },
    );

    test('ServicioNotas genera el borrador aunque no haya red', () async {
      final repo = RepositorioMemoria();
      final red = RedSimulada(conectada: false);
      addTearDown(red.cerrar);
      final servicio = ServicioNotas(repositorio: repo, ia: _ia, red: red);
      final p = await repo.guardarPaciente(pacienteEjemplo);

      final r = await servicio.notaTurno(await servicio.datosTurno(p));

      expect(r, isA<BorradorGuardado>());
      expect(await repo.pendientes(), isEmpty);
    });
  });

  group('ServicioIARemoto', () {
    test(
      'envía la solicitud anonimizada y la versión de los prompts',
      () async {
        late http.Request enviada;
        final ia = ServicioIARemoto(
          urlBase: 'https://servidor/api',
          token: () => 'abc',
          cliente: MockClient((req) async {
            enviada = req;
            return http.Response(
              jsonEncode({'texto': ' Nota lista. '}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final texto = await ia.generar(
          sistema: 'S',
          usuario: 'Paciente: PAC-001',
        );

        expect(texto, 'Nota lista.');
        expect(ia.funcionaSinRed, isFalse);
        expect(enviada.url.toString(), 'https://servidor/api/v1/ia/borradores');
        expect(enviada.headers['authorization'], 'Bearer abc');
        expect(jsonDecode(enviada.body), {
          'versionPrompts': versionPrompts,
          'sistema': 'S',
          'solicitud': 'Paciente: PAC-001',
        });
      },
    );

    test('un error 503 se puede reintentar; un 400 no', () async {
      ServicioIARemoto con(int codigo) => ServicioIARemoto(
        urlBase: 'https://servidor',
        cliente: MockClient(
          (_) async =>
              http.Response.bytes(utf8.encode('{"error":"caído"}'), codigo),
        ),
      );

      await expectLater(
        con(503).generar(sistema: '', usuario: ''),
        throwsA(
          isA<ErrorIA>()
              .having((e) => e.sinConexion, 'sinConexion', isTrue)
              .having((e) => e.mensaje, 'mensaje', contains('caído')),
        ),
      );
      await expectLater(
        con(400).generar(sistema: '', usuario: ''),
        throwsA(isA<ErrorIA>().having((e) => e.sinConexion, 'sin', isFalse)),
      );
    });

    test('sin conexión lanza un error que permite encolar', () async {
      final ia = ServicioIARemoto(
        urlBase: 'https://servidor',
        cliente: MockClient((_) async => throw http.ClientException('sin red')),
      );
      await expectLater(
        ia.generar(sistema: '', usuario: ''),
        throwsA(isA<ErrorIA>().having((e) => e.sinConexion, 'sin', isTrue)),
      );
    });
  });
}
