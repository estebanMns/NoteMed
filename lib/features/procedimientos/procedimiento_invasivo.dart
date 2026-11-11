/// TSK-14 · HU04: registro de procedimientos invasivos (intubación, paso de
/// catéteres o sondas).
library;

enum TipoProcedimiento {
  intubacion('Intubación orotraqueal', 'Tubo N°'),
  cateterVenosoCentral('Catéter venoso central', 'Calibre / lúmenes'),
  cateterVenosoPeriferico('Catéter venoso periférico', 'Calibre (G)'),
  lineaArterial('Línea arterial', 'Calibre (G)'),
  sondaVesical('Sonda vesical', 'Calibre (Fr)'),
  sondaNasogastrica('Sonda nasogástrica', 'Calibre (Fr)'),
  otro('Otro procedimiento', 'Calibre / tamaño');

  const TipoProcedimiento(this.etiqueta, this.etiquetaCalibre);
  final String etiqueta;
  final String etiquetaCalibre;
}

class ProcedimientoInvasivo {
  const ProcedimientoInvasivo({
    this.id,
    required this.tipo,
    required this.fechaHora,
    required this.sitio,
    this.calibre,
    this.intentos = 1,
    required this.responsable,
    this.descripcionOtro,
    this.observaciones,
  });

  final int? id;
  final TipoProcedimiento tipo;
  final DateTime fechaHora;

  /// Sitio de inserción, por ejemplo "antebrazo izquierdo".
  final String sitio;
  final String? calibre;
  final int intentos;

  /// Cargo o rol de quien realizó el procedimiento (no el nombre).
  final String responsable;

  /// Obligatoria cuando el tipo es [TipoProcedimiento.otro].
  final String? descripcionOtro;
  final String? observaciones;

  static String? validarSitio(String? v) =>
      (v ?? '').trim().isEmpty ? 'El sitio es obligatorio' : null;

  static String? validarResponsable(String? v) =>
      (v ?? '').trim().isEmpty ? 'Indique el cargo de quien lo realizó' : null;

  static String? validarIntentos(String? v) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null || n < 1 || n > 10) return 'Intentos entre 1 y 10';
    return null;
  }

  List<String> validar({DateTime? ahora}) => [
    validarSitio(sitio),
    validarResponsable(responsable),
    validarIntentos('$intentos'),
    if (tipo == TipoProcedimiento.otro &&
        (descripcionOtro ?? '').trim().isEmpty)
      'Describa el procedimiento',
    if (fechaHora.isAfter(
      (ahora ?? DateTime.now()).add(const Duration(minutes: 5)),
    ))
      'La fecha y hora no puede ser futura',
  ].whereType<String>().toList();

  bool get esValido => validar().isEmpty;

  ProcedimientoInvasivo conId(int id) => ProcedimientoInvasivo(
    id: id,
    tipo: tipo,
    fechaHora: fechaHora,
    sitio: sitio,
    calibre: calibre,
    intentos: intentos,
    responsable: responsable,
    descripcionOtro: descripcionOtro,
    observaciones: observaciones,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'tipo': tipo.name,
    'fechaHora': fechaHora.toIso8601String(),
    'sitio': sitio,
    'calibre': calibre,
    'intentos': intentos,
    'responsable': responsable,
    'descripcionOtro': descripcionOtro,
    'observaciones': observaciones,
  };

  factory ProcedimientoInvasivo.fromMap(Map<String, Object?> m) =>
      ProcedimientoInvasivo(
        id: m['id'] as int?,
        tipo: TipoProcedimiento.values.byName(m['tipo']! as String),
        fechaHora: DateTime.parse(m['fechaHora']! as String),
        sitio: m['sitio']! as String,
        calibre: m['calibre'] as String?,
        intentos: m['intentos'] as int? ?? 1,
        responsable: m['responsable']! as String,
        descripcionOtro: m['descripcionOtro'] as String?,
        observaciones: m['observaciones'] as String?,
      );

  String get nombre => tipo == TipoProcedimiento.otro
      ? (descripcionOtro ?? '').trim()
      : tipo.etiqueta;

  /// Por ejemplo: `Sonda vesical (calibre 16 Fr) en meato urinario,
  /// 11/11/2026 08:30, 1 intento, por enfermera jefe`.
  String toTexto() {
    final c = (calibre ?? '').trim();
    final obs = (observaciones ?? '').trim();
    return '$nombre${c.isEmpty ? '' : ' (calibre $c)'} en ${sitio.trim()}, '
        '${formatearFechaHora(fechaHora)}, '
        '$intentos ${intentos == 1 ? 'intento' : 'intentos'}, '
        'por ${responsable.trim()}'
        '${obs.isEmpty ? '' : '. Observaciones: $obs'}';
  }
}

String _dos(int n) => n.toString().padLeft(2, '0');

/// `dd/mm/aaaa hh:mm`
String formatearFechaHora(DateTime f) =>
    '${_dos(f.day)}/${_dos(f.month)}/${f.year} ${_dos(f.hour)}:${_dos(f.minute)}';
