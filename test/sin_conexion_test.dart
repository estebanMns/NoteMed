// TSK-25 / TSK-28 · HU07: base de datos interna y pruebas de apagar y
// encender la red sin perder la información cargada. Usa SQLite real
// (sqflite_common_ffi) en un archivo temporal.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notemed/core/datos/base_datos_local.dart';
import 'package:notemed/core/datos/repositorio_pacientes.dart';
import 'package:notemed/core/ia/servicio_ia.dart';
import 'package:notemed/features/nota/firma_enfermera.dart';
import 'package:notemed/features/nota/nota_clinica.dart';
import 'package:notemed/features/nota/servicio_notas.dart';
import 'package:notemed/features/paciente/infusion.dart';
import 'package:notemed/features/paciente/signos_vitales.dart';
import 'package:notemed/features/procedimientos/procedimiento_invasivo.dart';
import 'package:notemed/features/riesgos/braden/braden_escala.dart';
import 'package:notemed/features/riesgos/downton/downton_escala.dart';
import 'package:notemed/features/turno/generador_nota_turno.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'apoyo/dobles.dart';

void main() {
  sqfliteFfiInit();
  late Directory carpeta;
  late String ruta;

  setUp(() {
    carpeta = Directory.systemTemp.createTempSync('notemed_');
    ruta = '${carpeta.path}/notemed.db';
  });

  tearDown(() => carpeta.deleteSync(recursive: true));

  Future<Database> abrir() =>
      BaseDatosLocal.abrir(factory: databaseFactoryFfi, ruta: ruta);

  const infusion = Infusion(
    medicamento: 'Noradrenalina',
    dosis: 0.1,
    unidad: UnidadDosis.mcgKgMin,
    ritmoMlH: 8,
  );
  const signos = SignosVitales(
    taSistolica: 100,
    taDiastolica: 60,
    fc: 110,
    fr: 22,
    spo2: 91,
  );

  group('Base de datos interna (TSK-25)', () {
    test('guarda y lee todos los datos del paciente', () async {
      final db = await abrir();
      final repo = RepositorioSqlite(db);
      final p = await repo.guardarPaciente(pacienteEjemplo);
      final id = p.id!;

      await repo.guardarSignos(id, signos);
      final inf = await repo.agregarInfusion(id, infusion);
      await repo.agregarProcedimiento(
        id,
        ProcedimientoInvasivo(
          tipo: TipoProcedimiento.sondaVesical,
          fechaHora: DateTime(2026, 11, 11, 8),
          sitio: 'meato urinario',
          responsable: 'enfermera jefe',
        ),
      );
      final downton = const EvaluacionDownton()
          .conFactor(FactorDownton.diureticos, true)
          .conDeambulacion(DeambulacionDownton.insegura);
      await repo.guardarDownton(id, downton);
      var braden = const EvaluacionBraden();
      for (final s in SubescalaBraden.values) {
        braden = braden.conPuntaje(s, s.minimo);
      }
      await repo.guardarBraden(id, braden);

      expect((await repo.paciente(id))!.nombre, 'María Fernanda Gómez');
      expect((await repo.signos(id)).toTexto(), signos.toTexto());
      expect((await repo.infusiones(id)).single.id, inf.id);
      expect((await repo.procedimientos(id)).single.sitio, 'meato urinario');
      expect((await repo.downton(id))!.total, 2);
      expect((await repo.braden(id))!.total, 6);

      await repo.eliminarInfusion(inf.id!);
      expect(await repo.infusiones(id), isEmpty);
      await db.close();
    });

    test(
      'las notas se guardan como borrador y se actualizan al firmar',
      () async {
        final db = await abrir();
        final repo = RepositorioSqlite(db);
        final p = await repo.guardarPaciente(pacienteEjemplo);
        final borrador = await repo.guardarNota(
          NotaClinica(
            pacienteId: p.id!,
            tipo: TipoNota.turno,
            texto: 'Borrador',
            creada: DateTime(2026, 11, 11, 7),
            referencia: {'signos': signos.toMap()},
          ),
        );
        await repo.guardarNota(
          borrador.firmar(
            'Texto final',
            FirmaEnfermera(
              trazos: const [
                [Offset.zero, Offset(4, 4)],
              ],
              tarjetaProfesional: 'TP-1234',
              fecha: DateTime(2026, 11, 11, 7, 5),
            ),
          ),
        );
        final notas = await repo.notas(p.id!);
        expect(notas, hasLength(1));
        expect(notas.single.texto, 'Texto final');
        expect(notas.single.estado, EstadoNota.firmada);
        expect(notas.single.firma!.tarjetaProfesional, 'TP-1234');
        expect(notas.single.referencia['signos'], signos.toMap());
        await db.close();
      },
    );

    test('no permite dos pacientes con la misma cédula', () async {
      final db = await abrir();
      final repo = RepositorioSqlite(db);
      await repo.guardarPaciente(pacienteEjemplo);
      await expectLater(
        repo.guardarPaciente(pacienteEjemplo),
        throwsA(isA<PacienteDuplicado>()),
      );
      await db.close();
    });

    test('borrar un paciente borra todo lo suyo', () async {
      final db = await abrir();
      final repo = RepositorioSqlite(db);
      final p = await repo.guardarPaciente(pacienteEjemplo);
      await repo.agregarInfusion(p.id!, infusion);
      await repo.guardarSignos(p.id!, signos);
      await repo.eliminarPaciente(p.id!);
      expect(await repo.pacientes(), isEmpty);
      expect(await db.query('infusiones'), isEmpty);
      expect(await db.query('signos_vitales'), isEmpty);
      await db.close();
    });

    test('los datos siguen ahí al cerrar y reabrir la app', () async {
      var db = await abrir();
      final p = await RepositorioSqlite(db).guardarPaciente(pacienteEjemplo);
      await RepositorioSqlite(db).agregarInfusion(p.id!, infusion);
      await db.close();

      db = await abrir();
      final repo = RepositorioSqlite(db);
      expect((await repo.pacientes()).single.cedula, pacienteEjemplo.cedula);
      expect(
        (await repo.infusiones(p.id!)).single.toTexto(),
        infusion.toTexto(),
      );
      await db.close();
    });
  });

  group('Apagar y encender la red (TSK-28)', () {
    String respuesta(String _, String usuario) =>
        '[S] Situación: PAC-001 en CAMA-001. TA 100/60 mmHg, FC 110 lpm, '
        'FR 22 rpm, SpO2 91 %.';

    /// Deja que el aviso de la red llegue a la cola y espera a que termine.
    Future<void> esperarCola(ServicioNotas s) async {
      await Future<void>.delayed(Duration.zero);
      await s.cola.procesarPendientes();
    }

    test('lo cargado sin red no se pierde, ni al reiniciar la app', () async {
      // 1. Con red: se registra el paciente.
      var db = await abrir();
      var repo = RepositorioSqlite(db);
      final red = RedSimulada();
      final ia = IASimulada(respuesta);
      var servicio = ServicioNotas(repositorio: repo, ia: ia, red: red);
      final p = await repo.guardarPaciente(pacienteEjemplo);

      // 2. Se apaga la red: se siguen cargando datos y se pide la nota.
      red.conectada = false;
      await repo.guardarSignos(p.id!, signos);
      await repo.agregarInfusion(p.id!, infusion);
      final r = await servicio.notaTurno(await servicio.datosTurno(p));
      expect(r, isA<SolicitudEnCola>());
      expect(ia.recibidas, isEmpty);
      expect(servicio.cola.cantidad.value, 1);

      // 3. Se cierra la app sin red y se vuelve a abrir.
      await servicio.cola.detener();
      await db.close();
      db = await abrir();
      repo = RepositorioSqlite(db);
      servicio = ServicioNotas(repositorio: repo, ia: ia, red: red);
      await servicio.cola.iniciar();

      expect((await repo.signos(p.id!)).toTexto(), signos.toTexto());
      expect(
        (await repo.infusiones(p.id!)).single.medicamento,
        'Noradrenalina',
      );
      final pendientes = await repo.pendientes();
      expect(pendientes, hasLength(1));
      expect(ia.recibidas, isEmpty, reason: 'sin red no se envía nada');

      // 4. Vuelve la red: la cola se procesa sola.
      red.conectada = true;
      await esperarCola(servicio);

      expect(ia.recibidas, hasLength(1));
      expect(ia.recibidas.single.usuario, contains('Noradrenalina'));
      expect(ia.recibidas.single.usuario, isNot(contains('Gómez')));
      expect(await repo.pendientes(), isEmpty);
      expect(servicio.cola.cantidad.value, 0);
      final nota = (await repo.notas(p.id!)).single;
      expect(nota.estado, EstadoNota.borrador);
      expect(nota.texto, contains('María Fernanda Gómez en cama 12B'));
      expect(ServicioNotas.revisor(nota)(nota.texto).bloquea, isFalse);

      await servicio.cola.detener();
      await red.cerrar();
      await db.close();
    });

    test(
      'si la red se cae durante el envío, la solicitud queda en cola',
      () async {
        final db = await abrir();
        final repo = RepositorioSqlite(db);
        final red = RedSimulada();
        final ia = IASimulada(respuesta)
          ..error = const ErrorIA('sin red', sinConexion: true);
        final servicio = ServicioNotas(repositorio: repo, ia: ia, red: red);
        final p = await repo.guardarPaciente(pacienteEjemplo);

        final r = await servicio.notaTurno(
          DatosTurno(paciente: p, signos: signos),
        );
        expect(r, isA<SolicitudEnCola>());
        expect(await repo.pendientes(), hasLength(1));

        ia.error = null;
        expect(await servicio.cola.procesarPendientes(), 1);
        expect(await repo.pendientes(), isEmpty);
        expect(await repo.notas(p.id!), hasLength(1));
        await red.cerrar();
        await db.close();
      },
    );

    test(
      'un error de la IA deja la solicitud en cola con el intento',
      () async {
        final db = await abrir();
        final repo = RepositorioSqlite(db);
        final red = RedSimulada(conectada: false);
        final ia = IASimulada(respuesta);
        final servicio = ServicioNotas(repositorio: repo, ia: ia, red: red);
        final p = await repo.guardarPaciente(pacienteEjemplo);
        await servicio.notaTurno(DatosTurno(paciente: p, signos: signos));

        red.conectada = true;
        ia.error = const ErrorIA('Solicitud inválida (HTTP 400).');
        expect(await servicio.cola.procesarPendientes(), 0);
        final s = (await repo.pendientes()).single;
        expect(s.intentos, 1);
        expect(s.ultimoError, 'Solicitud inválida (HTTP 400).');
        expect(await repo.notas(p.id!), isEmpty);
        await red.cerrar();
        await db.close();
      },
    );

    test('apagar y encender varias veces no duplica ni pierde notas', () async {
      final db = await abrir();
      final repo = RepositorioSqlite(db);
      final red = RedSimulada(conectada: false);
      final ia = IASimulada(respuesta);
      final servicio = ServicioNotas(repositorio: repo, ia: ia, red: red);
      await servicio.cola.iniciar();
      final p = await repo.guardarPaciente(pacienteEjemplo);

      for (var i = 0; i < 3; i++) {
        await servicio.notaTurno(DatosTurno(paciente: p, signos: signos));
        red.conectada = true;
        red.conectada = false;
        red.conectada = true;
        await esperarCola(servicio);
        red.conectada = false;
      }

      expect(ia.recibidas, hasLength(3));
      expect(await repo.notas(p.id!), hasLength(3));
      expect(await repo.pendientes(), isEmpty);
      await servicio.cola.detener();
      await red.cerrar();
      await db.close();
    });
  });
}
