/// TSK-25 · HU07: implementación de [RepositorioPacientes] sobre la base
/// SQLite del celular (ver `BaseDatosLocal`).
library;

import 'dart:convert';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:notemed/features/notas/domain/firma_enfermera.dart';
import 'package:notemed/features/notas/domain/nota_clinica.dart';
import 'package:notemed/features/pacientes/domain/infusion.dart';
import 'package:notemed/features/pacientes/domain/paciente.dart';
import 'package:notemed/features/pacientes/domain/signos_vitales.dart';
import 'package:notemed/features/pacientes/domain/procedimiento_invasivo.dart';
import 'package:notemed/features/valoracion/domain/braden/braden_escala.dart';
import 'package:notemed/features/valoracion/domain/braden/braden_mapa.dart';
import 'package:notemed/features/valoracion/domain/downton/downton_escala.dart';
import 'package:notemed/features/valoracion/domain/prom/evaluacion_prom.dart';
import 'package:notemed/features/pacientes/domain/repositorio_pacientes.dart';
import 'package:notemed/features/sincronizacion/domain/solicitud_pendiente.dart';

class RepositorioSqlite implements RepositorioPacientes {
  RepositorioSqlite(this.db);

  final Database db;

  static Map<String, Object?> _json(Object? texto) =>
      Map<String, Object?>.from(jsonDecode(texto! as String) as Map);

