/// Cuestionario PROM: el paciente califica de 0 a 10 cada ítem. Se responde
/// tocando un número (sin teclado). Si no puede responder se registra el
/// motivo.
library;

import 'package:material_ui/material_ui.dart';

import 'package:notemed/features/valoracion/domain/prom/evaluacion_prom.dart';

class PromScreen extends StatefulWidget {
  const PromScreen({
    super.key,
    this.inicial = const EvaluacionProm(),
    required this.onGuardar,
  });

  final EvaluacionProm inicial;
  final Future<void> Function(EvaluacionProm e) onGuardar;

  @override
  State<PromScreen> createState() => _PromScreenState();
}

class _PromScreenState extends State<PromScreen> {
  late EvaluacionProm _e = widget.inicial;
  bool _guardando = false;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await widget.onGuardar(_e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final alertas = _e.alertas;
    return Scaffold(
      appBar: AppBar(title: const Text('Reportado por el paciente')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Pregunte al paciente y marque el número que indique: 0 es nada '
            'y 10 es lo peor que pueda imaginar.',
            style: TextStyle(color: esquema.onSurfaceVariant),
          ),
          SwitchListTile(
            key: const Key('prom-puede'),
            contentPadding: EdgeInsets.zero,
            title: const Text('El paciente puede responder'),
            value: _e.puedeResponder,
            onChanged: (v) => setState(() => _e = _e.conPuedeResponder(v)),
          ),
          if (!_e.puedeResponder) ...[
            Text('Motivo', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final m in MotivoNoResponde.values)
                  ChoiceChip(
                    key: Key('prom-motivo-${m.name}'),
                    label: Text(m.etiqueta),
                    selected: _e.motivo == m,
                    onSelected: (_) => setState(() => _e = _e.conMotivo(m)),
                  ),
              ],
            ),
          ] else
            for (final item in ItemProm.values)
              _ItemCard(
                item: item,
                valor: _e.respuestas[item],
                onChanged: (v) => setState(() => _e = _e.conRespuesta(item, v)),
              ),
          if (alertas.isNotEmpty)
            Card(
              key: const Key('prom-alertas'),
              color: esquema.errorContainer,
              child: ListTile(
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: esquema.onErrorContainer,
                ),
                title: Text(
                  'Valores altos: ${alertas.join(', ')}',
                  style: TextStyle(color: esquema.onErrorContainer),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            key: const Key('prom-guardar'),
            onPressed: _e.completa && !_guardando ? _guardar : null,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              _e.completa
                  ? 'Guardar'
                  : _e.puedeResponder
                  ? 'Faltan ${_e.pendientes.length} de ${ItemProm.values.length}'
                  : 'Seleccione el motivo',
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.valor,
    required this.onChanged,
  });

  final ItemProm item;
  final int? valor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.etiqueta, style: Theme.of(context).textTheme.titleSmall),
            Text(item.pregunta),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (
                  var v = EvaluacionProm.minimo;
                  v <= EvaluacionProm.maximo;
                  v++
                )
                  ChoiceChip(
                    key: Key('prom-${item.name}-$v'),
                    label: Text('$v'),
                    showCheckmark: false,
                    selected: valor == v,
                    onSelected: (_) => onChanged(v),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
