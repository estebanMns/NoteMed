/// TSK-06 · HU02: escala de Downton (riesgo de caídas). Cada factor presente
/// suma 1 punto; 3 o más indica riesgo alto.
library;

enum CategoriaDownton {
  caidas('Caídas previas'),
  medicamentos('Medicamentos'),
  deficitSensorial('Déficit sensorial'),
  estadoMental('Estado mental');

  const CategoriaDownton(this.titulo);
  final String titulo;
}

/// Factores que se marcan con una casilla.
enum FactorDownton {
  caidasPrevias(CategoriaDownton.caidas, 'Ha tenido caídas previas'),
  tranquilizantes(CategoriaDownton.medicamentos, 'Tranquilizantes / sedantes'),
  diureticos(CategoriaDownton.medicamentos, 'Diuréticos'),
  hipotensores(CategoriaDownton.medicamentos, 'Hipotensores (no diuréticos)'),
  antiparkinsonianos(CategoriaDownton.medicamentos, 'Antiparkinsonianos'),
  antidepresivos(CategoriaDownton.medicamentos, 'Antidepresivos'),
  otrosMedicamentos(CategoriaDownton.medicamentos, 'Otros medicamentos'),
  alteracionesVisuales(
    CategoriaDownton.deficitSensorial,
    'Alteraciones visuales',
  ),
  alteracionesAuditivas(
    CategoriaDownton.deficitSensorial,
    'Alteraciones auditivas',
  ),
  extremidades(
    CategoriaDownton.deficitSensorial,
    'Extremidades (ictus, neuropatía, amputación…)',
  ),
  confusion(CategoriaDownton.estadoMental, 'Confuso / desorientado');

  const FactorDownton(this.categoria, this.etiqueta);

  final CategoriaDownton categoria;
  final String etiqueta;

  static List<FactorDownton> de(CategoriaDownton c) =>
      values.where((f) => f.categoria == c).toList();
}

/// Deambulación: se elige una sola opción.
enum DeambulacionDownton {
  normal('Normal', 0),
  seguraConAyuda('Segura con ayuda', 1),
  insegura('Insegura con o sin ayuda', 1),
  imposible('Imposible', 1);

  const DeambulacionDownton(this.etiqueta, this.puntos);
  final String etiqueta;
  final int puntos;
}

/// Evaluación de Downton. Es inmutable: [conFactor] y [conDeambulacion]
/// devuelven una copia.
class EvaluacionDownton {
  const EvaluacionDownton({this.factores = const {}, this.deambulacion});

  static const int umbralRiesgoAlto = 3;
  static final int puntajeMaximo = FactorDownton.values.length + 1;

  final Set<FactorDownton> factores;

  /// Es `null` mientras no se haya elegido.
  final DeambulacionDownton? deambulacion;

  EvaluacionDownton conFactor(FactorDownton f, bool presente) =>
      EvaluacionDownton(
        factores: presente ? {...factores, f} : ({...factores}..remove(f)),
        deambulacion: deambulacion,
      );

  EvaluacionDownton conDeambulacion(DeambulacionDownton d) =>
      EvaluacionDownton(factores: factores, deambulacion: d);

  /// La evaluación está completa cuando se registró la deambulación (las
  /// casillas sin marcar valen 0).
  bool get completa => deambulacion != null;

  int get total => factores.length + (deambulacion?.puntos ?? 0);

  /// `null` hasta que la evaluación esté completa.
  bool? get riesgoAlto => completa ? total >= umbralRiesgoAlto : null;

  String get etiquetaRiesgo => switch (riesgoAlto) {
    null => 'Incompleta',
    true => 'Riesgo alto de caídas',
    false => 'Riesgo bajo de caídas',
  };

  Map<String, Object?> toMap() => {
    'factores': [for (final f in factores) f.name],
    'deambulacion': deambulacion?.name,
  };

  factory EvaluacionDownton.fromMap(Map<String, Object?> m) =>
      EvaluacionDownton(
        factores: {
          for (final n in (m['factores'] as List? ?? const []))
            FactorDownton.values.byName(n as String),
        },
        deambulacion: m['deambulacion'] == null
            ? null
            : DeambulacionDownton.values.byName(m['deambulacion']! as String),
      );

  String toTexto() {
    if (!completa) return 'Escala de Downton: incompleta';
    final presentes = factores.map((f) => f.etiqueta.toLowerCase()).toList()
      ..add('deambulación ${deambulacion!.etiqueta.toLowerCase()}');
    return 'Escala de Downton: $total puntos ($etiquetaRiesgo). '
        'Factores: ${presentes.join(', ')}';
  }
}
