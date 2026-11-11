/// TSK-06 / TSK-08 · HU02: pantalla de la escala de Downton con las
/// recomendaciones de cuidado cuando el riesgo es alto.
library;

import 'package:flutter/material.dart';

import '../recomendaciones_riesgo.dart';
import 'downton_escala.dart';

class DowntonScreen extends StatefulWidget {
  const DowntonScreen({
    super.key,
    this.inicial = const EvaluacionDownton(),
    this.onGuardar,
  });

  final EvaluacionDownton inicial;

  /// Se llama con la evaluación completa cuando el usuario pulsa Guardar.
  final ValueChanged<EvaluacionDownton>? onGuardar;

  @override
  State<DowntonScreen> createState() => _DowntonScreenState();
}

class _DowntonScreenState extends State<DowntonScreen> {
  late EvaluacionDownton _evaluacion = widget.inicial;

  @override
  Widget build(BuildContext context) {
    final titulo = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      appBar: AppBar(title: const Text('Escala de Downton')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          TarjetaRecomendaciones(
            titulo: 'Riesgo alto de caídas: recomendaciones',
            recomendaciones: recomendacionesDownton(_evaluacion),
          ),
          for (final categoria in CategoriaDownton.values)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(categoria.titulo, style: titulo),
                    ),
                    for (final f in FactorDownton.de(categoria))
                      CheckboxListTile(
                        key: Key('downton-${f.name}'),
                        value: _evaluacion.factores.contains(f),
                        title: Text(f.etiqueta),
                        onChanged: (v) => setState(
                          () => _evaluacion = _evaluacion.conFactor(
                            f,
                            v ?? false,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Deambulación', style: titulo),
                  ),
                  RadioGroup<DeambulacionDownton>(
                    groupValue: _evaluacion.deambulacion,
                    onChanged: (v) {
                      if (v != null) {
                        setState(
                          () => _evaluacion = _evaluacion.conDeambulacion(v),
                        );
                      }
                    },
                    child: Column(
                      children: [
                        for (final d in DeambulacionDownton.values)
                          RadioListTile<DeambulacionDownton>(
                            key: Key('downton-deambulacion-${d.name}'),
                            value: d,
                            title: Text(d.etiqueta),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _evaluacion.completa
                          ? 'Total: ${_evaluacion.total} / ${EvaluacionDownton.puntajeMaximo}'
                          : 'Seleccione la deambulación',
                      key: const Key('downton-total'),
                    ),
                    if (_evaluacion.completa)
                      Chip(
                        key: const Key('downton-nivel'),
                        label: Text(_evaluacion.etiquetaRiesgo),
                        backgroundColor: _evaluacion.riesgoAlto!
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                  ],
                ),
              ),
              FilledButton(
                key: const Key('downton-guardar'),
                onPressed: _evaluacion.completa && widget.onGuardar != null
                    ? () => widget.onGuardar!(_evaluacion)
                    : null,
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
