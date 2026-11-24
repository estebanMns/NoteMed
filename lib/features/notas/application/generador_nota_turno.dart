/// TSK-11 · HU03: envía los datos del paciente a la IA para que redacte el
/// resumen de turno en formato SBAR.
///
/// Flujo: datos → anonimizar (TSK-29) → IA → restaurar (TSK-31) → revisar
/// siglas y signos vitales (TSK-21 / TSK-23).
library;

import 'package:notemed/features/notas/application/redactor_privado.dart';
import 'package:notemed/features/notas/domain/servicio_ia.dart';
import 'package:notemed/features/validacion/domain/diccionario_medico.dart';
import 'package:notemed/features/notas/domain/revision_nota.dart';
import 'package:notemed/features/notas/domain/turno/datos_turno.dart';
import 'package:notemed/features/notas/domain/prompts/prompt_turno.dart';

class GeneradorNotaTurno {
  GeneradorNotaTurno(
    ServicioIA ia, {
    this.diccionario = DiccionarioMedico.aprobado,
  }) : _redactor = RedactorPrivado(ia);

  final RedactorPrivado _redactor;
  final DiccionarioMedico diccionario;

  /// Genera la nota de turno. Las notas de evolución y traslado usan el
  /// mismo flujo con sus propias instrucciones ([sistema]) y [solicitud].
  Future<RevisionNota> generar(
    DatosTurno d, {
    String? sistema,
    String? solicitud,
  }) async {
    final respuesta = await _redactor.redactar(
      nombre: d.paciente.nombre,
      cedula: d.paciente.cedula,
      cama: d.paciente.cama,
      sistema: sistema ?? instruccionesNotaTurno(diccionario),
      solicitud: solicitud ?? construirSolicitudTurno(d),
    );
    return revisarNota(
      respuesta.texto,
      signos: d.signos,
      diccionario: diccionario,
    );
  }
}
