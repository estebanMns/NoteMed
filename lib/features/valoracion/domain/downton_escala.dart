/// Escala de Downton: riesgo de caídas (PDF §2.2.4, Downton 1993).
///
/// Versión simplificada con 5 factores binarios (1 punto cada uno). El corte
/// de riesgo alto (≥ 3) y los factores deben validarse con el equipo de
/// enfermería de la UCI antes de usarse clínicamente.
library;

enum NivelRiesgoCaidas {
  bajo('Riesgo bajo de caídas'),
  alto('Riesgo alto de caídas');

  const NivelRiesgoCaidas(this.etiqueta);
  final String etiqueta;
}

class EvaluacionDownton {
  const EvaluacionDownton({
    this.caidasPrevias = false,
    this.medicacionRiesgo = false,
    this.deficitSensorial = false,
    this.estadoMentalAlterado = false,
    this.marchaAlterada = false,
  });

  /// Caídas en el último año o en el ingreso.
  final bool caidasPrevias;

  /// Uso de medicamentos de riesgo (sedantes, diuréticos, hipotensores,
  /// antidepresivos, antiepilépticos, opioides...).
  final bool medicacionRiesgo;

  /// Déficit visual, auditivo o de extremidades.
  final bool deficitSensorial;

  /// Desorientación o confusión.
  final bool estadoMentalAlterado;

  /// Marcha débil o con ayuda técnica.
  final bool marchaAlterada;

  int get total => [
        caidasPrevias,
        medicacionRiesgo,
        deficitSensorial,
        estadoMentalAlterado,
        marchaAlterada,
      ].where((f) => f).length;

  NivelRiesgoCaidas get nivel =>
      total >= 3 ? NivelRiesgoCaidas.alto : NivelRiesgoCaidas.bajo;
}
