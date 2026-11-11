/// TSK-14 · HU04: formulario para registrar procedimientos invasivos.
library;

import 'package:flutter/material.dart';

import 'procedimiento_invasivo.dart';

class ProcedimientoFormScreen extends StatefulWidget {
  const ProcedimientoFormScreen({
    super.key,
    required this.onGuardar,
    this.ahora = DateTime.now,
  });

  final ValueChanged<ProcedimientoInvasivo> onGuardar;

  /// Reloj inyectable para las pruebas.
  final DateTime Function() ahora;

  @override
  State<ProcedimientoFormScreen> createState() =>
      _ProcedimientoFormScreenState();
}

class _ProcedimientoFormScreenState extends State<ProcedimientoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  TipoProcedimiento _tipo = TipoProcedimiento.cateterVenosoPeriferico;
  late DateTime _fechaHora = widget.ahora();
  final _sitio = TextEditingController();
  final _calibre = TextEditingController();
  final _intentos = TextEditingController(text: '1');
  final _responsable = TextEditingController();
  final _descripcionOtro = TextEditingController();
  final _observaciones = TextEditingController();
  String? _errorFecha;

  @override
  void dispose() {
    for (final c in [
      _sitio,
      _calibre,
      _intentos,
      _responsable,
      _descripcionOtro,
      _observaciones,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFechaHora() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaHora,
      firstDate: widget.ahora().subtract(const Duration(days: 30)),
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

  String? _texto(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  void _guardar() {
    final valido = _formKey.currentState!.validate();
    final p = ProcedimientoInvasivo(
      tipo: _tipo,
      fechaHora: _fechaHora,
      sitio: _sitio.text.trim(),
      calibre: _texto(_calibre),
      intentos: int.tryParse(_intentos.text.trim()) ?? 0,
      responsable: _responsable.text.trim(),
      descripcionOtro: _texto(_descripcionOtro),
      observaciones: _texto(_observaciones),
    );
    final errores = p.validar(ahora: widget.ahora());
    final errorFecha = errores.where((e) => e.contains('fecha')).firstOrNull;
    setState(() => _errorFecha = errorFecha);
    if (valido && errores.isEmpty) widget.onGuardar(p);
  }

  @override
  Widget build(BuildContext context) {
    const borde = OutlineInputBorder();
    return Scaffold(
      appBar: AppBar(title: const Text('Procedimiento invasivo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownMenu<TipoProcedimiento>(
              key: const Key('proc-tipo'),
              expandedInsets: EdgeInsets.zero,
              initialSelection: _tipo,
              label: const Text('Tipo de procedimiento'),
              dropdownMenuEntries: [
                for (final t in TipoProcedimiento.values)
                  DropdownMenuEntry(value: t, label: t.etiqueta),
              ],
              onSelected: (t) => setState(() => _tipo = t ?? _tipo),
            ),
            if (_tipo == TipoProcedimiento.otro) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('proc-descripcion-otro'),
                controller: _descripcionOtro,
                decoration: const InputDecoration(
                  labelText: '¿Qué procedimiento?',
                  border: borde,
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Describa el procedimiento'
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            ListTile(
              key: const Key('proc-fecha'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(formatearFechaHora(_fechaHora)),
              subtitle: _errorFecha == null
                  ? const Text('Fecha y hora del procedimiento')
                  : Text(
                      _errorFecha!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
              trailing: TextButton(
                onPressed: _elegirFechaHora,
                child: const Text('Cambiar'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('proc-sitio'),
              controller: _sitio,
              decoration: const InputDecoration(
                labelText: 'Sitio de inserción',
                border: borde,
              ),
              validator: ProcedimientoInvasivo.validarSitio,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('proc-calibre'),
                    controller: _calibre,
                    decoration: InputDecoration(
                      labelText: _tipo.etiquetaCalibre,
                      border: borde,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    key: const Key('proc-intentos'),
                    controller: _intentos,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Intentos',
                      border: borde,
                    ),
                    validator: ProcedimientoInvasivo.validarIntentos,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('proc-responsable'),
              controller: _responsable,
              decoration: const InputDecoration(
                labelText: 'Realizado por (cargo)',
                helperText: 'Ejemplo: enfermera jefe, médico de turno',
                border: borde,
              ),
              validator: ProcedimientoInvasivo.validarResponsable,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('proc-observaciones'),
              controller: _observaciones,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Observaciones (opcional)',
                border: borde,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('proc-guardar'),
              onPressed: _guardar,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar procedimiento'),
            ),
          ],
        ),
      ),
    );
  }
}
