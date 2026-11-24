/// TSK-12 · HU03: cálculo del balance de líquidos para la entrega de turno.
library;

enum TipoIngreso {
  oral('Vía oral'),
  intravenoso('Intravenoso'),
  sonda('Sonda / enteral'),
  hemoderivados('Hemoderivados'),
  otro('Otro ingreso');

  const TipoIngreso(this.etiqueta);
  final String etiqueta;
}

enum TipoEgreso {
  diuresis('Diuresis'),
  drenajes('Drenajes'),
  vomito('Vómito'),
  deposiciones('Deposiciones'),
  otro('Otro egreso');

  const TipoEgreso(this.etiqueta);
  final String etiqueta;
}

/// mL/kg/h que se usan para estimar las pérdidas insensibles en adultos.
const double factorPerdidasInsensibles = 0.5;

class RegistroLiquidos {
  RegistroLiquidos({required this.horasTurno, this.pesoKg}) {
    if (horasTurno <= 0) {
      throw ArgumentError.value(horasTurno, 'horasTurno', 'debe ser > 0');
    }
    if (pesoKg != null && pesoKg! <= 0) {
      throw ArgumentError.value(pesoKg, 'pesoKg', 'debe ser > 0');
    }
  }

  final double horasTurno;
  final double? pesoKg;

  final Map<TipoIngreso, double> _ingresos = {};
  final Map<TipoEgreso, double> _egresos = {};

  Map<TipoIngreso, double> get ingresos => Map.unmodifiable(_ingresos);
  Map<TipoEgreso, double> get egresos => Map.unmodifiable(_egresos);

  void agregarIngreso(TipoIngreso tipo, double ml) {
    _validarVolumen(ml);
    _ingresos[tipo] = (_ingresos[tipo] ?? 0) + ml;
  }

  void agregarEgreso(TipoEgreso tipo, double ml) {
    _validarVolumen(ml);
    _egresos[tipo] = (_egresos[tipo] ?? 0) + ml;
  }

  static void _validarVolumen(double ml) {
    if (ml.isNaN || ml.isInfinite || ml < 0) {
      throw ArgumentError.value(ml, 'ml', 'el volumen debe ser >= 0');
    }
  }

  double get totalIngresos => _ingresos.values.fold(0, (a, b) => a + b);

  /// Pérdidas insensibles estimadas = peso × 0,5 × horas. Es 0 si no hay peso.
  double get perdidasInsensibles =>
      pesoKg == null ? 0 : pesoKg! * factorPerdidasInsensibles * horasTurno;

  /// Egresos medidos más las pérdidas insensibles.
  double get totalEgresos =>
      _egresos.values.fold<double>(0, (a, b) => a + b) + perdidasInsensibles;

  /// Positivo = retiene líquidos; negativo = pierde líquidos.
  double get balance => totalIngresos - totalEgresos;

  /// Gasto urinario en mL/kg/h. Es `null` si no hay peso registrado.
  double? get gastoUrinario => pesoKg == null
      ? null
      : (_egresos[TipoEgreso.diuresis] ?? 0) / pesoKg! / horasTurno;

  /// Alerta de oliguria en adultos (< 0,5 mL/kg/h).
  bool get oliguria {
    final g = gastoUrinario;
    return g != null && g < 0.5;
  }

  String resumen() {
    String f(double v) => v.toStringAsFixed(0);
    final signo = balance > 0 ? '+' : '';
    final b = StringBuffer()
      ..writeln('Balance de líquidos (${horasTurno.toStringAsFixed(0)} h)')
      ..writeln('Ingresos: ${f(totalIngresos)} mL')
      ..writeln('Egresos: ${f(totalEgresos)} mL'
          '${pesoKg != null ? ' (incluye ${f(perdidasInsensibles)} mL insensibles)' : ''}')
      ..write('Balance: $signo${f(balance)} mL');
    final g = gastoUrinario;
    if (g != null) {
      b.write('\nGasto urinario: ${g.toStringAsFixed(2)} mL/kg/h');
      if (oliguria) b.write(' — ALERTA: oliguria');
    }
    return b.toString();
  }
}
