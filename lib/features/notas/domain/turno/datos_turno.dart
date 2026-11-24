/// HU03: datos del turno con los que se pide la nota a la IA.
library;

import 'package:notemed/features/pacientes/domain/infusion.dart';
import 'package:notemed/features/pacientes/domain/paciente.dart';
import 'package:notemed/features/pacientes/domain/signos_vitales.dart';
import 'package:notemed/features/pacientes/domain/procedimiento_invasivo.dart';
import 'package:notemed/features/valoracion/domain/braden/braden_escala.dart';
import 'package:notemed/features/valoracion/domain/braden/braden_mapa.dart';
import 'package:notemed/features/valoracion/domain/downton/downton_escala.dart';
import 'package:notemed/features/valoracion/domain/prom/evaluacion_prom.dart';

/// Todo lo que se registra del paciente durante el turno.
class DatosTurno {
  const DatosTurno({
    required this.paciente,
    this.signos = const SignosVitales(),
    this.infusiones = const [],
    this.downton,
    this.braden,
    this.prom,
    this.procedimientos = const [],
    this.observaciones = '',
  });

  final Paciente paciente;
  final SignosVitales signos;
  final List<Infusion> infusiones;
  final EvaluacionDownton? downton;
  final EvaluacionBraden? braden;
  final EvaluacionProm? prom;
  final List<ProcedimientoInvasivo> procedimientos;
  final String observaciones;

  Map<String, Object?> toMap() => {
    'paciente': paciente.toMap(),
    'signos': signos.toMap(),
    'infusiones': [for (final i in infusiones) i.toMap()],
    'downton': downton?.toMap(),
    'braden': braden == null ? null : bradenAMapa(braden!),
    'prom': prom?.toMap(),
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
    prom: m['prom'] == null ? null : EvaluacionProm.fromMap(_mapa(m['prom'])),
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
    d.prom?.toTexto() ?? '${EvaluacionProm.titulo}: No registrados',
    'Procedimientos invasivos: ${_lista(d.procedimientos.map((p) => p.toTexto()))}',
    'Observaciones de enfermería: ${obs.isEmpty ? 'Ninguna' : obs}',
  ].join('\n');
}
