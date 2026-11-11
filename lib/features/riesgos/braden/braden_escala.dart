/// TSK-07 · HU02: suma de puntos y nivel de riesgo de la escala de Braden.
library;

/// Una opción puntuable dentro de una subescala.
class OpcionBraden {
  const OpcionBraden(this.puntos, this.titulo, this.descripcion);

  final int puntos;
  final String titulo;
  final String descripcion;
}

/// Las seis subescalas de Braden.
enum SubescalaBraden {
  percepcionSensorial(
    'Percepción sensorial',
    [
      OpcionBraden(1, 'Completamente limitada',
          'No reacciona ante estímulos dolorosos.'),
      OpcionBraden(2, 'Muy limitada',
          'Reacciona solo ante estímulos dolorosos.'),
      OpcionBraden(3, 'Ligeramente limitada',
          'Reacciona a órdenes verbales, pero no siempre comunica molestias.'),
      OpcionBraden(4, 'Sin limitaciones',
          'Responde a órdenes verbales y no tiene déficit sensorial.'),
    ],
  ),
  humedad(
    'Exposición a la humedad',
    [
      OpcionBraden(1, 'Constantemente húmeda',
          'La piel está húmeda casi siempre (sudor, orina).'),
      OpcionBraden(2, 'A menudo húmeda',
          'La ropa de cama se cambia al menos una vez por turno.'),
      OpcionBraden(3, 'Ocasionalmente húmeda',
          'Requiere un cambio adicional de ropa de cama al día.'),
      OpcionBraden(4, 'Raramente húmeda',
          'La piel está generalmente seca.'),
    ],
  ),
  actividad(
    'Actividad',
    [
      OpcionBraden(1, 'Encamado', 'Permanece en cama.'),
      OpcionBraden(2, 'En silla', 'Capacidad de caminar muy limitada o nula.'),
      OpcionBraden(3, 'Deambula ocasionalmente',
          'Camina distancias cortas, con o sin ayuda.'),
      OpcionBraden(4, 'Deambula frecuentemente',
          'Camina fuera de la habitación varias veces al día.'),
    ],
  ),
  movilidad(
    'Movilidad',
    [
      OpcionBraden(1, 'Completamente inmóvil',
          'No realiza ningún cambio de posición sin ayuda.'),
      OpcionBraden(2, 'Muy limitada',
          'Cambios ocasionales y ligeros de posición.'),
      OpcionBraden(3, 'Ligeramente limitada',
          'Cambios frecuentes y ligeros de posición de forma independiente.'),
      OpcionBraden(4, 'Sin limitaciones',
          'Cambios de posición importantes y frecuentes sin ayuda.'),
    ],
  ),
  nutricion(
    'Nutrición',
    [
      OpcionBraden(1, 'Muy pobre',
          'Nunca come una comida completa; NPO o líquidos claros > 5 días.'),
      OpcionBraden(2, 'Probablemente inadecuada',
          'Rara vez come una comida completa.'),
      OpcionBraden(3, 'Adecuada',
          'Come más de la mitad de la mayoría de las comidas.'),
      OpcionBraden(4, 'Excelente', 'Come la mayor parte de cada comida.'),
    ],
  ),
  friccionCizallamiento(
    'Fricción y cizallamiento',
    [
      OpcionBraden(1, 'Problema',
          'Requiere asistencia máxima; se desliza con frecuencia.'),
      OpcionBraden(2, 'Problema potencial',
          'Se mueve débilmente o requiere mínima asistencia.'),
      OpcionBraden(3, 'Sin problema aparente',
          'Se mueve en cama y silla de forma independiente.'),
    ],
  );

  const SubescalaBraden(this.nombre, this.opciones);

  final String nombre;
  final List<OpcionBraden> opciones;

  int get minimo => opciones.first.puntos;
  int get maximo => opciones.last.puntos;
}

enum NivelRiesgoBraden {
  muyAlto('Riesgo muy alto'),
  alto('Riesgo alto'),
  moderado('Riesgo moderado'),
  bajo('Riesgo bajo'),
  sinRiesgo('Sin riesgo');

  const NivelRiesgoBraden(this.etiqueta);
  final String etiqueta;
}

/// Evaluación de Braden. Es inmutable: [conPuntaje] devuelve una copia.
class EvaluacionBraden {
  const EvaluacionBraden([this.puntajes = const {}]);

  static const int puntajeMinimo = 6;
  static const int puntajeMaximo = 23;

  final Map<SubescalaBraden, int> puntajes;

  EvaluacionBraden conPuntaje(SubescalaBraden subescala, int puntos) {
    if (puntos < subescala.minimo || puntos > subescala.maximo) {
      throw RangeError.range(
          puntos, subescala.minimo, subescala.maximo, subescala.nombre);
    }
    return EvaluacionBraden({...puntajes, subescala: puntos});
  }

  bool get completa =>
      SubescalaBraden.values.every((s) => puntajes.containsKey(s));

  List<SubescalaBraden> get pendientes =>
      SubescalaBraden.values.where((s) => !puntajes.containsKey(s)).toList();

  /// Suma total. Devuelve `null` hasta que las seis subescalas tengan valor.
  int? get total =>
      completa ? puntajes.values.fold<int>(0, (a, b) => a + b) : null;

  NivelRiesgoBraden? get nivel {
    final t = total;
    return t == null ? null : nivelPara(t);
  }

  static NivelRiesgoBraden nivelPara(int total) {
    if (total < puntajeMinimo || total > puntajeMaximo) {
      throw RangeError.range(total, puntajeMinimo, puntajeMaximo, 'total');
    }
    if (total <= 9) return NivelRiesgoBraden.muyAlto;
    if (total <= 12) return NivelRiesgoBraden.alto;
    if (total <= 14) return NivelRiesgoBraden.moderado;
    if (total <= 18) return NivelRiesgoBraden.bajo;
    return NivelRiesgoBraden.sinRiesgo;
  }
}
