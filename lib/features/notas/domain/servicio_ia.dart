/// TSK-11 · HU03: contrato del servicio de IA que redacta las notas.
///
/// Implementaciones (capa de datos): `ServicioIASimulado` (por defecto, sin
/// internet), `ServicioIARemoto` (backend del proyecto) y
/// `ClaudeServicioIA` (solo para demostraciones).
library;

abstract interface class ServicioIA {
  /// `true` si la IA corre en el celular y no necesita red. Las solicitudes
  /// a una IA remota se guardan en la cola cuando no hay conexión.
  bool get funcionaSinRed;

  /// Envía [sistema] (instrucciones) y [usuario] (datos ya anonimizados) y
  /// devuelve el texto redactado. Lanza [ErrorIA] si falla.
  Future<String> generar({required String sistema, required String usuario});
}

class ErrorIA implements Exception {
  const ErrorIA(this.mensaje, {this.sinConexion = false, this.codigo});

  final String mensaje;

  /// `true` cuando no hubo red: la solicitud se puede guardar y reintentar.
  final bool sinConexion;

  /// Código HTTP, si lo hubo.
  final int? codigo;

  @override
  String toString() => 'ErrorIA: $mensaje';
}
