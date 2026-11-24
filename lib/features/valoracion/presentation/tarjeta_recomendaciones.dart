/// TSK-08 · HU02: tarjeta con las recomendaciones de cuidado.
library;

import 'package:material_ui/material_ui.dart';

/// Tarjeta que se muestra en pantalla cuando hay recomendaciones.
class TarjetaRecomendaciones extends StatelessWidget {
  const TarjetaRecomendaciones({
    super.key,
    required this.titulo,
    required this.recomendaciones,
  });

  final String titulo;
  final List<String> recomendaciones;

  @override
  Widget build(BuildContext context) {
    if (recomendaciones.isEmpty) return const SizedBox.shrink();
    final esquema = Theme.of(context).colorScheme;
    return Card(
      key: const Key('recomendaciones'),
      color: esquema.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: esquema.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: esquema.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final r in recomendaciones)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $r',
                  style: TextStyle(color: esquema.onErrorContainer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
