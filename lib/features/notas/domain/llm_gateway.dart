/// Puerto hacia el modelo de lenguaje. El dominio y los casos de uso solo
/// conocen esta interfaz; el proveedor concreto (API HTTP, modelo local o un
/// simulador) vive en la capa de datos. Así se puede cambiar de proveedor sin
/// tocar la lógica clínica (Arquitectura Limpia, PDF §2.2.7).
library;

abstract interface class LlmGateway {
  /// [instruccion] es la plantilla de prompt del tipo de nota.
  /// [contexto] son los datos YA seudonimizados. Nunca llegan nombres reales.
  Future<String> generar({
    required String instruccion,
    required String contexto,
  });
}
