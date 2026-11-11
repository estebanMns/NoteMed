/// TSK-21 · HU06: diccionario de palabras y siglas médicas aprobadas por el
/// hospital. Es la fuente de las siglas permitidas del [FiltroSiglas] y de
/// la lista que se le entrega a la IA.
library;

import '../privacidad/anonimizador.dart';
import 'filtro_siglas.dart';

enum CategoriaTermino {
  signosVitales('Signos vitales'),
  viasAdministracion('Vías de administración'),
  dispositivos('Dispositivos y procedimientos'),
  servicios('Servicios'),
  diagnosticos('Diagnósticos'),
  estudios('Estudios'),
  otros('Otros');

  const CategoriaTermino(this.titulo);
  final String titulo;
}

class TerminoMedico {
  const TerminoMedico(this.sigla, this.significado, this.categoria);

  final String sigla;
  final String significado;
  final CategoriaTermino categoria;

  @override
  String toString() => '$sigla: $significado';
}

class DiccionarioMedico {
  const DiccionarioMedico(this.terminos);

  /// Diccionario institucional aprobado por el comité de historias clínicas.
  static const DiccionarioMedico aprobado = DiccionarioMedico(_aprobados);

  final List<TerminoMedico> terminos;

  /// Busca una sigla exacta (con mayúsculas).
  TerminoMedico? buscar(String sigla) {
    for (final t in terminos) {
      if (t.sigla == sigla) return t;
    }
    return null;
  }

  bool contiene(String sigla) => buscar(sigla) != null;

  /// Términos cuya sigla o significado contienen [consulta], sin importar
  /// mayúsculas ni tildes. Una consulta vacía devuelve todo.
  List<TerminoMedico> filtrar(String consulta) {
    final q = Anonimizador.normalizar(consulta);
    if (q.isEmpty) return List.of(terminos);
    return terminos
        .where(
          (t) =>
              Anonimizador.normalizar(t.sigla).contains(q) ||
              Anonimizador.normalizar(t.significado).contains(q),
        )
        .toList();
  }

  List<TerminoMedico> porCategoria(CategoriaTermino c) =>
      terminos.where((t) => t.categoria == c).toList();

  /// Sigla → significado, en el formato que usa [FiltroSiglas].
  Map<String, String> comoMapa() => {
    for (final t in terminos) t.sigla: t.significado,
  };

  FiltroSiglas get filtro => FiltroSiglas(permitidas: comoMapa());

  /// Lista para incluir en las instrucciones de la IA.
  String comoListaTexto() => terminos.map((t) => t.toString()).join('; ');
}

const List<TerminoMedico> _aprobados = [
  // Signos vitales
  TerminoMedico('TA', 'tensión arterial', CategoriaTermino.signosVitales),
  TerminoMedico(
    'TAM',
    'tensión arterial media',
    CategoriaTermino.signosVitales,
  ),
  TerminoMedico('FC', 'frecuencia cardiaca', CategoriaTermino.signosVitales),
  TerminoMedico(
    'FR',
    'frecuencia respiratoria',
    CategoriaTermino.signosVitales,
  ),
  TerminoMedico(
    'SpO2',
    'saturación de oxígeno',
    CategoriaTermino.signosVitales,
  ),
  TerminoMedico(
    'SatO2',
    'saturación de oxígeno',
    CategoriaTermino.signosVitales,
  ),
  TerminoMedico(
    'PVC',
    'presión venosa central',
    CategoriaTermino.signosVitales,
  ),
  TerminoMedico(
    'FiO2',
    'fracción inspirada de oxígeno',
    CategoriaTermino.signosVitales,
  ),
  TerminoMedico(
    'IMC',
    'índice de masa corporal',
    CategoriaTermino.signosVitales,
  ),
  // Vías de administración
  TerminoMedico('IV', 'intravenoso', CategoriaTermino.viasAdministracion),
  TerminoMedico('EV', 'endovenoso', CategoriaTermino.viasAdministracion),
  TerminoMedico('VO', 'vía oral', CategoriaTermino.viasAdministracion),
  TerminoMedico('IM', 'intramuscular', CategoriaTermino.viasAdministracion),
  // Dispositivos y procedimientos
  TerminoMedico('SNG', 'sonda nasogástrica', CategoriaTermino.dispositivos),
  TerminoMedico('SV', 'sonda vesical', CategoriaTermino.dispositivos),
  TerminoMedico('TOT', 'tubo orotraqueal', CategoriaTermino.dispositivos),
  TerminoMedico('IOT', 'intubación orotraqueal', CategoriaTermino.dispositivos),
  TerminoMedico('CVC', 'catéter venoso central', CategoriaTermino.dispositivos),
  TerminoMedico(
    'CVP',
    'catéter venoso periférico',
    CategoriaTermino.dispositivos,
  ),
  TerminoMedico(
    'RCP',
    'reanimación cardiopulmonar',
    CategoriaTermino.dispositivos,
  ),
  TerminoMedico(
    'PEEP',
    'presión positiva al final de la espiración',
    CategoriaTermino.dispositivos,
  ),
  // Servicios
  TerminoMedico(
    'UCI',
    'unidad de cuidados intensivos',
    CategoriaTermino.servicios,
  ),
  TerminoMedico(
    'SBAR',
    'situación, antecedentes, evaluación, recomendación',
    CategoriaTermino.otros,
  ),
  // Estudios
  TerminoMedico('EKG', 'electrocardiograma', CategoriaTermino.estudios),
  TerminoMedico('ECG', 'electrocardiograma', CategoriaTermino.estudios),
  TerminoMedico(
    'TAC',
    'tomografía axial computarizada',
    CategoriaTermino.estudios,
  ),
  // Diagnósticos
  TerminoMedico('HTA', 'hipertensión arterial', CategoriaTermino.diagnosticos),
  TerminoMedico(
    'EPOC',
    'enfermedad pulmonar obstructiva crónica',
    CategoriaTermino.diagnosticos,
  ),
  TerminoMedico(
    'VIH',
    'virus de inmunodeficiencia humana',
    CategoriaTermino.diagnosticos,
  ),
  TerminoMedico(
    'ACV',
    'accidente cerebrovascular',
    CategoriaTermino.diagnosticos,
  ),
  TerminoMedico(
    'ERC',
    'enfermedad renal crónica',
    CategoriaTermino.diagnosticos,
  ),
];
