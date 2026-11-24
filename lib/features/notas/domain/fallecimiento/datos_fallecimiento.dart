/// TSK-15 · HU04: datos de la nota de fallecimiento y validación de que la
/// IA no agregue horas, fechas ni causas de muerte.
library;

import 'package:notemed/core/utils/fechas.dart';
import 'package:notemed/features/pacientes/domain/paciente.dart';
import 'package:notemed/features/pacientes/domain/procedimiento_invasivo.dart';

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
