/// TSK-11 · HU03: contrato del servicio de IA que redacta las notas. La app
/// usa [ClaudeServicioIA]; las pruebas usan una IA simulada.
library;

abstract interface class ServicioIA {
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

/// Se usa cuando la app se compila sin clave de la API: avisa en lugar de
/// fallar al iniciar.
class ServicioIANoConfigurado implements ServicioIA {
  const ServicioIANoConfigurado();

  @override
  Future<String> generar({required String sistema, required String usuario}) =>
      Future.error(
        const ErrorIA(
          'La IA no está configurada. Compile la app con '
          '--dart-define=ANTHROPIC_API_KEY=<clave>.',
        ),
      );
}
