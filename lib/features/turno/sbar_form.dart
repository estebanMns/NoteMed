/// TSK-10 · HU03: formulario reutilizable de la plantilla SBAR.
library;

import 'package:flutter/material.dart';

import 'sbar_plantilla.dart';

class SbarForm extends StatefulWidget {
  const SbarForm({super.key, this.inicial = const NotaSbar(), this.onGuardar});

  final NotaSbar inicial;
  final ValueChanged<NotaSbar>? onGuardar;

  @override
  State<SbarForm> createState() => _SbarFormState();
}

class _SbarFormState extends State<SbarForm> {
  late NotaSbar _nota = widget.inicial;
  final _formKey = GlobalKey<FormState>();

  void _guardar() {
    if (_formKey.currentState!.validate()) {
      widget.onGuardar?.call(_nota);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in SeccionSbar.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                key: Key('sbar-${s.name}'),
                initialValue: _nota.texto(s),
                minLines: 2,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: '${s.letra} · ${s.titulo}',
                  helperText: s.guia,
                  helperMaxLines: 3,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => _nota = _nota.con(s, v),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? '${s.titulo} es obligatoria'
                    : null,
              ),
            ),
          FilledButton(
            key: const Key('sbar-guardar'),
            onPressed: _guardar,
            child: const Text('Guardar nota SBAR'),
          ),
        ],
      ),
    );
  }
}
