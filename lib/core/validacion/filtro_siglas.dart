/// TSK-22 · HU06: filtro de siglas para registros de enfermería (Ley 911 de
/// 2004). El registro clínico debe ser claro, legible y sin ambigüedades:
/// solo se aceptan las siglas institucionales aprobadas; las prohibidas o
/// desconocidas se señalan con una sugerencia.
library;

enum TipoHallazgo { prohibida, desconocida }

class Hallazgo {
  const Hallazgo({
    required this.sigla,
    required this.inicio,
    required this.fin,
    required this.tipo,
    this.sugerencia,
  });

  final String sigla;
  final int inicio;
  final int fin;
  final TipoHallazgo tipo;
  final String? sugerencia;

  String get mensaje => switch (tipo) {
        TipoHallazgo.prohibida =>
          'La sigla "$sigla" no está permitida. Escriba: ${sugerencia ?? 'el término completo'}.',
        TipoHallazgo.desconocida =>
          'La sigla "$sigla" no está en la lista aprobada. Escriba el término completo.',
      };

  @override
  String toString() => 'Hallazgo($sigla, $inicio-$fin, ${tipo.name})';
}

class FiltroSiglas {
  const FiltroSiglas({
    this.permitidas = siglasPermitidas,
    this.prohibidas = siglasProhibidas,
  });

  /// Siglas aprobadas → significado. Se comparan exactamente (con
  /// mayúsculas), salvo unidades y abreviaturas mixtas como SpO2.
  final Map<String, String> permitidas;

  /// Siglas no permitidas o ambiguas → término sugerido.
  final Map<String, String> prohibidas;

  // Token candidato a sigla: 2 a 6 caracteres que empiezan por mayúscula y
  // tienen al menos otra mayúscula (TA, SpO2, VIH, PVC, IM). Se excluyen los
  // códigos de anonimización (PAC-001, CAMA-002, ID-003).
  static final RegExp _token = RegExp(
    r'(?<![\p{L}\p{N}])(\p{Lu}[\p{L}\p{N}]{1,5})(?![\p{L}\p{N}])(?!-\d)',
    unicode: true,
  );

  bool _pareceSigla(String t) =>
      RegExp(r'^\p{Lu}.*\p{Lu}', unicode: true).hasMatch(t) ||
      permitidas.containsKey(t) ||
      prohibidas.containsKey(t);

  /// Devuelve las siglas prohibidas o desconocidas de [texto], en orden.
  List<Hallazgo> analizar(String texto) {
    final hallazgos = <Hallazgo>[];
    for (final m in _token.allMatches(texto)) {
      final t = m[1]!;
      if (!_pareceSigla(t) || permitidas.containsKey(t)) continue;
      final prohibida = prohibidas[t];
      hallazgos.add(Hallazgo(
        sigla: t,
        inicio: m.start,
        fin: m.end,
        tipo: prohibida != null
            ? TipoHallazgo.prohibida
            : TipoHallazgo.desconocida,
        sugerencia: prohibida,
      ));
    }
    return hallazgos;
  }

  bool esValido(String texto) => analizar(texto).isEmpty;

  /// Reemplaza las siglas permitidas por su significado y las prohibidas por
  /// su sugerencia. Las desconocidas quedan igual (las debe corregir quien
  /// escribe).
  String expandir(String texto) => texto.replaceAllMapped(_token, (m) {
        final t = m[1]!;
        return permitidas[t] ?? prohibidas[t] ?? t;
      });
}

/// Lista institucional de siglas aprobadas. Es editable por el comité de
/// historias clínicas.
const Map<String, String> siglasPermitidas = {
  'TA': 'tensión arterial',
  'FC': 'frecuencia cardiaca',
  'FR': 'frecuencia respiratoria',
  'SpO2': 'saturación de oxígeno',
  'SatO2': 'saturación de oxígeno',
  'IV': 'intravenoso',
  'VO': 'vía oral',
  'IM': 'intramuscular',
  'SNG': 'sonda nasogástrica',
  'UCI': 'unidad de cuidados intensivos',
  'EKG': 'electrocardiograma',
  'ECG': 'electrocardiograma',
  'HTA': 'hipertensión arterial',
  'EPOC': 'enfermedad pulmonar obstructiva crónica',
  'VIH': 'virus de inmunodeficiencia humana',
  'PVC': 'presión venosa central',
  'TAM': 'tensión arterial media',
  'IMC': 'índice de masa corporal',
  'SBAR': 'situación, antecedentes, evaluación, recomendación',
};

/// Siglas prohibidas por ambiguas o propensas a error (basado en las listas
/// de abreviaturas peligrosas de seguridad del paciente).
const Map<String, String> siglasProhibidas = {
  'SC': 'subcutáneo (o superficie corporal: especifique)',
  'SL': 'sublingual',
  'QD': 'diario',
  'QOD': 'interdiario',
  'HS': 'al acostarse',
  'IU': 'unidades internacionales',
  'UI': 'unidades internacionales',
  'IT': 'intratecal',
  'AD': 'oído derecho',
  'AI': 'oído izquierdo',
  'OD': 'ojo derecho',
  'OI': 'ojo izquierdo',
  'BID': 'cada 12 horas',
  'TID': 'cada 8 horas',
  'QID': 'cada 6 horas',
  'PRN': 'si es necesario',
  'NPO': 'nada por vía oral',
  'DM': 'diabetes mellitus',
  'IAM': 'infarto agudo de miocardio',
  'ICC': 'insuficiencia cardiaca congestiva',
  'IRA': 'insuficiencia renal aguda (o infección respiratoria aguda: especifique)',
  'MgSO4': 'sulfato de magnesio',
  'MS': 'sulfato de morfina (o sulfato de magnesio: especifique)',
};
