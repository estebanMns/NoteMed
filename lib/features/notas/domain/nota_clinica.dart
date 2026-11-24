/// Entidad de nota clínica de enfermería. Dart puro, sin Flutter.
///
/// Ciclo de vida (Human-in-the-Loop, PDF §1.8 y §2.2.6):
///   borrador (IA) → revisada (la enfermera la edita) → firmada (inmutable).
library;

enum TipoNota {
  recibo('Recibo y entrega de turno'),
  evolucion('Evolución'),
  traslado('Traslado'),
  procedimiento('Procedimiento'),
  fallecimiento('Fallecimiento');

  const TipoNota(this.etiqueta);
  final String etiqueta;
}

enum EstadoNota { borrador, revisada, firmada }

/// Se lanza al intentar firmar una nota que no cumple las reglas de
/// [FirmarNota]. [motivos] se muestra a la enfermera.
class NotaNoFirmableException implements Exception {
  const NotaNoFirmableException(this.motivos);

  final List<String> motivos;

  @override
  String toString() => 'NotaNoFirmableException: ${motivos.join('; ')}';
}

class NotaClinica {
  const NotaClinica({
    required this.id,
    required this.pseudonimoPaciente,
    required this.tipo,
    required this.texto,
    this.estado = EstadoNota.borrador,
    this.firmadaPor,
    this.firmadaEn,
  });

  final String id;

  /// Código del paciente (`PAC-###`), nunca el nombre real.
  final String pseudonimoPaciente;
  final TipoNota tipo;
  final String texto;
  final EstadoNota estado;

  /// Rol o código de quien firma (no el nombre). Solo existe si está firmada.
  final String? firmadaPor;
  final DateTime? firmadaEn;

  bool get esFirmada => estado == EstadoNota.firmada;

  /// La enfermera revisó y editó el texto. Una nota firmada no se modifica.
  NotaClinica revisar(String textoRevisado) {
    if (esFirmada) {
      throw StateError('Una nota firmada no se puede modificar.');
    }
    return NotaClinica(
      id: id,
      pseudonimoPaciente: pseudonimoPaciente,
      tipo: tipo,
      texto: textoRevisado,
      estado: EstadoNota.revisada,
    );
  }

  /// Sella la nota. Solo válido desde `revisada`; las reglas de contenido
  /// (siglas, texto no vacío) las valida [FirmarNota] antes de llamar aquí.
  NotaClinica firmar({required String firmante, required DateTime ahora}) {
    if (estado != EstadoNota.revisada) {
      throw StateError('La nota debe revisarse antes de firmar.');
    }
    return NotaClinica(
      id: id,
      pseudonimoPaciente: pseudonimoPaciente,
      tipo: tipo,
      texto: texto,
      estado: EstadoNota.firmada,
      firmadaPor: firmante,
      firmadaEn: ahora,
    );
  }
}
