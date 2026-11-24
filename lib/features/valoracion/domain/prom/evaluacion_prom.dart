/// PROM (Patient-Reported Outcome Measures): lo que el paciente reporta de
/// su propio estado, en escala de 0 a 10 (0 = nada, 10 = lo peor que puede
/// imaginar). Cuando el paciente no puede responder (sedación, intubación,
/// alteración de la conciencia) se registra el motivo en lugar de inventar
/// valores.
///
/// Los ítems son PROVISIONALES: el diccionario de datos definitivo del PROM
/// se acuerda con el personal de la UCI en la Fase 1 (objetivo específico 1).
/// Agregar o cambiar un ítem solo requiere editar [ItemProm].
library;

enum ItemProm {
  dolor('Dolor', '¿Cuánto dolor siente en este momento?'),
  disnea('Dificultad para respirar', '¿Cuánta dificultad tiene para respirar?'),
  ansiedad('Ansiedad o miedo', '¿Qué tanta ansiedad o miedo siente?'),
  sed('Sed', '¿Cuánta sed tiene?'),
  malestar('Malestar general', '¿Qué tan mal se siente en general?'),
  sueno('Mal descanso', '¿Qué tan mal descansó o durmió?');

  const ItemProm(this.etiqueta, this.pregunta);
  final String etiqueta;
  final String pregunta;
}

enum MotivoNoResponde {
  sedacion('Bajo sedación'),
  viaAerea('Intubado, sin forma de comunicarse'),
  conciencia('Alteración de la conciencia'),
  otro('Otro motivo');

  const MotivoNoResponde(this.etiqueta);
  final String etiqueta;
}

/// Evaluación PROM. Es inmutable: los métodos `con...` devuelven una copia.
class EvaluacionProm {
  const EvaluacionProm({
    this.respuestas = const {},
    this.puedeResponder = true,
    this.motivo,
  });

  static const int minimo = 0;
  static const int maximo = 10;

  /// Desde este valor el ítem se resalta como alerta.
  static const int umbralAlerta = 7;

  final Map<ItemProm, int> respuestas;
  final bool puedeResponder;

  /// Obligatorio cuando el paciente no puede responder.
  final MotivoNoResponde? motivo;

  EvaluacionProm conRespuesta(ItemProm item, int valor) {
    if (valor < minimo || valor > maximo) {
      throw RangeError.range(valor, minimo, maximo, item.etiqueta);
    }
    return EvaluacionProm(
      respuestas: {...respuestas, item: valor},
      puedeResponder: puedeResponder,
      motivo: motivo,
    );
  }

  EvaluacionProm conPuedeResponder(bool puede) => EvaluacionProm(
    respuestas: respuestas,
    puedeResponder: puede,
    motivo: puede ? null : motivo,
  );

  EvaluacionProm conMotivo(MotivoNoResponde m) =>
      EvaluacionProm(respuestas: respuestas, puedeResponder: false, motivo: m);

  List<ItemProm> get pendientes => puedeResponder
      ? ItemProm.values.where((i) => !respuestas.containsKey(i)).toList()
      : const [];

  bool get completa => puedeResponder ? pendientes.isEmpty : motivo != null;

  /// Ítems con valor alto, por ejemplo `Dolor: 8/10`.
  List<String> get alertas => [
    if (puedeResponder)
      for (final i in ItemProm.values)
        if ((respuestas[i] ?? 0) >= umbralAlerta)
          '${i.etiqueta}: ${respuestas[i]}/$maximo',
  ];

  Map<String, Object?> toMap() => {
    'respuestas': {for (final e in respuestas.entries) e.key.name: e.value},
    'puedeResponder': puedeResponder,
    'motivo': motivo?.name,
  };

  factory EvaluacionProm.fromMap(Map<String, Object?> m) => EvaluacionProm(
    respuestas: {
      for (final e in (m['respuestas'] as Map? ?? const {}).entries)
        ItemProm.values.byName(e.key as String): e.value as int,
    },
    puedeResponder: m['puedeResponder'] as bool? ?? true,
    motivo: m['motivo'] == null
        ? null
        : MotivoNoResponde.values.byName(m['motivo']! as String),
  );

  static const titulo = 'Resultados reportados por el paciente';

  /// Resumen corto para la pantalla del paciente.
  String get resumen {
    if (!completa) return 'Incompleto';
    if (!puedeResponder) return 'No valorable: ${motivo!.etiqueta}';
    final a = alertas;
    return a.isEmpty ? 'Sin valores altos' : 'Alerta: ${a.join(', ')}';
  }

  /// Línea para la solicitud a la IA. No usa la sigla "PROM", que no está en
  /// el diccionario de siglas aprobadas.
  String toTexto() {
    if (!completa) return '$titulo: incompletos';
    if (!puedeResponder) {
      return '$titulo: no valorables (${motivo!.etiqueta.toLowerCase()})';
    }
    return '$titulo: ${[for (final i in ItemProm.values) '${i.etiqueta.toLowerCase()} ${respuestas[i]}/$maximo'].join(', ')}';
  }
}
