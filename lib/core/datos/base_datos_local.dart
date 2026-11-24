/// TSK-25 · HU07: base de datos interna del celular (SQLite) para trabajar
/// sin internet. En el celular el archivo está cifrado con SQLCipher y la
/// clave vive en el almacenamiento seguro del sistema (Ley 1581 de 2012).
/// Los datos del paciente nunca salen del dispositivo sin anonimizar (HU08).
library;

import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;

import 'package:notemed/core/datos/clave_base_datos.dart';

class BaseDatosLocal {
  BaseDatosLocal._();

  /// 1: esquema inicial (HU07). 2: nota firmada inmutable, nota aclaratoria
  /// y métricas de validación.
  static const int version = 2;
  static const String nombreArchivo = 'notemed_cifrada.db';

  /// Archivo sin cifrar de versiones anteriores. Solo tuvo datos sintéticos.
  static const String nombreArchivoAnterior = 'notemed.db';

  /// Abre (o crea) la base cifrada del celular.
  static Future<Database> abrirCifrada({ClaveBaseDatos? clave}) async {
    final f = cipher.databaseFactory;
    final dir = await f.getDatabasesPath();
    // No se deja en el celular una copia sin cifrar.
    await f.deleteDatabase(p.join(dir, nombreArchivoAnterior));
    final password = await (clave ?? ClaveBaseDatos()).obtener();
    return f.openDatabase(
      p.join(dir, nombreArchivo),
      options: cipher.SqlCipherOpenDatabaseOptions(
        version: version,
        password: password,
        onConfigure: _configurar,
        onCreate: (db, _) => _crear(db),
        onUpgrade: _migrar,
      ),
    );
  }

  /// Abre una base sin cifrar. Solo para pruebas con `sqflite_common_ffi`.
  static Future<Database> abrir({
    required DatabaseFactory factory,
    required String ruta,
  }) => factory.openDatabase(
    ruta,
    options: OpenDatabaseOptions(
      version: version,
      onConfigure: _configurar,
      onCreate: (db, _) => _crear(db),
    ),
  );

  static Future<void> _configurar(Database db) =>
      db.execute('PRAGMA foreign_keys = ON');

  static Future<void> _crear(Database db) async {
    await _crearV1(db);
    await _migrar(db, 1, version);
  }

  static Future<void> _migrar(Database db, int desde, int hasta) async {
    if (desde < 2 && hasta >= 2) await _migrarA2(db);
  }

  static Future<void> _migrarA2(Database db) async {
    final b = db.batch()
      ..execute('ALTER TABLE notas ADD COLUMN version_prompts TEXT')
      ..execute(
        'ALTER TABLE notas ADD COLUMN aclara_a INTEGER REFERENCES notas(id)',
      )
      ..execute('ALTER TABLE notas ADD COLUMN hash TEXT')
      // Defensa adicional: la base rechaza cambios a una nota firmada aunque
      // algún código se salte el repositorio.
      ..execute('''
        CREATE TRIGGER notas_firmadas_inmutables
        BEFORE UPDATE ON notas
        WHEN OLD.firma IS NOT NULL
        BEGIN
          SELECT RAISE(ABORT, 'nota firmada inmutable');
        END''')
      // Sin llave foránea: las métricas no tienen datos del paciente y deben
      // conservarse para el informe aunque se borre el paciente del celular.
      ..execute('''
        CREATE TABLE metricas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nota_id INTEGER NOT NULL,
          tipo TEXT NOT NULL,
          generada TEXT NOT NULL,
          firmada TEXT NOT NULL,
          palabras_borrador INTEGER NOT NULL,
          porcentaje_edicion REAL NOT NULL,
          segundos_revision INTEGER,
          version_prompts TEXT
        )''');
    await b.commit(noResult: true);
  }

  static Future<void> _crearV1(Database db) async {
    const fk = 'REFERENCES pacientes(id) ON DELETE CASCADE';
    final b = db.batch()
      ..execute('''
        CREATE TABLE pacientes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL,
          cedula TEXT NOT NULL UNIQUE,
          edad INTEGER NOT NULL,
          cama TEXT NOT NULL
        )''')
      ..execute('''
        CREATE TABLE signos_vitales (
          paciente_id INTEGER PRIMARY KEY $fk,
          datos TEXT NOT NULL,
          actualizado TEXT NOT NULL
        )''')
      ..execute('''
        CREATE TABLE infusiones (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          paciente_id INTEGER NOT NULL $fk,
          datos TEXT NOT NULL
        )''')
      ..execute('''
        CREATE TABLE procedimientos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          paciente_id INTEGER NOT NULL $fk,
          datos TEXT NOT NULL
        )''')
      ..execute('''
        CREATE TABLE evaluaciones (
          paciente_id INTEGER NOT NULL $fk,
          escala TEXT NOT NULL,
          datos TEXT NOT NULL,
          PRIMARY KEY (paciente_id, escala)
        )''')
      ..execute('''
        CREATE TABLE notas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          paciente_id INTEGER NOT NULL $fk,
          tipo TEXT NOT NULL,
          texto TEXT NOT NULL,
          creada TEXT NOT NULL,
          referencia TEXT NOT NULL,
          firma TEXT
        )''')
      ..execute('''
        CREATE TABLE cola_pendientes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          paciente_id INTEGER NOT NULL $fk,
          tipo TEXT NOT NULL,
          datos TEXT NOT NULL,
          creada TEXT NOT NULL,
          intentos INTEGER NOT NULL DEFAULT 0,
          ultimo_error TEXT
        )''');
    await b.commit(noResult: true);
  }
}
