/// TSK-03 · HU01: dosis y ritmo de las infusiones de medicamentos.
library;

/// Unidades de dosis. No se usa "UI" porque es una sigla prohibida (HU06).
enum UnidadDosis {
  mg('mg'),
  mcg('mcg'),
  g('g'),
  unidades('unidades'),
  mEq('mEq'),
  mcgKgMin('mcg/kg/min'),
  mgH('mg/h'),
  unidadesH('unidades/h');

  const UnidadDosis(this.etiqueta);
  final String etiqueta;
}

class Infusion {
  const Infusion({
    this.id,
    required this.medicamento,
    required this.dosis,
    required this.unidad,
    required this.ritmoMlH,
    this.concentracion,
  });

  final int? id;
  final String medicamento;
  final double dosis;
  final UnidadDosis unidad;

  /// Velocidad de la bomba en mL/h.
  final double ritmoMlH;

  /// Dilución opcional, por ejemplo "4 mg en 250 mL SSN".
  final String? concentracion;

  static const double ritmoMaximo = 999;

  static double? leerNumero(String? v) =>
      double.tryParse((v ?? '').trim().replaceAll(',', '.'));

  static String? validarMedicamento(String? v) =>
      (v ?? '').trim().isEmpty ? 'El medicamento es obligatorio' : null;

  static String? validarDosis(String? v) {
    final n = leerNumero(v);
    if (n == null) return 'Escriba la dosis';
    if (n <= 0) return 'La dosis debe ser mayor que 0';
    return null;
  }

  static String? validarRitmo(String? v) {
    final n = leerNumero(v);
    if (n == null) return 'Escriba el ritmo';
    if (n <= 0 || n > ritmoMaximo) {
      return 'El ritmo debe estar entre 0 y ${ritmoMaximo.toStringAsFixed(0)} mL/h';
    }
    return null;
  }

  List<String> validar() => [
    validarMedicamento(medicamento),
    validarDosis('$dosis'),
    validarRitmo('$ritmoMlH'),
  ].whereType<String>().toList();

  bool get esValida => validar().isEmpty;

  Infusion conId(int id) => Infusion(
    id: id,
    medicamento: medicamento,
    dosis: dosis,
    unidad: unidad,
    ritmoMlH: ritmoMlH,
    concentracion: concentracion,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'medicamento': medicamento,
    'dosis': dosis,
    'unidad': unidad.name,
    'ritmoMlH': ritmoMlH,
    'concentracion': concentracion,
  };

  factory Infusion.fromMap(Map<String, Object?> m) => Infusion(
    id: m['id'] as int?,
    medicamento: m['medicamento']! as String,
    dosis: (m['dosis']! as num).toDouble(),
    unidad: UnidadDosis.values.byName(m['unidad']! as String),
    ritmoMlH: (m['ritmoMlH']! as num).toDouble(),
    concentracion: m['concentracion'] as String?,
  );

  static String _numero(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  /// Por ejemplo: `Noradrenalina 0.1 mcg/kg/min a 8 mL/h (4 mg en 250 mL)`.
  String toTexto() {
    final dilucion = (concentracion ?? '').trim();
    return '${medicamento.trim()} ${_numero(dosis)} ${unidad.etiqueta} '
        'a ${_numero(ritmoMlH)} mL/h'
        '${dilucion.isEmpty ? '' : ' ($dilucion)'}';
  }
}
