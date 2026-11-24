/// Métricas de validación en la base local (tabla `metricas`).
library;

import 'package:sqflite_common/sqlite_api.dart';

import 'package:notemed/features/metricas/domain/metrica_nota.dart';
import 'package:notemed/features/metricas/domain/repositorio_metricas.dart';

class RepositorioMetricasSqlite implements RepositorioMetricas {
  RepositorioMetricasSqlite(this.db);

  final Database db;

  @override
  Future<MetricaNota> registrar(MetricaNota m) async {
    final id = await db.insert('metricas', m.toMap()..remove('id'));
    return MetricaNota.fromMap({...m.toMap(), 'id': id});
  }

  @override
  Future<List<MetricaNota>> metricas() async => [
    for (final f in await db.query('metricas', orderBy: 'id'))
      MetricaNota.fromMap(f),
  ];
}
