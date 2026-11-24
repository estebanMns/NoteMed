/// HU05 / HU06: revisión automática del texto de una nota antes de firmar:
/// siglas no aprobadas (TSK-21 / TSK-22) y signos vitales que no concuerdan
/// con lo registrado (TSK-23).
library;

import 'package:notemed/features/validacion/domain/diccionario_medico.dart';
import 'package:notemed/features/validacion/domain/filtro_siglas.dart';
import 'package:notemed/features/validacion/domain/verificador_signos_vitales.dart';
import 'package:notemed/features/pacientes/domain/signos_vitales.dart';

class RevisionNota {
  const RevisionNota({
    required this.texto,
    this.discrepancias = const [],
    this.siglas = const [],
  });

  final String texto;
  final List<Discrepancia> discrepancias;
  final List<Hallazgo> siglas;

  bool get tieneAdvertencias => discrepancias.isNotEmpty || siglas.isNotEmpty;

  /// Errores que impiden firmar: valores diferentes o inventados. Las
  /// omisiones y las siglas son advertencias.
  bool get bloqueaFirma =>
      discrepancias.any((d) => d.tipo != TipoDiscrepancia.omitido);

  List<String> get mensajes => [
    for (final d in discrepancias) d.mensaje,
    for (final h in siglas) h.mensaje,
  ];
}

RevisionNota revisarNota(
  String texto, {
  required SignosVitales signos,
  DiccionarioMedico diccionario = DiccionarioMedico.aprobado,
}) => RevisionNota(
  texto: texto,
  discrepancias: const VerificadorSignosVitales().verificar(texto, signos),
  siglas: diccionario.filtro.analizar(texto),
);

/// Revisa el texto actual: mensajes a mostrar y si hay errores que impiden
/// firmar.
typedef RevisorNota =
    ({List<String> mensajes, bool bloquea}) Function(String texto);
