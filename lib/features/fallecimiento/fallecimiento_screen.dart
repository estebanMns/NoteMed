/// TSK-15 · HU04: datos objetivos del fallecimiento que se envían a la IA.
library;

import 'package:flutter/material.dart';

import '../procedimientos/procedimiento_invasivo.dart';
import 'nota_fallecimiento.dart';

class FallecimientoScreen extends StatefulWidget {
  const FallecimientoScreen({
    super.key,
    required this.onGenerar,
    this.ahora = DateTime.now,
  });

  final Future<void> Function(DatosFallecimiento datos) onGenerar;
  final DateTime Function() ahora;

  @override
  State<FallecimientoScreen> createState() => _FallecimientoScreenState();
}

class _FallecimientoScreenState extends State<FallecimientoScreen> {
  late DateTime _fechaHora = widget.ahora();
  final _certifica = TextEditingController();
  final _duracion = TextEditingController();
  final _entregaA = TextEditingController();
  final _observaciones = TextEditingController();
  final Set<String> _signos = {};
  final Set<String> _cuidados = {};
  bool _reanimacion = false;
  bool _generando = false;
  List<String> _errores = const [];

  @override
  void dispose() {
    for (final c in [_certifica, _duracion, _entregaA, _observaciones]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFechaHora() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaHora,
      firstDate: widget.ahora().subtract(const Duration(days: 7)),
      lastDate: widget.ahora(),
    );
    if (fecha == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaHora),
    );
    if (hora == null) return;
    setState(
      () => _fechaHora = DateTime(
        fecha.year,
        fecha.month,
        fecha.day,
        hora.hour,
        hora.minute,
      ),
    );
  }

  Future<void> _generar() async {
    final datos = DatosFallecimiento(
      fechaHora: _fechaHora,
      quienCertifica: _certifica.text.trim(),
      signosObservados: [
        for (final s in signosDeMuerte)
          if (_signos.contains(s)) s,
      ],
      reanimacion: _reanimacion,
      duracionReanimacionMin: _reanimacion
          ? int.tryParse(_duracion.text.trim())
          : null,
      cuidadosRealizados: [
        for (final c in cuidadosPostMortem)
          if (_cuidados.contains(c)) c,
      ],
      entregaA: _entregaA.text.trim().isEmpty ? null : _entregaA.text.trim(),
      observaciones: _observaciones.text.trim(),
    );
    final errores = datos.validar();
    setState(() => _errores = errores);
    if (errores.isNotEmpty) return;
    setState(() => _generando = true);
    try {
      await widget.onGenerar(datos);
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const borde = OutlineInputBorder();
    final titulo = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      appBar: AppBar(title: const Text('Nota de fallecimiento')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(
              formatearFechaHora(_fechaHora),
              key: const Key('fall-fecha'),
            ),
            subtitle: const Text('Fecha y hora del fallecimiento'),
            trailing: TextButton(
              onPressed: _elegirFechaHora,
              child: const Text('Cambiar'),
            ),
          ),
          TextField(
            key: const Key('fall-certifica'),
            controller: _certifica,
            decoration: const InputDecoration(
              labelText: 'Certificado por (cargo)',
              helperText: 'Ejemplo: médico de turno',
              border: borde,
            ),
          ),
          const SizedBox(height: 16),
          Text('Signos observados', style: titulo),
          for (final s in signosDeMuerte)
            CheckboxListTile(
              key: Key('fall-signo-${signosDeMuerte.indexOf(s)}'),
              value: _signos.contains(s),
              title: Text(s),
              onChanged: (v) => setState(
                () => v == true ? _signos.add(s) : _signos.remove(s),
              ),
            ),
          SwitchListTile(
            key: const Key('fall-reanimacion'),
            value: _reanimacion,
            title: const Text('Se realizaron maniobras de reanimación'),
            onChanged: (v) => setState(() => _reanimacion = v),
          ),
          if (_reanimacion)
            TextField(
              key: const Key('fall-duracion'),
              controller: _duracion,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duración',
                suffixText: 'min',
                border: borde,
              ),
            ),
          const SizedBox(height: 16),
          Text('Cuidados post mortem realizados', style: titulo),
          for (final c in cuidadosPostMortem)
            CheckboxListTile(
              key: Key('fall-cuidado-${cuidadosPostMortem.indexOf(c)}'),
              value: _cuidados.contains(c),
              title: Text(c),
              onChanged: (v) => setState(
                () => v == true ? _cuidados.add(c) : _cuidados.remove(c),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('fall-entrega'),
            controller: _entregaA,
            decoration: const InputDecoration(
              labelText: 'Se informó / entregó a (parentesco o cargo)',
              border: borde,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('fall-observaciones'),
            controller: _observaciones,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Observaciones (opcional)',
              border: borde,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Junto al botón, para que se vean sin desplazarse.
              for (final e in _errores)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    e,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton.icon(
                key: const Key('fall-generar'),
                onPressed: _generando ? null : _generar,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(_generando ? 'Generando…' : 'Generar nota'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
