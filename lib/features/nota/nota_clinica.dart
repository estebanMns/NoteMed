/// HU05: nota clínica guardada (borrador o firmada).
library;

import 'firma_enfermera.dart';

enum TipoNota {
  turno('Nota de turno'),
  fallecimiento('Nota de fallecimiento');

  const TipoNota(this.etiqueta);
  final String etiqueta;
}

enum EstadoNota { borrador, firmada }

class NotaClinica {
  const NotaClinica({
    this.id,
    required this.pacienteId,
    required this.tipo,
    required this.texto,
    required this.creada,
    this.referencia = const {},
    this.firma,
  });

  final int? id;
  final int pacienteId;
  final TipoNota tipo;
  final String texto;
  final DateTime creada;

  /// Datos con los que se revisa el texto: los signos vitales (turno) o la
  /// solicitud original (fallecimiento).
  final Map<String, Object?> referencia;

  /// `null` mientras sea borrador.
  final FirmaEnfermera? firma;

  EstadoNota get estado =>
      firma == null ? EstadoNota.borrador : EstadoNota.firmada;

  NotaClinica conId(int id) => NotaClinica(
    id: id,
    pacienteId: pacienteId,
    tipo: tipo,
    texto: texto,
    creada: creada,
    referencia: referencia,
    firma: firma,
  );

  NotaClinica firmar(String textoFinal, FirmaEnfermera f) => NotaClinica(
    id: id,
    pacienteId: pacienteId,
    tipo: tipo,
    texto: textoFinal,
    creada: creada,
    referencia: referencia,
    firma: f,
  );
}
