/// TSK-03 · HU01: campos para registrar dosis y ritmo de las infusiones.
library;

import 'package:flutter/material.dart';

import 'infusion.dart';

class InfusionesForm extends StatefulWidget {
  const InfusionesForm({
    super.key,
    required this.infusiones,
    required this.onAgregar,
    required this.onEliminar,
  });

  final List<Infusion> infusiones;
  final ValueChanged<Infusion> onAgregar;
  final ValueChanged<Infusion> onEliminar;

  @override
  State<InfusionesForm> createState() => _InfusionesFormState();
}

class _InfusionesFormState extends State<InfusionesForm> {
  final _formKey = GlobalKey<FormState>();
  final _medicamento = TextEditingController();
  final _dosis = TextEditingController();
  final _ritmo = TextEditingController();
  final _concentracion = TextEditingController();
  UnidadDosis _unidad = UnidadDosis.mg;

  @override
  void dispose() {
    for (final c in [_medicamento, _dosis, _ritmo, _concentracion]) {
      c.dispose();
    }
    super.dispose();
  }

  void _agregar() {
    if (!_formKey.currentState!.validate()) return;
    widget.onAgregar(
      Infusion(
        medicamento: _medicamento.text.trim(),
        dosis: Infusion.leerNumero(_dosis.text)!,
        unidad: _unidad,
        ritmoMlH: Infusion.leerNumero(_ritmo.text)!,
        concentracion: _concentracion.text.trim().isEmpty
            ? null
            : _concentracion.text.trim(),
      ),
    );
    for (final c in [_medicamento, _dosis, _ritmo, _concentracion]) {
      c.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    const numero = TextInputType.numberWithOptions(decimal: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final i in widget.infusiones)
          Card(
            child: ListTile(
              key: Key('infusion-${i.id ?? i.medicamento}'),
              leading: const Icon(Icons.water_drop_outlined),
              title: Text(i.toTexto()),
              trailing: IconButton(
                tooltip: 'Eliminar infusión',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => widget.onEliminar(i),
              ),
            ),
          ),
        Form(
          key: _formKey,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: TextFormField(
                  key: const Key('inf-medicamento'),
                  controller: _medicamento,
                  decoration: const InputDecoration(
                    labelText: 'Medicamento',
                    isDense: true,
                  ),
                  validator: Infusion.validarMedicamento,
                ),
              ),
              SizedBox(
                width: 110,
                child: TextFormField(
                  key: const Key('inf-dosis'),
                  controller: _dosis,
                  keyboardType: numero,
                  decoration: const InputDecoration(
                    labelText: 'Dosis',
                    isDense: true,
                  ),
                  validator: Infusion.validarDosis,
                ),
              ),
              DropdownMenu<UnidadDosis>(
                key: const Key('inf-unidad'),
                initialSelection: _unidad,
                label: const Text('Unidad'),
                dropdownMenuEntries: [
                  for (final u in UnidadDosis.values)
                    DropdownMenuEntry(value: u, label: u.etiqueta),
                ],
                onSelected: (u) => setState(() => _unidad = u ?? _unidad),
              ),
              SizedBox(
                width: 120,
                child: TextFormField(
                  key: const Key('inf-ritmo'),
                  controller: _ritmo,
                  keyboardType: numero,
                  decoration: const InputDecoration(
                    labelText: 'Ritmo',
                    suffixText: 'mL/h',
                    isDense: true,
                  ),
                  validator: Infusion.validarRitmo,
                ),
              ),
              SizedBox(
                width: 220,
                child: TextFormField(
                  key: const Key('inf-concentracion'),
                  controller: _concentracion,
                  decoration: const InputDecoration(
                    labelText: 'Dilución (opcional)',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('inf-agregar'),
            onPressed: _agregar,
            icon: const Icon(Icons.add),
            label: const Text('Agregar infusión'),
          ),
        ),
      ],
    );
  }
}
