/// TSK-25 · HU07: base de datos interna del celular (SQLite) para trabajar
/// sin internet. Los datos del paciente nunca salen del dispositivo sin
/// anonimizar (HU08).
library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class BaseDatosLocal {
  BaseDatosLocal._();

  static const int version = 1;
  static const String nombreArchivo = 'notemed.db';

  /// Abre (o crea) la base. En las pruebas se pasa [factory] de
  /// `sqflite_common_ffi` y una [ruta] temporal.
  static Future<Database> abrir({
    DatabaseFactory? factory,
    String? ruta,
  }) async {
    final f = factory ?? databaseFactory;
    final destino = ruta ?? p.join(await f.getDatabasesPath(), nombreArchivo);
    return f.openDatabase(
      destino,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => _crear(db),
      ),
    );
  }

  static Future<void> _crear(Database db) async {
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
