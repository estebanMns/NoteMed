/// TSK-19 · HU05: firma digital y tarjeta profesional de la enfermera.
library;

/// Punto de un trazo de la firma, en píxeles lógicos del lienzo. Es propio
/// del dominio para no depender de Flutter (`Offset`).
class PuntoFirma {
  const PuntoFirma(this.x, this.y);

  static const PuntoFirma cero = PuntoFirma(0, 0);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is PuntoFirma && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'PuntoFirma($x, $y)';
}

class FirmaEnfermera {
  const FirmaEnfermera({
    required this.trazos,
    required this.tarjetaProfesional,
    required this.fecha,
  });

  /// Cada trazo es la lista de puntos de un movimiento del dedo.
  final List<List<PuntoFirma>> trazos;
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
  static bool trazosValidos(List<List<PuntoFirma>> trazos) =>
      trazos.any((t) => t.length >= 2);

  bool get esValida =>
      trazosValidos(trazos) && validarTarjeta(tarjetaProfesional) == null;

  Map<String, Object?> toMap() => {
    'trazos': [
      for (final t in trazos)
        [
          for (final p in t) [p.x, p.y],
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
            PuntoFirma(
              ((p as List)[0] as num).toDouble(),
              (p[1] as num).toDouble(),
            ),
        ],
    ],
    tarjetaProfesional: m['tarjetaProfesional']! as String,
    fecha: DateTime.parse(m['fecha']! as String),
  );
}
