/// TSK-30 · HU08: enmascaramiento y anonimización de datos (Ley 1581 de 2012).
///
/// Cambia los identificadores directos del paciente por códigos:
///  * nombres → `PAC-###`
///  * cédulas / documentos (6 a 10 dígitos, con o sin puntos) → `ID-###`
///  * cama o habitación → `CAMA-###`
///
/// Dentro de una misma instancia el mapeo es determinista: el mismo dato
/// recibe siempre el mismo código. La tabla para reidentificar queda solo
/// en memoria y nunca se escribe en el texto de salida.
library;

class Anonimizador {
  Anonimizador();

  final Map<String, String> _tabla = {};
  final Map<String, int> _contadores = {};

  static const _letra = r'[\p{L}\p{N}]';
  static const _noLetraAntes = '(?<!$_letra)';
  static const _noLetraDespues = '(?!$_letra)';

  // Solo se reemplaza el número; el prefijo ("C.C.", "cédula"…) se conserva.
  static final RegExp _documento = RegExp(
    '$_noLetraAntes'
    r'(?:\d{1,3}(?:\.\d{3}){2,3}|\d{6,10})'
    '$_noLetraDespues',
    unicode: true,
  );

  static final RegExp _cama = RegExp(
    '$_noLetraAntes'
    r'(?:cama|habitaci[oó]n|hab\.)\s*(?:n(?:o\.?|[°º]|\.)\s*)?[A-Za-z]?-?\d+[A-Za-z]?'
    '$_noLetraDespues',
    caseSensitive: false,
    unicode: true,
  );

  // Tratamientos de cortesía seguidos de 1 a 3 palabras con mayúscula.
  static final RegExp _tratamiento = RegExp(
    '$_noLetraAntes'
    r'(?:Sr\.|Sra\.|Srta\.|señor|señora|señorita|don|doña|Don|Doña|Señor|Señora)'
    r'\s+((?:\p{Lu}\p{Ll}+)(?:\s+\p{Lu}\p{Ll}+){0,2})',
    unicode: true,
  );

  /// Vista de solo lectura de la tabla original → código. Es para uso
  /// autorizado y no se debe persistir junto a la nota.
  Map<String, String> get tablaReidentificacion => Map.unmodifiable(_tabla);

  String _codigo(String prefijo, String clave) {
    final k = '$prefijo|$clave';
    return _tabla.putIfAbsent(k, () {
      final n = (_contadores[prefijo] ?? 0) + 1;
      _contadores[prefijo] = n;
      return '$prefijo-${n.toString().padLeft(3, '0')}';
    });
  }

  /// Anonimiza [texto]. [nombresConocidos] son los nombres completos de los
  /// pacientes de la nota. También se reemplaza cada nombre o apellido suelto
  /// de 3 letras o más.
  String anonimizar(String texto, {Iterable<String> nombresConocidos = const []}) {
    var salida = texto;

    // 1. Nombres conocidos: primero el nombre completo y después cada parte
    //    (ignora mayúsculas y tildes).
    for (final nombre in nombresConocidos) {
      final partes = nombre.trim().split(RegExp(r'\s+'))
        ..removeWhere((p) => p.isEmpty);
      if (partes.isEmpty) continue;
      final codigo = _codigo('PAC', normalizar(partes.join(' ')));
      final candidatos = <String>[
        partes.join(' '),
        ...partes.where(_esParteIdentificable),
      ];
      for (final c in candidatos) {
        salida = salida.replaceAll(_patronFlexible(c), codigo);
      }
    }

    // 2. Nombres precedidos de un tratamiento ("la señora Martínez").
    salida = salida.replaceAllMapped(_tratamiento, (m) {
      final completo = m[0]!;
      final nombre = m[1]!;
      final tratamiento = completo.substring(0, completo.length - nombre.length);
      return '$tratamiento${_codigo('PAC', normalizar(nombre))}';
    });

    // 3. Cama/habitación (antes que los documentos, para no tomar números de cama).
    salida = salida.replaceAllMapped(_cama, (m) {
      final numero = RegExp(r'[A-Za-z]?-?\d+[A-Za-z]?$').firstMatch(m[0]!)![0]!;
      return _codigo('CAMA', numero.toUpperCase().replaceAll('-', ''));
    });

    // 4. Documentos de identidad.
    salida = salida.replaceAllMapped(
      _documento,
      (m) => _codigo('ID', m[0]!.replaceAll('.', '')),
    );

    return salida;
  }

  /// `true` si [texto] todavía contiene algo que parezca un documento, una
  /// cama o alguno de los [nombres]. Sirve para verificar antes de exportar.
  static bool contieneDatosPersonales(String texto,
      {Iterable<String> nombres = const []}) {
    if (_documento.hasMatch(texto) || _cama.hasMatch(texto)) return true;
    for (final n in nombres) {
      for (final p in n.split(RegExp(r'\s+')).where(_esParteIdentificable)) {
        if (_patronFlexible(p).hasMatch(texto)) return true;
      }
    }
    return false;
  }

  /// Partículas de nombres compuestos que no se reemplazan solas, porque
  /// también son palabras comunes del texto clínico.
  static const _particulas = {'del', 'las', 'los', 'san', 'santa', 'van', 'von'};

  static bool _esParteIdentificable(String parte) =>
      parte.length >= 3 && !_particulas.contains(normalizar(parte));

  /// Minúsculas y sin tildes, para comparar.
  static String normalizar(String s) {
    const con = 'áéíóúüñÁÉÍÓÚÜÑ';
    const sin = 'aeiouunAEIOUUN';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = con.indexOf(ch);
      b.write(i >= 0 ? sin[i] : ch);
    }
    return b.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Regex que reconoce [palabra] sin importar mayúsculas ni tildes, como
  /// palabra completa.
  static RegExp _patronFlexible(String palabra) {
    const clases = {
      'a': '[aáAÁ]',
      'e': '[eéEÉ]',
      'i': '[iíIÍ]',
      'o': '[oóOÓ]',
      'u': '[uúüUÚÜ]',
      'n': '[nñNÑ]',
    };
    final b = StringBuffer(_noLetraAntes);
    for (final ch in normalizar(palabra).split('')) {
      if (ch == ' ') {
        b.write(r'\s+');
      } else {
        b.write(clases[ch] ?? RegExp.escape(ch));
      }
    }
    b.write(_noLetraDespues);
    return RegExp(b.toString(), caseSensitive: false, unicode: true);
  }
}
