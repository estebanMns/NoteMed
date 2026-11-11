/// TSK-01 · HU01: formulario para registrar los datos básicos del paciente.
library;

import 'package:flutter/material.dart';

import 'paciente.dart';

class PacienteFormScreen extends StatefulWidget {
  const PacienteFormScreen({super.key, this.inicial, required this.onGuardar});

  /// Paciente a editar. Si es `null` se registra uno nuevo.
  final Paciente? inicial;
  final ValueChanged<Paciente> onGuardar;

  @override
  State<PacienteFormScreen> createState() => _PacienteFormScreenState();
}

class _PacienteFormScreenState extends State<PacienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.inicial?.nombre);
  late final _cedula = TextEditingController(text: widget.inicial?.cedula);
  late final _edad = TextEditingController(
    text: widget.inicial?.edad.toString(),
  );
  late final _cama = TextEditingController(text: widget.inicial?.cama);

  @override
  void dispose() {
    for (final c in [_nombre, _cedula, _edad, _cama]) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    widget.onGuardar(
      Paciente(
        id: widget.inicial?.id,
        nombre: _nombre.text.trim().replaceAll(RegExp(r'\s+'), ' '),
        cedula: _cedula.text.trim().replaceAll('.', ''),
        edad: int.parse(_edad.text.trim()),
        cama: _cama.text.trim().toUpperCase(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.inicial == null ? 'Nuevo paciente' : 'Editar paciente',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('pac-nombre'),
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: Paciente.validarNombre,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('pac-cedula'),
              controller: _cedula,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cédula',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              validator: Paciente.validarCedula,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('pac-edad'),
                    controller: _edad,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Edad',
                      suffixText: 'años',
                      border: OutlineInputBorder(),
                    ),
                    validator: Paciente.validarEdad,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('pac-cama'),
                    controller: _cama,
                    decoration: const InputDecoration(
                      labelText: 'Cama / camilla',
                      prefixIcon: Icon(Icons.bed_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: Paciente.validarCama,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('pac-guardar'),
              onPressed: _guardar,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar paciente'),
            ),
          ],
        ),
      ),
    );
  }
}
