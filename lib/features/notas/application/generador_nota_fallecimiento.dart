/// TSK-15 · HU04: instrucciones para que la IA genere notas de fallecimiento
/// objetivas, sin inventar datos, y una validación posterior de la respuesta.
library;

import 'package:notemed/features/notas/application/redactor_privado.dart';
import 'package:notemed/features/notas/domain/servicio_ia.dart';
import 'package:notemed/features/validacion/domain/diccionario_medico.dart';
import 'package:notemed/features/notas/domain/revision_nota.dart';
import 'package:notemed/features/pacientes/domain/paciente.dart';
import 'package:notemed/features/pacientes/domain/signos_vitales.dart';
import 'package:notemed/features/pacientes/domain/procedimiento_invasivo.dart';
import 'package:notemed/features/notas/domain/fallecimiento/datos_fallecimiento.dart';
import 'package:notemed/features/notas/domain/prompts/prompt_fallecimiento.dart';

class RevisionNotaFallecimiento {
  const RevisionNotaFallecimiento(this.revision, this.problemas);

  final RevisionNota revision;

  /// Datos que la IA agregó por su cuenta. Si hay alguno, no se puede firmar.
  final List<String> problemas;

  String get texto => revision.texto;
  bool get bloqueaFirma => revision.bloqueaFirma || problemas.isNotEmpty;
  List<String> get mensajes => [...problemas, ...revision.mensajes];
}

class GeneradorNotaFallecimiento {
  GeneradorNotaFallecimiento(
    ServicioIA ia, {
    this.diccionario = DiccionarioMedico.aprobado,
  }) : _redactor = RedactorPrivado(ia);

  final RedactorPrivado _redactor;
  final DiccionarioMedico diccionario;

  Future<RevisionNotaFallecimiento> generar(
    Paciente paciente,
    DatosFallecimiento datos, {
    List<ProcedimientoInvasivo> procedimientos = const [],
  }) async {
    final solicitud = construirSolicitudFallecimiento(
      paciente,
      datos,
      procedimientos: procedimientos,
    );
    final respuesta = await _redactor.redactar(
      nombre: paciente.nombre,
      cedula: paciente.cedula,
      cama: paciente.cama,
      sistema: instruccionesNotaFallecimiento,
      solicitud: solicitud,
    );
    return RevisionNotaFallecimiento(
      // Ningún signo vital registrado: cualquier valor sería inventado.
      revisarNota(
        respuesta.texto,
        signos: const SignosVitales(),
        diccionario: diccionario,
      ),
      const ValidadorNotaFallecimiento().problemas(respuesta.texto, solicitud),
    );
  }
}
