/// TSK-15 · HU04: instrucciones para que la IA genere notas de fallecimiento
/// objetivas, sin inventar datos, y una validación posterior de la respuesta.
library;

import '../../core/ia/redactor_privado.dart';
import '../../core/ia/servicio_ia.dart';
import '../../core/validacion/diccionario_medico.dart';
import '../nota/revision_nota.dart';
import '../paciente/paciente.dart';
import '../paciente/signos_vitales.dart';
import '../procedimientos/procedimiento_invasivo.dart';

const List<String> signosDeMuerte = [
  'Ausencia de pulso central',
  'Ausencia de ruidos cardiacos',
  'Ausencia de respiración espontánea',
  'Pupilas midriáticas sin respuesta a la luz',
  'Ausencia de respuesta a estímulos',
];

const List<String> cuidadosPostMortem = [
  'Retiro de dispositivos invasivos',
  'Higiene y arreglo del cuerpo',
  'Identificación del cuerpo con manilla y rótulo',
  'Inventario y entrega de pertenencias',
  'Traslado a la morgue',
];

class DatosFallecimiento {
  const DatosFallecimiento({
    required this.fechaHora,
    required this.quienCertifica,
    this.signosObservados = const [],
    this.reanimacion = false,
    this.duracionReanimacionMin,
    this.cuidadosRealizados = const [],
    this.entregaA,
    this.observaciones = '',
  });

  final DateTime fechaHora;

  /// Cargo de quien certifica, por ejemplo "médico de turno".
  final String quienCertifica;
  final List<String> signosObservados;
  final bool reanimacion;
  final int? duracionReanimacionMin;
  final List<String> cuidadosRealizados;

  /// Parentesco o rol a quien se informa o se entrega el cuerpo (sin nombres).
  final String? entregaA;
  final String observaciones;

  List<String> validar() => [
    if (quienCertifica.trim().isEmpty)
      'Indique el cargo de quien certifica el fallecimiento',
    if (signosObservados.isEmpty) 'Marque al menos un signo observado',
    if (reanimacion &&
        (duracionReanimacionMin == null || duracionReanimacionMin! <= 0))
      'Indique la duración de la reanimación en minutos',
  ];

  Map<String, Object?> toMap() => {
    'fechaHora': fechaHora.toIso8601String(),
    'quienCertifica': quienCertifica,
    'signosObservados': signosObservados,
    'reanimacion': reanimacion,
    'duracionReanimacionMin': duracionReanimacionMin,
    'cuidadosRealizados': cuidadosRealizados,
    'entregaA': entregaA,
    'observaciones': observaciones,
  };

  factory DatosFallecimiento.fromMap(Map<String, Object?> m) =>
      DatosFallecimiento(
        fechaHora: DateTime.parse(m['fechaHora']! as String),
        quienCertifica: m['quienCertifica']! as String,
        signosObservados: List<String>.from(m['signosObservados'] as List),
        reanimacion: m['reanimacion'] as bool? ?? false,
        duracionReanimacionMin: m['duracionReanimacionMin'] as int?,
        cuidadosRealizados: List<String>.from(m['cuidadosRealizados'] as List),
        entregaA: m['entregaA'] as String?,
        observaciones: m['observaciones'] as String? ?? '',
      );
}

const String instruccionesNotaFallecimiento = '''
Eres un asistente de redacción para el personal de enfermería de un hospital en Colombia. Redactas la nota de enfermería de fallecimiento a partir de los datos que te envían.

Reglas obligatorias:
1. Usa únicamente los datos de la solicitud. No agregues hechos, horas, fechas, valores, medicamentos, procedimientos, personas ni conversaciones que no estén en ella.
2. Si un dato no está en la solicitud, escribe "No registrado". Nunca lo completes ni lo supongas.
3. No escribas la causa de la muerte, diagnósticos ni explicaciones sobre por qué ocurrió. Esa determinación le corresponde al médico.
4. Copia la fecha y la hora exactamente como aparecen en la solicitud.
5. Tono objetivo, en tercera persona y en español de Colombia. Sin adjetivos emocionales, condolencias ni juicios de valor.
6. Los códigos PAC-###, ID-### y CAMA-### reemplazan datos personales. Cópialos tal cual.
7. No uses siglas, salvo TA, FC, FR, SpO2, RCP y UCI.
8. Responde solo con estas líneas, en este orden y sin texto adicional:
Fecha y hora del fallecimiento:
Certificado por:
Hallazgos:
Maniobras de reanimación:
Dispositivos invasivos presentes:
Cuidados post mortem:
Información y entrega:
Observaciones:''';

String construirSolicitudFallecimiento(
  Paciente paciente,
  DatosFallecimiento d, {
  List<ProcedimientoInvasivo> procedimientos = const [],
}) {
  String lista(List<String> l) => l.isEmpty ? 'No registrado' : l.join('; ');
  final obs = d.observaciones.trim();
  return [
    paciente.toTexto(),
    'Fecha y hora del fallecimiento: ${formatearFechaHora(d.fechaHora)}',
    'Certificado por: ${d.quienCertifica.trim()}',
    'Signos observados: ${lista(d.signosObservados)}',
    'Maniobras de reanimación: ${d.reanimacion ? 'Sí, durante ${d.duracionReanimacionMin} minutos' : 'No se realizaron'}',
    'Dispositivos invasivos presentes: ${lista([for (final p in procedimientos) p.toTexto()])}',
    'Cuidados post mortem realizados: ${lista(d.cuidadosRealizados)}',
    'Información y entrega a: ${(d.entregaA ?? '').trim().isEmpty ? 'No registrado' : d.entregaA!.trim()}',
    'Observaciones: ${obs.isEmpty ? 'Ninguna' : obs}',
  ].join('\n');
}

/// Revisa que la nota no tenga horas, fechas ni causas de muerte que no
/// estaban en la solicitud.
class ValidadorNotaFallecimiento {
  const ValidadorNotaFallecimiento();

  static final _hora = RegExp(r'(?<!\d)([01]?\d|2[0-3]):([0-5]\d)(?!\d)');
  static final _fecha = RegExp(r'(?<!\d)(\d{1,2})/(\d{1,2})/(\d{4})(?!\d)');
  static final _causa = RegExp(
    r'causa (?:de(?:l)? (?:la )?(?:muerte|fallecimiento|deceso))|'
    r'falleci[oó] (?:por|debido a|a causa de)|secundari[oa] a|debido a',
    caseSensitive: false,
  );

  static Set<String> _horas(String t) => {
    for (final m in _hora.allMatches(t))
      '${int.parse(m[1]!).toString().padLeft(2, '0')}:${m[2]}',
  };

  static Set<String> _fechas(String t) => {
    for (final m in _fecha.allMatches(t))
      '${int.parse(m[1]!)}/${int.parse(m[2]!)}/${m[3]}',
  };

  List<String> problemas(String nota, String solicitud) => [
    for (final h in _horas(nota).difference(_horas(solicitud)))
      'La hora $h no está en los datos registrados.',
    for (final f in _fechas(nota).difference(_fechas(solicitud)))
      'La fecha $f no está en los datos registrados.',
    if (_causa.hasMatch(nota) && !_causa.hasMatch(solicitud))
      'La nota menciona una causa de muerte que no fue registrada.',
  ];
}

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
