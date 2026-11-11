/// TSK-23 · HU06: regla de control que verifica que el texto generado por la
/// IA tenga exactamente los signos vitales que registró la enfermera.
///
/// Se reportan tres casos:
///  * [TipoDiscrepancia.diferente]: el texto trae otro valor.
///  * [TipoDiscrepancia.noRegistrado]: el texto trae un valor que la
///    enfermera no registró (dato inventado).
///  * [TipoDiscrepancia.omitido]: se registró el valor y el texto no lo
///    menciona.
library;

import '../../features/paciente/signos_vitales.dart';

enum SignoVital {
  ta('TA'),
  fc('FC'),
  fr('FR'),
  spo2('SpO2'),
  temperatura('Temperatura');

  const SignoVital(this.etiqueta);
  final String etiqueta;
}

enum TipoDiscrepancia { diferente, noRegistrado, omitido }

class Discrepancia {
  const Discrepancia({
    required this.signo,
    required this.tipo,
    this.esperado,
    this.encontrado,
  });

  final SignoVital signo;
  final TipoDiscrepancia tipo;
  final String? esperado;
  final String? encontrado;

  String get mensaje => switch (tipo) {
    TipoDiscrepancia.diferente =>
      '${signo.etiqueta}: el texto dice $encontrado pero se registró $esperado.',
    TipoDiscrepancia.noRegistrado =>
      '${signo.etiqueta}: el texto dice $encontrado pero no se registró ningún valor.',
    TipoDiscrepancia.omitido =>
      '${signo.etiqueta}: se registró $esperado y el texto no lo menciona.',
  };

  @override
  String toString() =>
      'Discrepancia(${signo.name}, ${tipo.name}, '
      'esperado: $esperado, encontrado: $encontrado)';
}

class VerificadorSignosVitales {
  const VerificadorSignosVitales();

  static const _antes = r'(?<![\p{L}\p{N}])';
  static const _despues = r'(?![\p{L}])';
  static const _union = r'\s*(?:de|es|en|:|=)?\s*';

  // Las siglas se comparan con mayúsculas para no confundir "FR" con el
  // calibre "Fr 16" de una sonda.
  static final Map<SignoVital, RegExp> _patrones = {
    SignoVital.ta: RegExp(
      '$_antes(?:TA|T\\.A\\.|[Tt]ensi[oó]n arterial|[Pp]resi[oó]n arterial)'
      '$_despues$_union(\\d{2,3})\\s*/\\s*(\\d{2,3})',
      unicode: true,
    ),
    SignoVital.fc: RegExp(
      '$_antes(?:FC|[Ff]recuencia card[ií]aca)$_despues$_union(\\d{1,3})(?![\\d/])',
      unicode: true,
    ),
    SignoVital.fr: RegExp(
      '$_antes(?:FR|[Ff]recuencia respiratoria)$_despues$_union(\\d{1,3})(?![\\d/])',
      unicode: true,
    ),
    SignoVital.spo2: RegExp(
      '$_antes(?:SpO2|SatO2|SpO₂|[Ss]aturaci[oó]n(?: de ox[ií]geno)?)'
      '$_despues$_union(\\d{2,3})(?![\\d/])',
      unicode: true,
    ),
    SignoVital.temperatura: RegExp(
      '$_antes(?:[Tt]emperatura|[Tt]emp\\.|T°|T)(?![\\p{L}])$_union'
      '(\\d{2}(?:[.,]\\d{1,2})?)(?![\\d/])',
      unicode: true,
    ),
  };

  /// Valores que menciona [texto] para cada signo, normalizados como texto
  /// (la TA como `120/80`, la temperatura con punto decimal).
  Map<SignoVital, List<String>> extraer(String texto) => {
    for (final e in _patrones.entries)
      e.key: [
        for (final m in e.value.allMatches(texto))
          e.key == SignoVital.ta
              ? '${int.parse(m[1]!)}/${int.parse(m[2]!)}'
              : e.key == SignoVital.temperatura
              ? _temperatura(double.parse(m[1]!.replaceAll(',', '.')))
              : '${int.parse(m[1]!)}',
      ],
  };

  static String _temperatura(double t) => SignosVitales.formatearTemperatura(t);

  static Map<SignoVital, String?> _esperados(SignosVitales s) => {
    SignoVital.ta: s.taSistolica != null && s.taDiastolica != null
        ? '${s.taSistolica}/${s.taDiastolica}'
        : null,
    SignoVital.fc: s.fc?.toString(),
    SignoVital.fr: s.fr?.toString(),
    SignoVital.spo2: s.spo2?.toString(),
    SignoVital.temperatura: s.temperatura == null
        ? null
        : _temperatura(s.temperatura!),
  };

  /// Discrepancias entre [texto] y [signos]. Vacía si concuerdan.
  List<Discrepancia> verificar(String texto, SignosVitales signos) {
    final encontrados = extraer(texto);
    final esperados = _esperados(signos);
    final resultado = <Discrepancia>[];
    for (final signo in SignoVital.values) {
      final esperado = esperados[signo];
      final valores = encontrados[signo]!;
      if (esperado != null && valores.isEmpty) {
        resultado.add(
          Discrepancia(
            signo: signo,
            tipo: TipoDiscrepancia.omitido,
            esperado: esperado,
          ),
        );
      }
      for (final v in valores.toSet()) {
        if (esperado == null) {
          resultado.add(
            Discrepancia(
              signo: signo,
              tipo: TipoDiscrepancia.noRegistrado,
              encontrado: v,
            ),
          );
        } else if (v != esperado) {
          resultado.add(
            Discrepancia(
              signo: signo,
              tipo: TipoDiscrepancia.diferente,
              esperado: esperado,
              encontrado: v,
            ),
          );
        }
      }
    }
    return resultado;
  }

  /// `true` si no hay valores diferentes ni inventados. Las omisiones se
  /// muestran como advertencia pero no invalidan el texto.
  bool concuerda(String texto, SignosVitales signos) =>
      verificar(texto, signos).every((d) => d.tipo == TipoDiscrepancia.omitido);
}
