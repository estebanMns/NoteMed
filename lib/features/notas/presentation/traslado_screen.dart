/// Datos del traslado que se agregan a lo registrado del paciente para que
/// la IA redacte la nota de traslado.
library;

import 'package:material_ui/material_ui.dart';

import 'package:notemed/features/notas/domain/traslado/datos_traslado.dart';

class TrasladoScreen extends StatefulWidget {
  const TrasladoScreen({super.key, required this.onGenerar});

  final Future<void> Function(DatosTraslado datos) onGenerar;

  @override
  State<TrasladoScreen> createState() => _TrasladoScreenState();
}

class _TrasladoScreenState extends State<TrasladoScreen> {
  final _destino = TextEditingController();
  final _motivo = TextEditingController();
  final _acompanante = TextEditingController();
  final _recibe = TextEditingController();
  MedioTraslado _medio = MedioTraslado.camilla;
  EstadoConciencia _conciencia = EstadoConciencia.alerta;
  bool _generando = false;
  List<String> _errores = const [];

  @override
  void dispose() {
    for (final c in [_destino, _motivo, _acompanante, _recibe]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _generar() async {
    final datos = DatosTraslado(
      destino: _destino.text.trim(),
      motivo: _motivo.text.trim(),
      medio: _medio,
      acompanante: _acompanante.text.trim(),
      recibe: _recibe.text.trim(),
      estadoConciencia: _conciencia,
    );
    setState(() => _errores = datos.validar());
    if (_errores.isNotEmpty) return;
    setState(() => _generando = true);
    try {
      await widget.onGenerar(datos);
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Widget _campo(
    String key,
    TextEditingController c,
    String etiqueta, {
    String? ayuda,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: Key(key),
      controller: c,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: etiqueta, helperText: ayuda),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final titulo = Theme.of(context).textTheme.titleSmall;
    return Scaffold(
      appBar: AppBar(title: const Text('Nota de traslado')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Se usan también los signos vitales, infusiones, escalas y '
            'procedimientos registrados del paciente.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _campo(
            'tras-destino',
            _destino,
            'Destino',
            ayuda:
                'Servicio o institución, por ejemplo "Hospitalización 3er piso"',
          ),
          _campo('tras-motivo', _motivo, 'Motivo del traslado'),
          Text('Medio de transporte', style: titulo),
          Wrap(
            spacing: 8,
            children: [
              for (final m in MedioTraslado.values)
                ChoiceChip(
                  key: Key('tras-medio-${m.name}'),
                  label: Text(m.etiqueta),
                  selected: _medio == m,
                  onSelected: (_) => setState(() => _medio = m),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Estado de conciencia', style: titulo),
          Wrap(
            spacing: 8,
            children: [
              for (final e in EstadoConciencia.values)
                ChoiceChip(
                  key: Key('tras-conciencia-${e.name}'),
                  label: Text(e.etiqueta),
                  selected: _conciencia == e,
                  onSelected: (_) => setState(() => _conciencia = e),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _campo(
            'tras-acompanante',
            _acompanante,
            'Acompaña',
            ayuda: 'Cargo, sin nombres (por ejemplo "auxiliar de enfermería")',
          ),
          _campo(
            'tras-recibe',
            _recibe,
            'Recibe',
            ayuda: 'Cargo de quien recibe en el destino, sin nombres',
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
                key: const Key('tras-generar'),
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