  @override
  Future<Paciente> guardarPaciente(Paciente paciente) async {
    final fila = paciente.toMap()..remove('id');
    try {
      if (paciente.id == null) {
        return paciente.conId(await db.insert('pacientes', fila));
      }
      await db.update(
        'pacientes',
        fila,
        where: 'id = ?',
        whereArgs: [paciente.id],
      );
      return paciente;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw PacienteDuplicado(paciente.cedula);
      }
      rethrow;
    }
  }

  @override
  Future<List<Paciente>> pacientes() async => [
    for (final f in await db.query('pacientes', orderBy: 'cama, nombre'))
      Paciente.fromMap(f),
  ];

  @override
  Future<Paciente?> paciente(int id) async {
    final f = await db.query('pacientes', where: 'id = ?', whereArgs: [id]);
    return f.isEmpty ? null : Paciente.fromMap(f.first);
  }

  @override
  Future<void> eliminarPaciente(int id) =>
      db.delete('pacientes', where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> guardarSignos(int pacienteId, SignosVitales s) =>
      db.insert('signos_vitales', {
        'paciente_id': pacienteId,
        'datos': jsonEncode(s.toMap()),
        'actualizado': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<SignosVitales> signos(int pacienteId) async {
    final f = await db.query(
      'signos_vitales',
      where: 'paciente_id = ?',
      whereArgs: [pacienteId],
    );
    return f.isEmpty
        ? const SignosVitales()
        : SignosVitales.fromMap(_json(f.first['datos']));
  }

  @override
  Future<Infusion> agregarInfusion(int pacienteId, Infusion i) async {
    final id = await db.insert('infusiones', {
      'paciente_id': pacienteId,
      'datos': jsonEncode(i.toMap()..remove('id')),
    });
    return i.conId(id);
  }

  @override
  Future<void> eliminarInfusion(int id) =>
      db.delete('infusiones', where: 'id = ?', whereArgs: [id]);

  @override
  Future<List<Infusion>> infusiones(int pacienteId) async => [
    for (final f in await db.query(
      'infusiones',
      where: 'paciente_id = ?',
      whereArgs: [pacienteId],
      orderBy: 'id',
    ))
      Infusion.fromMap({..._json(f['datos']), 'id': f['id']}),
  ];

  @override
  Future<ProcedimientoInvasivo> agregarProcedimiento(
    int pacienteId,
    ProcedimientoInvasivo p,
  ) async {
    final id = await db.insert('procedimientos', {
      'paciente_id': pacienteId,
      'datos': jsonEncode(p.toMap()..remove('id')),
    });
    return p.conId(id);
  }

  @override
  Future<List<ProcedimientoInvasivo>> procedimientos(int pacienteId) async => [
    for (final f in await db.query(
      'procedimientos',
      where: 'paciente_id = ?',
      whereArgs: [pacienteId],
      orderBy: 'id',
    ))
      ProcedimientoInvasivo.fromMap({..._json(f['datos']), 'id': f['id']}),
  ];

  Future<void> _guardarEvaluacion(
    int pacienteId,
    String escala,
    Map<String, Object?> datos,
  ) => db.insert('evaluaciones', {
    'paciente_id': pacienteId,
    'escala': escala,
    'datos': jsonEncode(datos),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<Map<String, Object?>?> _evaluacion(
    int pacienteId,
    String escala,
  ) async {
    final f = await db.query(
      'evaluaciones',
      where: 'paciente_id = ? AND escala = ?',
      whereArgs: [pacienteId, escala],
    );
    return f.isEmpty ? null : _json(f.first['datos']);
  }

  @override
  Future<void> guardarDownton(int pacienteId, EvaluacionDownton e) =>
      _guardarEvaluacion(pacienteId, 'downton', e.toMap());

  @override
  Future<EvaluacionDownton?> downton(int pacienteId) async {
    final m = await _evaluacion(pacienteId, 'downton');
    return m == null ? null : EvaluacionDownton.fromMap(m);
  }

  @override
  Future<void> guardarBraden(int pacienteId, EvaluacionBraden e) =>
      _guardarEvaluacion(pacienteId, 'braden', bradenAMapa(e));

  @override
  Future<EvaluacionBraden?> braden(int pacienteId) async {
    final m = await _evaluacion(pacienteId, 'braden');
    return m == null ? null : bradenDeMapa(m);
  }

  @override
  Future<void> guardarProm(int pacienteId, EvaluacionProm e) =>
      _guardarEvaluacion(pacienteId, 'prom', e.toMap());

  @override
  Future<EvaluacionProm?> prom(int pacienteId) async {
    final m = await _evaluacion(pacienteId, 'prom');
    return m == null ? null : EvaluacionProm.fromMap(m);
  }

  @override
  Future<NotaClinica> guardarNota(NotaClinica n) async {
    final fila = {
      'paciente_id': n.pacienteId,
      'tipo': n.tipo.name,
      'texto': n.texto,
      'creada': n.creada.toIso8601String(),
      'referencia': jsonEncode(n.referencia),
      'firma': n.firma == null ? null : jsonEncode(n.firma!.toMap()),
      'version_prompts': n.versionPrompts,
      'aclara_a': n.aclaraA,
      'hash': n.hash,
    };
    if (n.id == null) return n.conId(await db.insert('notas', fila));
    final actual = await db.query(
      'notas',
      columns: ['firma'],
      where: 'id = ?',
      whereArgs: [n.id],
    );
    if (actual.isNotEmpty && actual.first['firma'] != null) {
      throw NotaFirmadaInmutable(n.id);
    }
    await db.update('notas', fila, where: 'id = ?', whereArgs: [n.id]);
    return n;
  }

  static NotaClinica _nota(Map<String, Object?> f) => NotaClinica(
    id: f['id']! as int,
    pacienteId: f['paciente_id']! as int,
    tipo: TipoNota.values.byName(f['tipo']! as String),
    texto: f['texto']! as String,
    creada: DateTime.parse(f['creada']! as String),
    referencia: _json(f['referencia']),
    firma: f['firma'] == null
        ? null
        : FirmaEnfermera.fromMap(_json(f['firma'])),
    versionPrompts: f['version_prompts'] as String?,
    aclaraA: f['aclara_a'] as int?,
    hash: f['hash'] as String?,
  );

  @override
  Future<List<NotaClinica>> notas(int pacienteId) async => [
    for (final f in await db.query(
      'notas',
      where: 'paciente_id = ?',
      whereArgs: [pacienteId],
      orderBy: 'creada DESC, id DESC',
    ))
      _nota(f),
  ];

  @override
  Future<SolicitudPendiente> encolar(SolicitudPendiente s) async {
    final id = await db.insert('cola_pendientes', {
      'paciente_id': s.pacienteId,
      'tipo': s.tipo.name,
      'datos': jsonEncode(s.datos),
      'creada': s.creada.toIso8601String(),
      'intentos': s.intentos,
      'ultimo_error': s.ultimoError,
    });
    return s.conId(id);
  }

  @override
  Future<List<SolicitudPendiente>> pendientes() async => [
    for (final f in await db.query('cola_pendientes', orderBy: 'id'))
      SolicitudPendiente(
        id: f['id']! as int,
        pacienteId: f['paciente_id']! as int,
        tipo: TipoNota.values.byName(f['tipo']! as String),
        datos: _json(f['datos']),
        creada: DateTime.parse(f['creada']! as String),
        intentos: f['intentos']! as int,
        ultimoError: f['ultimo_error'] as String?,
      ),
  ];

  @override
  Future<void> eliminarPendiente(int id) =>
      db.delete('cola_pendientes', where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> registrarIntento(int id, String error) => db.rawUpdate(
    'UPDATE cola_pendientes SET intentos = intentos + 1, ultimo_error = ? '
    'WHERE id = ?',
    [error, id],
  );
}
