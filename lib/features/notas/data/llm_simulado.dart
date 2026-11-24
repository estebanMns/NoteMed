/// Implementación simulada de [LlmGateway] para desarrollo y pruebas con datos
/// sintéticos (PDF §3.3, fase 3). Es determinista: no llama a ningún servicio
/// externo. La implementación real (API del proveedor) irá en otro archivo de
/// esta misma capa.
library;

import '../domain/llm_gateway.dart';

class LlmSimulado implements LlmGateway {
  const LlmSimulado();

  @override
  Future<String> generar({
    required String instruccion,
    required String contexto,
  }) async {
    final lineas = contexto
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final cuerpo = lineas.map((l) => '- $l').join('\n');
    return 'Borrador generado a partir de los datos registrados:\n$cuerpo';
  }
}
