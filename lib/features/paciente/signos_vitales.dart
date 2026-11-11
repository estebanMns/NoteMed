/// HU01: signos vitales registrados por la enfermera. Son la referencia con
/// la que se verifica el texto que genera la IA (TSK-23).
library;

class SignosVitales {
  const SignosVitales({
    this.taSistolica,
    this.taDiastolica,
    this.fc,
    this.fr,
    this.spo2,
    this.temperatura,
  });

  /// mmHg
  final int? taSistolica;
  final int? taDiastolica;

  /// latidos por minuto
  final int? fc;

  /// respiraciones por minuto
  final int? fr;

  /// %
  final int? spo2;

  /// °C
  final double? temperatura;

  bool get vacio =>
      taSistolica == null &&
      taDiastolica == null &&
      fc == null &&
      fr == null &&
      spo2 == null &&
      temperatura == null;

  /// Errores de rango. La TA debe tener los dos valores o ninguno.
  List<String> validar() {
    final errores = <String>[];
    void rango(num? v, num min, num max, String nombre) {
      if (v != null && (v < min || v > max)) {
        errores.add('$nombre fuera de rango ($min a $max)');
      }
    }

    if ((taSistolica == null) != (taDiastolica == null)) {
      errores.add('Registre la TA sistólica y diastólica');
    }
    rango(taSistolica, 40, 300, 'TA sistólica');
    rango(taDiastolica, 20, 200, 'TA diastólica');
    if (taSistolica != null &&
        taDiastolica != null &&
        taDiastolica! >= taSistolica!) {
      errores.add('La TA diastólica debe ser menor que la sistólica');
    }
    rango(fc, 20, 250, 'FC');
    rango(fr, 4, 80, 'FR');
    rango(spo2, 50, 100, 'SpO2');
    rango(temperatura, 30, 45, 'Temperatura');
    return errores;
  }

  bool get esValido => validar().isEmpty;

  Map<String, Object?> toMap() => {
    'taSistolica': taSistolica,
    'taDiastolica': taDiastolica,
    'fc': fc,
    'fr': fr,
    'spo2': spo2,
    'temperatura': temperatura,
  };

  factory SignosVitales.fromMap(Map<String, Object?> m) => SignosVitales(
    taSistolica: m['taSistolica'] as int?,
    taDiastolica: m['taDiastolica'] as int?,
    fc: m['fc'] as int?,
    fr: m['fr'] as int?,
    spo2: m['spo2'] as int?,
    temperatura: (m['temperatura'] as num?)?.toDouble(),
  );

  /// Texto con las siglas aprobadas, por ejemplo
  /// `TA 120/80 mmHg, FC 80 lpm, FR 18 rpm, SpO2 95 %, T 36.8 °C`.
  String toTexto() {
    final partes = <String>[
      if (taSistolica != null && taDiastolica != null)
        'TA $taSistolica/$taDiastolica mmHg',
      if (fc != null) 'FC $fc lpm',
      if (fr != null) 'FR $fr rpm',
      if (spo2 != null) 'SpO2 $spo2 %',
      if (temperatura != null) 'T ${formatearTemperatura(temperatura!)} °C',
    ];
    return partes.isEmpty ? 'No registrados' : partes.join(', ');
  }

  static String formatearTemperatura(double t) =>
      t == t.roundToDouble() ? t.toStringAsFixed(0) : '$t';
}
