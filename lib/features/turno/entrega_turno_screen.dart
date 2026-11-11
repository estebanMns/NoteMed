/// HU03: pantalla de recibo y entrega de turno. Reúne la plantilla SBAR
/// (TSK-10) y el balance de líquidos (TSK-12).
library;

import 'package:flutter/material.dart';

import 'balance_liquidos.dart';
import 'sbar_form.dart';
import 'sbar_plantilla.dart';

class EntregaTurnoScreen extends StatefulWidget {
  const EntregaTurnoScreen({super.key, this.onGuardar});

  final void Function(NotaSbar nota, RegistroLiquidos? liquidos)? onGuardar;

  @override
  State<EntregaTurnoScreen> createState() => _EntregaTurnoScreenState();
}

class _EntregaTurnoScreenState extends State<EntregaTurnoScreen> {
  double _horas = 12;
  double? _peso;
  final Map<TipoIngreso, double> _ingresos = {};
  final Map<TipoEgreso, double> _egresos = {};

  RegistroLiquidos? get _registro {
    try {
      final r = RegistroLiquidos(horasTurno: _horas, pesoKg: _peso);
      _ingresos.forEach(r.agregarIngreso);
      _egresos.forEach(r.agregarEgreso);
      return r;
    } on ArgumentError {
      return null;
    }
  }

  double? _numero(String v) => double.tryParse(v.replaceAll(',', '.'));

  Widget _campoMl(String etiqueta, String key, ValueChanged<double?> onChanged) {
    return SizedBox(
      width: 160,
      child: TextField(
        key: Key(key),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: etiqueta,
          suffixText: 'mL',
          isDense: true,
        ),
        onChanged: (v) => setState(() => onChanged(_numero(v))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final registro = _registro;
    final titulo = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      appBar: AppBar(title: const Text('Entrega de turno')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Balance de líquidos', style: titulo),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 160,
                child: TextField(
                  key: const Key('liq-peso'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Peso', suffixText: 'kg', isDense: true),
                  onChanged: (v) => setState(() => _peso = _numero(v)),
                ),
              ),
              DropdownMenu<double>(
                initialSelection: _horas,
                label: const Text('Turno'),
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 6, label: '6 h'),
                  DropdownMenuEntry(value: 8, label: '8 h'),
                  DropdownMenuEntry(value: 12, label: '12 h'),
                  DropdownMenuEntry(value: 24, label: '24 h'),
                ],
                onSelected: (v) => setState(() => _horas = v ?? _horas),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Ingresos', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final t in TipoIngreso.values)
              _campoMl(t.etiqueta, 'liq-in-${t.name}', (v) {
                if (v == null) {
                  _ingresos.remove(t);
                } else {
                  _ingresos[t] = v;
                }
              }),
          ]),
          const SizedBox(height: 12),
          Text('Egresos', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final t in TipoEgreso.values)
              _campoMl(t.etiqueta, 'liq-out-${t.name}', (v) {
                if (v == null) {
                  _egresos.remove(t);
                } else {
                  _egresos[t] = v;
                }
              }),
          ]),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                registro?.resumen() ?? 'Revise los valores: no se aceptan negativos.',
                key: const Key('liq-resumen'),
              ),
            ),
          ),
          const Divider(height: 32),
          Text('Nota SBAR', style: titulo),
          const SizedBox(height: 8),
          SbarForm(
            onGuardar: (nota) {
              widget.onGuardar?.call(nota, registro);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nota de entrega guardada')),
              );
            },
          ),
        ],
      ),
    );
  }
}
