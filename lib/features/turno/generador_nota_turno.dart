/// TSK-11 · HU03: envía los datos del paciente a la IA para que redacte el
/// resumen de turno en formato SBAR.
///
/// Flujo: datos → anonimizar (TSK-29) → IA → restaurar (TSK-31) → revisar
/// siglas y signos vitales (TSK-21 / TSK-23).
library;

import '../../core/ia/redactor_privado.dart';
import '../../core/ia/servicio_ia.dart';
import '../../core/validacion/diccionario_medico.dart';
import '../nota/revision_nota.dart';
import '../paciente/infusion.dart';
import '../paciente/paciente.dart';
import '../paciente/signos_vitales.dart';
import '../procedimientos/procedimiento_invasivo.dart';
import '../riesgos/braden/braden_escala.dart';
import '../riesgos/braden/braden_mapa.dart';
import '../riesgos/downton/downton_escala.dart';

/// Todo lo que se registra del paciente durante el turno.
class DatosTurno {
  const DatosTurno({
    required this.paciente,
    this.signos = const SignosVitales(),
    this.infusiones = const [],
    this.downton,
    this.braden,
    this.procedimientos = const [],
    this.observaciones = '',
  });

  final Paciente paciente;
  final SignosVitales signos;
  final List<Infusion> infusiones;
  final EvaluacionDownton? downton;
  final EvaluacionBraden? braden;
  final List<ProcedimientoInvasivo> procedimientos;
  final String observaciones;

  Map<String, Object?> toMap() => {
    'paciente': paciente.toMap(),
    'signos': signos.toMap(),
    'infusiones': [for (final i in infusiones) i.toMap()],
    'downton': downton?.toMap(),
    'braden': braden == null ? null : bradenAMapa(braden!),
    'procedimientos': [for (final p in procedimientos) p.toMap()],
    'observaciones': observaciones,
  };

  factory DatosTurno.fromMap(Map<String, Object?> m) => DatosTurno(
    paciente: Paciente.fromMap(_mapa(m['paciente'])),
    signos: SignosVitales.fromMap(_mapa(m['signos'])),
    infusiones: [
      for (final i in m['infusiones'] as List? ?? const [])
        Infusion.fromMap(_mapa(i)),
    ],
    downton: m['downton'] == null
        ? null
        : EvaluacionDownton.fromMap(_mapa(m['downton'])),
    braden: m['braden'] == null ? null : bradenDeMapa(_mapa(m['braden'])),
    procedimientos: [
      for (final p in m['procedimientos'] as List? ?? const [])
        ProcedimientoInvasivo.fromMap(_mapa(p)),
    ],
    observaciones: m['observaciones'] as String? ?? '',
  );

  static Map<String, Object?> _mapa(Object? o) =>
      Map<String, Object?>.from(o! as Map);
}

String _lista(Iterable<String> items) =>
    items.isEmpty ? 'Ninguno registrado' : items.map((i) => '\n- $i').join();

/// Texto con los datos reales. [GeneradorNotaTurno] lo anonimiza antes de
/// enviarlo.
String construirSolicitudTurno(DatosTurno d) {
  final braden = d.braden;
  final obs = d.observaciones.trim();
  return [
    d.paciente.toTexto(),
    'Signos vitales: ${d.signos.toTexto()}',
    'Infusiones: ${_lista(d.infusiones.map((i) => i.toTexto()))}',
    d.downton?.toTexto() ?? 'Escala de Downton: No registrada',
    braden?.total == null
        ? 'Escala de Braden: No registrada'
        : 'Escala de Braden: ${braden!.total} puntos (${braden.nivel!.etiqueta})',
    'Procedimientos invasivos: ${_lista(d.procedimientos.map((p) => p.toTexto()))}',
    'Observaciones de enfermería: ${obs.isEmpty ? 'Ninguna' : obs}',
  ].join('\n');
}

String instruccionesNotaTurno(DiccionarioMedico diccionario) =>
    '''
Eres un asistente de redacción para el personal de enfermería de un hospital en Colombia. Redactas la nota de entrega de turno en formato SBAR a partir de los datos que te envían.

Reglas:
1. Usa únicamente los datos de la solicitud. No inventes valores, diagnósticos, horas, medicamentos, dosis ni procedimientos. Si falta un dato, escribe "No registrado".
2. Copia los signos vitales exactamente con el mismo número y la misma sigla (TA, FC, FR, SpO2, T). No los redondees ni los conviertas.
3. Los códigos PAC-###, ID-### y CAMA-### reemplazan datos personales. Cópialos tal cual y no intentes deducir a quién corresponden.
4. Usa solo estas siglas aprobadas: ${diccionario.comoListaTexto()}. Cualquier otro término escríbelo completo.
5. Tono objetivo, en tercera persona y en español de Colombia, sin juicios de valor (Ley 911 de 2004).
6. Responde solo con cuatro párrafos, cada uno en su propia línea y empezando exactamente por "[S] Situación:", "[B] Antecedentes:", "[A] Evaluación:" y "[R] Recomendación:". Sin títulos ni texto adicional.''';

class GeneradorNotaTurno {
  GeneradorNotaTurno(
    ServicioIA ia, {
    this.diccionario = DiccionarioMedico.aprobado,
  }) : _redactor = RedactorPrivado(ia);

  final RedactorPrivado _redactor;
  final DiccionarioMedico diccionario;

  Future<RevisionNota> generar(DatosTurno d) async {
    final respuesta = await _redactor.redactar(
      nombre: d.paciente.nombre,
      cedula: d.paciente.cedula,
      cama: d.paciente.cama,
      sistema: instruccionesNotaTurno(diccionario),
      solicitud: construirSolicitudTurno(d),
    );
    return revisarNota(
      respuesta.texto,
      signos: d.signos,
      diccionario: diccionario,
    );
  }
}
