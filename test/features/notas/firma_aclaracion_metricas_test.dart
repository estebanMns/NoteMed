import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:notemed/core/datos/base_datos_local.dart';
import 'package:notemed/features/metricas/domain/metrica_nota.dart';
import 'package:notemed/features/notas/application/servicio_notas.dart';
import 'package:notemed/features/notas/data/ia/servicio_ia_simulado.dart';
import 'package:notemed/features/notas/domain/firma_enfermera.dart';
import 'package:notemed/features/notas/domain/nota_clinica.dart';
import 'package:notemed/features/notas/domain/prompts/version_prompts.dart';
import 'package:notemed/features/notas/domain/traslado/datos_traslado.dart';
import 'package:notemed/features/pacientes/data/repositorio_sqlite.dart';
import 'package:notemed/features/pacientes/domain/paciente.dart';
import 'package:notemed/features/pacientes/domain/signos_vitales.dart';
import 'package:notemed/features/pacientes/presentation/paciente_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../apoyo/dobles.dart';

final _firma = FirmaEnfermera(
  trazos: const [
    [PuntoFirma.cero, PuntoFirma(4, 4)],
  ],
  tarjetaProfesional: 'TP-1234',
  fecha: DateTime(2026, 11, 20, 7, 5),
);

NotaClinica _borrador({int? id = 1, String texto = 'Paciente estable.'}) =>
    NotaClinica(
      id: id,
      pacienteId: 1,
      tipo: TipoNota.turno,
      texto: texto,
      creada: DateTime(2026, 11, 20, 7),
      versionPrompts: versionPrompts,
    );

const _traslado = DatosTraslado(
  destino: 'Hospitalización tercer piso',
  motivo: 'Mejoría clínica',
  medio: MedioTraslado.camilla,
  acompanante: 'auxiliar de enfermería',
  recibe: 'enfermera jefe de hospitalización',
  estadoConciencia: EstadoConciencia.alerta,
);

