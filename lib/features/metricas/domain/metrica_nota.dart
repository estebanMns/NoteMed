/// Métricas de la fase de validación (objetivo específico 4, Tabla 2):
/// tasa de aceptación del borrador de la IA y tasa de edición. Se registran
/// automáticamente al firmar cada nota generada por IA. No contienen datos
/// del paciente ni el texto de la nota.
library;

import 'package:notemed/features/notas/domain/nota_clinica.dart';

class MetricaNota {
  const MetricaNota({
    this.id,
    required this.notaId,
    required this.tipo,
    required this.generada,
    required this.firmada,
    required this.palabrasBorrador,
    required this.porcentajeEdicion,
    this.segundosRevision,
    this.versionPrompts,
  });

  /// Métrica de una nota que pasó de [borrador] (texto de la IA) a
  /// [firmada] (texto final de la enfermera).
  factory MetricaNota.de(
    NotaClinica borrador,
    NotaClinica firmada, {
    Duration? tiempoRevision,
  }) => MetricaNota(
    notaId: firmada.id!,
    tipo: firmada.tipo,
    generada: borrador.creada,
    firmada: firmada.firma!.fecha,
    palabrasBorrador: palabras(borrador.texto).length,
    porcentajeEdicion: porcentajeEdicionEntre(borrador.texto, firmada.texto),
    segundosRevision: tiempoRevision?.inSeconds,
    versionPrompts: firmada.versionPrompts,
  );

  final int? id;
  final int notaId;
  final TipoNota tipo;
  final DateTime generada;
  final DateTime firmada;
  final int palabrasBorrador;

  /// 0 = se firmó tal cual; 100 = se reescribió todo.
  final double porcentajeEdicion;

  /// Tiempo con el borrador abierto hasta firmar.
  final int? segundosRevision;
  final String? versionPrompts;

  bool get aceptadaSinCambios => porcentajeEdicion == 0;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'nota_id': notaId,
    'tipo': tipo.name,
    'generada': generada.toIso8601String(),
    'firmada': firmada.toIso8601String(),
    'palabras_borrador': palabrasBorrador,
    'porcentaje_edicion': porcentajeEdicion,
    'segundos_revision': segundosRevision,
    'version_prompts': versionPrompts,
  };

  factory MetricaNota.fromMap(Map<String, Object?> m) => MetricaNota(
    id: m['id'] as int?,
    notaId: m['nota_id']! as int,
    tipo: TipoNota.values.byName(m['tipo']! as String),
    generada: DateTime.parse(m['generada']! as String),
    firmada: DateTime.parse(m['firmada']! as String),
    palabrasBorrador: m['palabras_borrador']! as int,
    porcentajeEdicion: (m['porcentaje_edicion']! as num).toDouble(),
    segundosRevision: m['segundos_revision'] as int?,
    versionPrompts: m['version_prompts'] as String?,
  );

  static const columnasCsv = [
    'nota_id',
    'tipo',
    'generada',
    'firmada',
    'palabras_borrador',
    'porcentaje_edicion',
    'segundos_revision',
    'version_prompts',
  ];

  String filaCsv() => [
    notaId,
    tipo.name,
    generada.toIso8601String(),
    firmada.toIso8601String(),
    palabrasBorrador,
    porcentajeEdicion.toStringAsFixed(1),
    segundosRevision ?? '',
    versionPrompts ?? '',
  ].join(',');
}

List<String> palabras(String texto) =>
    texto.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

/// Distancia de edición por palabras (Levenshtein) dividida por la longitud
/// del texto más largo, en porcentaje.
double porcentajeEdicionEntre(String original, String editado) {
  final a = palabras(original);
  final b = palabras(editado);
  final mayor = a.length > b.length ? a.length : b.length;
  if (mayor == 0) return 0;
  var previa = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final actual = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final costo = a[i - 1] == b[j - 1] ? 0 : 1;
      final borrar = previa[j] + 1;
      final insertar = actual[j - 1] + 1;
      final cambiar = previa[j - 1] + costo;
      actual[j] = [borrar, insertar, cambiar].reduce((x, y) => x < y ? x : y);
    }
    previa = actual;
  }
  return previa[b.length] * 100 / mayor;
}

/// Resumen para la pantalla de métricas y el informe de validación.
class ResumenMetricas {
  ResumenMetricas(this.metricas);

  final List<MetricaNota> metricas;

  int get total => metricas.length;

  int get aceptadasSinCambios =>
      metricas.where((m) => m.aceptadaSinCambios).length;

  /// Porcentaje de borradores firmados sin cambios.
  double? get tasaAceptacion =>
      total == 0 ? null : aceptadasSinCambios * 100 / total;

  /// Porcentaje promedio de edición.
  double? get edicionPromedio => total == 0
      ? null
      : metricas.fold<double>(0, (s, m) => s + m.porcentajeEdicion) / total;

  double? get segundosRevisionPromedio {
    final con = [
      for (final m in metricas)
        if (m.segundosRevision != null) m.segundosRevision!,
    ];
    return con.isEmpty ? null : con.reduce((a, b) => a + b) / con.length;
  }

  Map<TipoNota, int> get porTipo => {
    for (final t in TipoNota.values)
      if (metricas.any((m) => m.tipo == t))
        t: metricas.where((m) => m.tipo == t).length,
  };

  String csv() => [
    MetricaNota.columnasCsv.join(','),
    for (final m in metricas) m.filaCsv(),
  ].join('\n');
}
