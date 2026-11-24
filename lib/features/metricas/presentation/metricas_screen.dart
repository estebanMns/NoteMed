/// Métricas de la fase de validación (Tabla 2): tasa de aceptación y de
/// edición de los borradores de la IA y tiempo de revisión. Se pueden copiar
/// en CSV para el informe.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:notemed/app/providers.dart';
import 'package:notemed/features/metricas/domain/metrica_nota.dart';

class MetricasScreen extends ConsumerWidget {
  const MetricasScreen({super.key});

  static String _pct(double? v) =>
      v == null ? '—' : '${v.toStringAsFixed(1)} %';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(resumenMetricasProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Métricas de validación'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(resumenMetricasProvider),
          ),
        ],
      ),
      body: resumen.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (r) => r.total == 0
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Todavía no hay notas firmadas. Las métricas se registran '
                    'automáticamente al firmar cada borrador de la IA.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _Contenido(r),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido(this.r);

  final ResumenMetricas r;

  @override
  Widget build(BuildContext context) {
    final seg = r.segundosRevisionPromedio;
    Widget dato(String key, String titulo, String valor, String detalle) =>
        Card(
          child: ListTile(
            key: Key(key),
            title: Text(titulo),
            subtitle: Text(detalle),
            trailing: Text(
              valor,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        dato(
          'met-total',
          'Notas firmadas',
          '${r.total}',
          'Borradores de la IA revisados y firmados',
        ),
        dato(
          'met-aceptacion',
          'Tasa de aceptación',
          MetricasScreen._pct(r.tasaAceptacion),
          '${r.aceptadasSinCambios} firmadas sin cambios',
        ),
        dato(
          'met-edicion',
          'Edición promedio',
          MetricasScreen._pct(r.edicionPromedio),
          'Palabras cambiadas respecto al borrador',
        ),
        dato(
          'met-revision',
          'Tiempo de revisión',
          seg == null ? '—' : '${(seg / 60).toStringAsFixed(1)} min',
          'Promedio con el borrador abierto hasta firmar',
        ),
        const SizedBox(height: 8),
        Text('Por tipo de nota', style: Theme.of(context).textTheme.titleSmall),
        for (final e in r.porTipo.entries)
          ListTile(
            dense: true,
            title: Text(e.key.etiqueta),
            trailing: Text('${e.value}'),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('met-csv'),
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Copiar datos en CSV'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: r.csv()));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Datos copiados')));
            }
          },
        ),
      ],
    );
  }
}
