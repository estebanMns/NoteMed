/// Datos de la nota de traslado de un paciente que sale de la UCI.
library;

import 'package:notemed/features/notas/domain/turno/datos_turno.dart';

enum MedioTraslado {
  camilla('Camilla'),
  cama('En su cama'),
  sillaRuedas('Silla de ruedas'),
  ambulancia('Ambulancia');

  const MedioTraslado(this.etiqueta);
  final String etiqueta;
}

enum EstadoConciencia {
  alerta('Alerta'),
  somnoliento('Somnoliento'),
  estuporoso('Estuporoso'),
  sedado('Bajo sedación'),
  coma('En coma');

  const EstadoConciencia(this.etiqueta);
  final String etiqueta;
}

class DatosTraslado {
  const DatosTraslado({
    required this.destino,
    required this.motivo,
    required this.medio,
    required this.acompanante,
    required this.recibe,
    required this.estadoConciencia,
  });

  /// Servicio o institución de destino, por ejemplo "Hospitalización piso 3".
  final String destino;
  final String motivo;
  final MedioTraslado medio;

  /// Cargo de quien acompaña (sin nombres), por ejemplo "auxiliar de
  /// enfermería y médico de turno".
  final String acompanante;

  /// Cargo de quien recibe en el destino (sin nombres).
  final String recibe;
  final EstadoConciencia estadoConciencia;

  List<String> validar() => [
    if (destino.trim().isEmpty) 'Indique el destino',
    if (motivo.trim().isEmpty) 'Indique el motivo del traslado',
    if (acompanante.trim().isEmpty) 'Indique el cargo de quien acompaña',
    if (recibe.trim().isEmpty) 'Indique el cargo de quien recibe',
  ];

  Map<String, Object?> toMap() => {
    'destino': destino,
    'motivo': motivo,
    'medio': medio.name,
    'acompanante': acompanante,
    'recibe': recibe,
    'estadoConciencia': estadoConciencia.name,
  };

  factory DatosTraslado.fromMap(Map<String, Object?> m) => DatosTraslado(
    destino: m['destino']! as String,
    motivo: m['motivo']! as String,
    medio: MedioTraslado.values.byName(m['medio']! as String),
    acompanante: m['acompanante']! as String,
    recibe: m['recibe']! as String,
    estadoConciencia: EstadoConciencia.values.byName(
      m['estadoConciencia']! as String,
    ),
  );
}

/// Datos del turno más los del traslado. Se anonimiza antes de enviar.
String construirSolicitudTraslado(DatosTurno d, DatosTraslado t) => [
  construirSolicitudTurno(d),
  'Destino: ${t.destino.trim()}',
  'Motivo del traslado: ${t.motivo.trim()}',
  'Medio de transporte: ${t.medio.etiqueta}',
  'Acompañante: ${t.acompanante.trim()}',
  'Recibe: ${t.recibe.trim()}',
  'Estado de conciencia: ${t.estadoConciencia.etiqueta}',
].join('\n');
