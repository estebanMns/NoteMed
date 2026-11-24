/// TSK-08 · HU02: recomendaciones breves de cuidado cuando una escala indica
/// riesgo alto.
library;

import 'package:notemed/features/valoracion/domain/braden/braden_escala.dart';
import 'package:notemed/features/valoracion/domain/downton/downton_escala.dart';

const List<String> recomendacionesCaidas = [
  'Mantener la cama en posición baja, frenada y con barandas arriba.',
  'Dejar el timbre y los objetos personales al alcance del paciente.',
  'Acompañar la deambulación y los traslados al baño.',
  'Usar calzado cerrado y antideslizante; mantener el piso seco.',
  'Revisar con el médico los medicamentos que aumentan el riesgo.',
  'Señalizar el riesgo de caída en la cama e informar al familiar.',
];

const List<String> recomendacionesLesionesPresion = [
  'Cambiar de posición al paciente cada 2 horas y registrarlo.',
  'Usar superficie de apoyo (colchón de aire o de presión alterna).',
  'Proteger talones y prominencias óseas; no masajear zonas enrojecidas.',
  'Mantener la piel limpia, seca e hidratada; controlar la humedad.',
  'Vigilar la nutrición y la hidratación; avisar si come menos de la mitad.',
];

/// Recomendaciones para Downton. Vacía si el riesgo no es alto.
List<String> recomendacionesDownton(EvaluacionDownton e) =>
    e.riesgoAlto == true ? recomendacionesCaidas : const [];

/// Recomendaciones para Braden. Solo aplican en riesgo alto o muy alto.
List<String> recomendacionesBraden(NivelRiesgoBraden? nivel) => switch (nivel) {
  NivelRiesgoBraden.alto ||
  NivelRiesgoBraden.muyAlto => recomendacionesLesionesPresion,
  _ => const [],
};
