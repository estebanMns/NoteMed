/// TSK-10 · HU03: plantilla SBAR para la nota de recibo y entrega de turno.
/// SBAR = Situación, Antecedentes (Background), Evaluación (Assessment),
/// Recomendación.
library;

enum SeccionSbar {
  situacion(
    'S',
    'Situación',
    '¿Qué está pasando ahora con el paciente? Motivo de atención, estado '
        'actual, signos vitales relevantes.',
  ),
  antecedentes(
    'B',
    'Antecedentes',
    'Diagnóstico de ingreso, antecedentes, alergias, medicación actual, '
        'procedimientos realizados.',
  ),
  evaluacion(
    'A',
    'Evaluación',
    'Valoración de enfermería: hallazgos, escalas de riesgo, balance de '
        'líquidos, dispositivos.',
  ),
  recomendacion(
    'R',
    'Recomendación',
    'Pendientes, cuidados a continuar, alertas para el siguiente turno.',
  );

  const SeccionSbar(this.letra, this.titulo, this.guia);

  final String letra;
  final String titulo;
  final String guia;
}

/// Nota SBAR inmutable. Las cuatro secciones son obligatorias.
class NotaSbar {
  const NotaSbar({
    this.situacion = '',
    this.antecedentes = '',
    this.evaluacion = '',
    this.recomendacion = '',
    this.turnoEntrega,
    this.turnoRecibe,
  });

  final String situacion;
  final String antecedentes;
  final String evaluacion;
  final String recomendacion;

  /// Rol o código de quien entrega y de quien recibe. No van nombres reales
  /// del personal ni del paciente (ver HU08).
  final String? turnoEntrega;
  final String? turnoRecibe;

  String texto(SeccionSbar s) => switch (s) {
        SeccionSbar.situacion => situacion,
        SeccionSbar.antecedentes => antecedentes,
        SeccionSbar.evaluacion => evaluacion,
        SeccionSbar.recomendacion => recomendacion,
      };

  NotaSbar con(SeccionSbar s, String valor) => NotaSbar(
        situacion: s == SeccionSbar.situacion ? valor : situacion,
        antecedentes: s == SeccionSbar.antecedentes ? valor : antecedentes,
        evaluacion: s == SeccionSbar.evaluacion ? valor : evaluacion,
        recomendacion: s == SeccionSbar.recomendacion ? valor : recomendacion,
        turnoEntrega: turnoEntrega,
        turnoRecibe: turnoRecibe,
      );

  /// Secciones vacías (solo espacios cuenta como vacía).
  List<SeccionSbar> validar() =>
      SeccionSbar.values.where((s) => texto(s).trim().isEmpty).toList();

  bool get esValida => validar().isEmpty;

  /// Texto final de la nota, con una sección por línea.
  String toTexto() {
    final b = StringBuffer('NOTA DE ENTREGA DE TURNO (SBAR)\n');
    if (turnoEntrega != null) b.writeln('Entrega: $turnoEntrega');
    if (turnoRecibe != null) b.writeln('Recibe: $turnoRecibe');
    for (final s in SeccionSbar.values) {
      b.writeln('[${s.letra}] ${s.titulo}: ${texto(s).trim()}');
    }
    return b.toString().trimRight();
  }
}
