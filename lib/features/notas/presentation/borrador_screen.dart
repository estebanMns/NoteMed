/// TSK-17 · HU05: vista previa del borrador generado por la IA, con una caja
/// de texto editable. Desde aquí se firma la nota (TSK-19).
library;

import 'package:material_ui/material_ui.dart';

import 'package:notemed/features/notas/domain/firma_enfermera.dart';
import 'package:notemed/features/notas/presentation/firma_modal.dart';
import 'package:notemed/features/notas/domain/revision_nota.dart';

class BorradorScreen extends StatefulWidget {
  const BorradorScreen({
    super.key,
    required this.titulo,
    required this.textoInicial,
    required this.revisar,
    required this.onFirmar,
    this.ahora = DateTime.now,
    this.aviso =
        'Borrador generado por IA. Revíselo y corríjalo antes de firmar.',
    this.tarjetaProfesional,
  });

  final String titulo;
  final String textoInicial;
  final RevisorNota revisar;

  /// Se llama con el texto final y la firma. La pantalla se cierra cuando
  /// termina.
  final Future<void> Function(String texto, FirmaEnfermera firma) onFirmar;
  final DateTime Function() ahora;

  /// Texto que se muestra arriba del editor.
  final String aviso;

  /// Tarjeta de la enfermera con sesión, para llenar el modal de firma.
  final String? tarjetaProfesional;

  @override
  State<BorradorScreen> createState() => _BorradorScreenState();
}

class _BorradorScreenState extends State<BorradorScreen> {
  late final _texto = TextEditingController(text: widget.textoInicial);
  late var _revision = widget.revisar(widget.textoInicial);
  bool _guardando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _firmar() async {
    final firma = await mostrarFirmaModal(
      context,
      ahora: widget.ahora,
      tarjetaInicial: widget.tarjetaProfesional,
    );
    if (firma == null || !mounted) return;
    setState(() => _guardando = true);
    try {
      await widget.onFirmar(_texto.text.trim(), firma);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final vacio = _texto.text.trim().isEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.aviso, style: TextStyle(color: esquema.onSurfaceVariant)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('borrador-texto'),
            controller: _texto,
            minLines: 10,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onChanged: (t) => setState(() => _revision = widget.revisar(t)),
          ),
          const SizedBox(height: 12),
          if (_revision.mensajes.isNotEmpty)
            Card(
              key: const Key('borrador-advertencias'),
              color: _revision.bloquea
                  ? esquema.errorContainer
                  : esquema.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _revision.bloquea
                          ? 'Corrija estos datos antes de firmar'
                          : 'Revise',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    for (final m in _revision.mensajes) Text('• $m'),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            key: const Key('borrador-firmar'),
            onPressed: _guardando || vacio || _revision.bloquea
                ? null
                : _firmar,
            icon: _guardando
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.draw_outlined),
            label: const Text('Firmar nota'),
          ),
        ),
      ),
    );
  }
}
