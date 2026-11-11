/// TSK-19 · HU05: firma digital y tarjeta profesional de la enfermera.
library;

import 'dart:ui' show Offset;

class FirmaEnfermera {
  const FirmaEnfermera({
    required this.trazos,
    required this.tarjetaProfesional,
    required this.fecha,
  });

  /// Cada trazo es la lista de puntos de un movimiento del dedo.
  final List<List<Offset>> trazos;
  final String tarjetaProfesional;
  final DateTime fecha;

  /// Letras, números y guiones; de 4 a 20 caracteres.
  static String? validarTarjeta(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'La tarjeta profesional es obligatoria';
    if (!RegExp(r'^[A-Za-z0-9-]{4,20}$').hasMatch(t)) {
      return 'Use de 4 a 20 letras, números o guiones';
    }
    return null;
  }

  /// Una firma necesita al menos un trazo con dos puntos.
  static bool trazosValidos(List<List<Offset>> trazos) =>
      trazos.any((t) => t.length >= 2);

  bool get esValida =>
      trazosValidos(trazos) && validarTarjeta(tarjetaProfesional) == null;

  Map<String, Object?> toMap() => {
    'trazos': [
      for (final t in trazos)
        [
          for (final p in t) [p.dx, p.dy],
        ],
    ],
    'tarjetaProfesional': tarjetaProfesional,
    'fecha': fecha.toIso8601String(),
  };

  factory FirmaEnfermera.fromMap(Map<String, Object?> m) => FirmaEnfermera(
    trazos: [
      for (final t in m['trazos']! as List)
        [
          for (final p in t as List)
            Offset(
              ((p as List)[0] as num).toDouble(),
              (p[1] as num).toDouble(),
            ),
        ],
    ],
    tarjetaProfesional: m['tarjetaProfesional']! as String,
    fecha: DateTime.parse(m['fecha']! as String),
  );
}
