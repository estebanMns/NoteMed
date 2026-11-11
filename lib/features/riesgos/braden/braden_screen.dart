/// TSK-05 · HU02: pantalla de la escala de Braden. Muestra las
/// recomendaciones de cuidado si el riesgo es alto (TSK-08).
library;

import 'package:flutter/material.dart';

import '../recomendaciones_riesgo.dart';
import 'braden_escala.dart';

class BradenScreen extends StatefulWidget {
  const BradenScreen({super.key, this.onGuardar});

  /// Se llama con la evaluación completa cuando el usuario pulsa Guardar.
  final ValueChanged<EvaluacionBraden>? onGuardar;

  @override
  State<BradenScreen> createState() => _BradenScreenState();
}

class _BradenScreenState extends State<BradenScreen> {
  EvaluacionBraden _evaluacion = const EvaluacionBraden();

  Color _colorNivel(NivelRiesgoBraden nivel) => switch (nivel) {
        NivelRiesgoBraden.muyAlto => Colors.red.shade700,
        NivelRiesgoBraden.alto => Colors.deepOrange,
        NivelRiesgoBraden.moderado => Colors.amber.shade800,
        NivelRiesgoBraden.bajo => Colors.lightGreen.shade700,
        NivelRiesgoBraden.sinRiesgo => Colors.green.shade700,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escala de Braden')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          TarjetaRecomendaciones(
            titulo: 'Riesgo de lesiones por presión: recomendaciones',
            recomendaciones: recomendacionesBraden(_evaluacion.nivel),
          ),
          for (final subescala in SubescalaBraden.values)
            _SubescalaCard(
              subescala: subescala,
              seleccionado: _evaluacion.puntajes[subescala],
              onChanged: (p) => setState(
                  () => _evaluacion = _evaluacion.conPuntaje(subescala, p)),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _Resumen(
            evaluacion: _evaluacion,
            color: _evaluacion.nivel == null
                ? Theme.of(context).colorScheme.outline
                : _colorNivel(_evaluacion.nivel!),
            onGuardar: _evaluacion.completa && widget.onGuardar != null
                ? () => widget.onGuardar!(_evaluacion)
                : null,
          ),
        ),
      ),
    );
  }
}

class _SubescalaCard extends StatelessWidget {
  const _SubescalaCard({
    required this.subescala,
    required this.seleccionado,
    required this.onChanged,
  });

  final SubescalaBraden subescala;
  final int? seleccionado;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(subescala.nombre,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            RadioGroup<int>(
              groupValue: seleccionado,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              child: Column(
                children: [
                  for (final o in subescala.opciones)
                    RadioListTile<int>(
                      key: Key('braden-${subescala.name}-${o.puntos}'),
                      value: o.puntos,
                      title: Text('${o.puntos} · ${o.titulo}'),
                      subtitle: Text(o.descripcion),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({
    required this.evaluacion,
    required this.color,
    required this.onGuardar,
  });

  final EvaluacionBraden evaluacion;
  final Color color;
  final VoidCallback? onGuardar;

  @override
  Widget build(BuildContext context) {
    final total = evaluacion.total;
    final texto = total == null
        ? 'Faltan ${evaluacion.pendientes.length} de 6 subescalas'
        : 'Total: $total / ${EvaluacionBraden.puntajeMaximo}';
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(texto, key: const Key('braden-total')),
              if (evaluacion.nivel != null)
                Chip(
                  key: const Key('braden-nivel'),
                  label: Text(evaluacion.nivel!.etiqueta),
                  backgroundColor: color,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
            ],
          ),
        ),
        FilledButton(onPressed: onGuardar, child: const Text('Guardar')),
      ],
    );
  }
}
