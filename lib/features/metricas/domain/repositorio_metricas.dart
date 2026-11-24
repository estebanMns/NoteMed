/// Acceso a las métricas de validación guardadas en el celular.
library;

import 'package:notemed/features/metricas/domain/metrica_nota.dart';

abstract interface class RepositorioMetricas {
  Future<MetricaNota> registrar(MetricaNota m);

  /// De la más antigua a la más reciente.
  Future<List<MetricaNota>> metricas();
}
