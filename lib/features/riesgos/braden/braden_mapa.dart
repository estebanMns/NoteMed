/// TSK-25 · HU07: conversión de la evaluación de Braden para guardarla en
/// la base local.
library;

import 'braden_escala.dart';

Map<String, Object?> bradenAMapa(EvaluacionBraden e) => {
  for (final p in e.puntajes.entries) p.key.name: p.value,
};

EvaluacionBraden bradenDeMapa(Map<String, Object?> m) => EvaluacionBraden({
  for (final e in m.entries)
    SubescalaBraden.values.byName(e.key): e.value! as int,
});