void main() {
  group('Nota firmada inmutable', () {
    test('al firmar se calcula un hash que detecta cambios', () {
      final f = _borrador().firmar('Paciente estable.', _firma);
      expect(f.hash, hasLength(64));
      expect(f.integra, isTrue);

      final alterada = NotaClinica(
        id: f.id,
        pacienteId: f.pacienteId,
        tipo: f.tipo,
        texto: 'Paciente inestable.',
        creada: f.creada,
        firma: f.firma,
        versionPrompts: f.versionPrompts,
        hash: f.hash,
      );
      expect(alterada.integra, isFalse);
    });

    test('no se puede firmar dos veces', () {
      final f = _borrador().firmar('x', _firma);
      expect(() => f.firmar('y', _firma), throwsA(isA<NotaFirmadaInmutable>()));
    });

    test(
      'el repositorio en memoria rechaza cambiar una nota firmada',
      () async {
        final repo = RepositorioMemoria();
        final n = await repo.guardarNota(_borrador(id: null));
        final f = await repo.guardarNota(n.firmar('ok', _firma));
        await expectLater(
          repo.guardarNota(f),
          throwsA(isA<NotaFirmadaInmutable>()),
        );
      },
    );

    group('SQLite', () {
      late Database db;
      late RepositorioSqlite repo;
      late Directory dir;

      setUpAll(sqfliteFfiInit);

      setUp(() async {
        dir = await Directory.systemTemp.createTemp('notemed');
        db = await BaseDatosLocal.abrir(
          factory: databaseFactoryFfi,
          ruta: '${dir.path}/n.db',
        );
        repo = RepositorioSqlite(db);
      });

      tearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });

      Future<NotaClinica> firmada() async {
        final p = await repo.guardarPaciente(pacienteEjemplo);
        final n = await repo.guardarNota(
          NotaClinica(
            pacienteId: p.id!,
            tipo: TipoNota.turno,
            texto: 'Borrador',
            creada: DateTime(2026, 11, 20),
            versionPrompts: versionPrompts,
          ),
        );
        return repo.guardarNota(n.firmar('Final', _firma));
      }

      test('guarda y lee hash, versión de prompts y nota aclarada', () async {
        final f = await firmada();
        final leida = (await repo.notas(f.pacienteId)).single;
        expect(leida.hash, f.hash);
        expect(leida.versionPrompts, versionPrompts);
        expect(leida.integra, isTrue);
      });

      test('el repositorio rechaza cambiar una nota firmada', () async {
        final f = await firmada();
        await expectLater(
          repo.guardarNota(f),
          throwsA(isA<NotaFirmadaInmutable>()),
        );
      });

      test('la base rechaza un UPDATE directo a una nota firmada', () async {
        final f = await firmada();
        await expectLater(
          db.update(
            'notas',
            {'texto': 'cambiado'},
            where: 'id = ?',
            whereArgs: [f.id],
          ),
          throwsA(isA<DatabaseException>()),
        );
        expect((await repo.notas(f.pacienteId)).single.texto, 'Final');
      });
    });
  });

  group('ServicioNotas: firmar y aclarar', () {
    late RepositorioMemoria repo;
    late MetricasMemoria metricas;
    late ServicioNotas servicio;
    late Paciente p;
    late RedSimulada red;

    setUp(() async {
      repo = RepositorioMemoria();
      metricas = MetricasMemoria();
      red = RedSimulada();
      servicio = ServicioNotas(
        repositorio: repo,
        ia: const ServicioIASimulado(demora: Duration.zero),
        red: red,
        metricas: metricas,
        ahora: () => DateTime(2026, 11, 20, 8),
      );
      p = await repo.guardarPaciente(pacienteEjemplo);
    });

    tearDown(() => red.cerrar());

    Future<NotaClinica> borrador() async {
      final r = await servicio.notaTurno(await servicio.datosTurno(p));
      return (r as BorradorGuardado).nota;
    }

    test('firmar sin cambios registra aceptación', () async {
      final b = await borrador();
      expect(b.versionPrompts, versionPrompts);
      final f = await servicio.firmar(
        b,
        b.texto,
        _firma,
        tiempoRevision: const Duration(seconds: 42),
      );
      expect(f.firmada, isTrue);
      final m = metricas.lista.single;
      expect(m.notaId, f.id);
      expect(m.aceptadaSinCambios, isTrue);
      expect(m.segundosRevision, 42);
      expect(m.versionPrompts, versionPrompts);
    });

    test('firmar con cambios registra el porcentaje de edición', () async {
      final b = await borrador();
      await servicio.firmar(b, '${b.texto} Paciente tranquilo.', _firma);
      expect(metricas.lista.single.porcentajeEdicion, greaterThan(0));
    });

    test('la aclaración es una nota nueva y la original no cambia', () async {
      final f = await servicio.firmar(await borrador(), 'Original.', _firma);
      final a = await servicio.aclarar(f, 'La TA se tomó a las 7.', _firma);

      expect(a.tipo, TipoNota.aclaracion);
      expect(a.aclaraA, f.id);
      expect(a.integra, isTrue);
      final notas = await repo.notas(p.id!);
      expect(notas, hasLength(2));
      expect(notas.firstWhere((n) => n.id == f.id).texto, 'Original.');
      expect(metricas.lista, hasLength(1), reason: 'la aclaración no es de IA');
    });

    test('no se aclara un borrador', () async {
      expect(
        () => servicio.aclarar(_borrador(), 'x', _firma),
        throwsArgumentError,
      );
    });

    test('nota de evolución y de traslado con la IA simulada', () async {
      await repo.guardarSignos(
        p.id!,
        const SignosVitales(taSistolica: 110, taDiastolica: 70, fc: 88),
      );
      final d = await servicio.datosTurno(p);

      final e = (await servicio.notaEvolucion(d) as BorradorGuardado).nota;
      expect(e.tipo, TipoNota.evolucion);
      expect(e.texto, contains('TA 110/70 mmHg'));
      expect(ServicioNotas.revisor(e)(e.texto).mensajes, isEmpty);

      final t =
          (await servicio.notaTraslado(d, _traslado) as BorradorGuardado).nota;
      expect(t.tipo, TipoNota.traslado);
      expect(t.texto, startsWith('Traslado: Paciente María Fernanda Gómez'));
      expect(t.texto, contains('Hospitalización tercer piso'));
      expect(t.texto, contains('Camilla, acompañado por auxiliar'));
      expect(ServicioNotas.revisor(t)(t.texto).mensajes, isEmpty);
    });

    test(
      'un traslado sin red queda en la cola y se genera al volver',
      () async {
        final ia = IASimulada((_, _) => 'Traslado: listo.');
        red.conectada = false;
        final s = ServicioNotas(repositorio: repo, ia: ia, red: red);
        final r = await s.notaTraslado(await s.datosTurno(p), _traslado);
        expect(r, isA<SolicitudEnCola>());

        red.conectada = true;
        expect(await s.cola.procesarPendientes(), 1);
        final nota = (await repo.notas(p.id!)).single;
        expect(nota.tipo, TipoNota.traslado);
        expect(
          ia.recibidas.single.usuario,
          contains('Destino: Hospitalización'),
        );
      },
    );
  });

  group('Métricas', () {
    test('porcentaje de edición por palabras', () {
      expect(porcentajeEdicionEntre('a b c d', 'a b c d'), 0);
      expect(porcentajeEdicionEntre('a b c d', 'w x y z'), 100);
      expect(
        porcentajeEdicionEntre('a b c d e f g h i j', 'a b c d e f g h i X'),
        10,
      );
      expect(porcentajeEdicionEntre('', ''), 0);
    });

    test('resumen y CSV', () {
      MetricaNota m(double edicion, int? seg) => MetricaNota(
        notaId: 1,
        tipo: TipoNota.turno,
        generada: DateTime(2026),
        firmada: DateTime(2026),
        palabrasBorrador: 10,
        porcentajeEdicion: edicion,
        segundosRevision: seg,
      );
      final r = ResumenMetricas([m(0, 60), m(20, null), m(10, 120)]);
      expect(r.tasaAceptacion, closeTo(33.3, 0.1));
      expect(r.edicionPromedio, 10);
      expect(r.segundosRevisionPromedio, 90);
      expect(r.porTipo, {TipoNota.turno: 3});
      expect(r.csv().split('\n').first, startsWith('nota_id,tipo,'));
      expect(r.csv().split('\n'), hasLength(4));
    });
  });

  testWidgets('desde la pantalla del paciente: traslado, firma y aclaración', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final repo = RepositorioMemoria();
    final metricas = MetricasMemoria();
    final p = await repo.guardarPaciente(pacienteEjemplo);
    await tester.pumpWidget(
      conDependencias(
        repo: repo,
        ia: const ServicioIASimulado(demora: Duration.zero),
        metricas: metricas,
        hijo: PacienteScreen(paciente: p),
      ),
    );
    await tester.pumpAndSettle();

    // Traslado
    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu-traslado')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tras-destino')), 'Piso 3');
    await tester.enterText(find.byKey(const Key('tras-motivo')), 'Mejoría');
    await tester.enterText(
      find.byKey(const Key('tras-acompanante')),
      'auxiliar de enfermería',
    );
    await tester.enterText(
      find.byKey(const Key('tras-recibe')),
      'jefe de piso',
    );
    await tester.tap(find.byKey(const Key('tras-generar')));
    await tester.pumpAndSettle();

    // Borrador → firma
    final texto = tester.widget<TextField>(
      find.byKey(const Key('borrador-texto')),
    );
    expect(texto.controller!.text, contains('Piso 3'));
    await tester.tap(find.byKey(const Key('borrador-firmar')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('firma-lienzo')),
      const Offset(100, 20),
    );
    await tester.enterText(find.byKey(const Key('firma-tarjeta')), 'TP-1234');
    await tester.tap(find.byKey(const Key('firma-aceptar')));
    await tester.pumpAndSettle();

    final firmada = (await repo.notas(p.id!)).single;
    expect(firmada.tipo, TipoNota.traslado);
    expect(firmada.integra, isTrue);
    expect(metricas.lista.single.aceptadaSinCambios, isTrue);

    // Abrir la nota firmada → aclaración
    await tester.scrollUntilVisible(
      find.byKey(Key('nota-${firmada.id}')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(Key('nota-${firmada.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Contenido sin cambios desde la firma'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nota-aclarar')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('borrador-texto')),
      'El destino correcto es el piso 4.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('borrador-firmar')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('firma-lienzo')),
      const Offset(100, 20),
    );
    await tester.enterText(find.byKey(const Key('firma-tarjeta')), 'TP-1234');
    await tester.tap(find.byKey(const Key('firma-aceptar')));
    await tester.pumpAndSettle();

    final notas = await repo.notas(p.id!);
    expect(notas, hasLength(2));
    final aclaracion = notas.firstWhere((n) => n.tipo == TipoNota.aclaracion);
    expect(aclaracion.aclaraA, firmada.id);
    expect(notas.firstWhere((n) => n.id == firmada.id).texto, firmada.texto);
  });
}
