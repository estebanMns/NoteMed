/// TSK-11 / TSK-29 / TSK-31: envía una solicitud a la IA sin datos
/// personales y restaura los datos reales en la respuesta.
library;

import '../privacidad/protector_privacidad.dart';
import 'servicio_ia.dart';

class RespuestaPrivada {
  const RespuestaPrivada({required this.enviado, required this.texto});

  /// Lo que se envió a la IA (anonimizado). Sirve para auditoría y pruebas.
  final String enviado;

  /// Respuesta con los datos reales, para mostrar en pantalla.
  final String texto;
}

class RedactorPrivado {
  const RedactorPrivado(this.ia);

  final ServicioIA ia;

  /// Lanza [DatosPersonalesExpuestos] sin llamar a la IA si no logra
  /// ocultar todos los datos, o [ErrorIA] si la IA falla.
  Future<RespuestaPrivada> redactar({
    required String nombre,
    required String cedula,
    required String cama,
    required String sistema,
    required String solicitud,
  }) async {
    final protector = ProtectorPrivacidad(
      nombre: nombre,
      cedula: cedula,
      cama: cama,
    );
    final enviado = protector.ocultar(solicitud);
    final respuesta = await ia.generar(sistema: sistema, usuario: enviado);
    return RespuestaPrivada(
      enviado: enviado,
      texto: protector.restaurar(respuesta),
    );
  }
}
