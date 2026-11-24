/// TSK-09 · HU03: pantalla principal del paciente. Reúne signos vitales,
/// infusiones (TSK-03), escalas de riesgo (HU02), procedimientos (TSK-14),
/// las notas guardadas y el botón "Generar Nota de Turno".
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:notemed/app/providers.dart';

import 'package:notemed/features/pacientes/domain/repositorio_pacientes.dart';
import 'package:notemed/features/notas/domain/servicio_ia.dart';
import 'package:notemed/features/privacidad/domain/protector_privacidad.dart';
import 'package:notemed/features/notas/presentation/fallecimiento_screen.dart';
import 'package:notemed/features/notas/presentation/borrador_screen.dart';
import 'package:notemed/features/notas/domain/nota_clinica.dart';
import 'package:notemed/features/notas/application/servicio_notas.dart';
import 'package:notemed/features/pacientes/presentation/procedimiento_form.dart';
import 'package:notemed/features/pacientes/domain/procedimiento_invasivo.dart';
import 'package:notemed/features/valoracion/domain/braden/braden_escala.dart';
import 'package:notemed/features/valoracion/presentation/braden_screen.dart';
import 'package:notemed/features/valoracion/domain/downton/downton_escala.dart';
import 'package:notemed/features/valoracion/presentation/downton_screen.dart';
import 'package:notemed/features/pacientes/domain/infusion.dart';
import 'package:notemed/features/pacientes/presentation/infusiones_form.dart';
import 'package:notemed/features/pacientes/domain/paciente.dart';
import 'package:notemed/features/pacientes/presentation/paciente_form_screen.dart';
import 'package:notemed/features/pacientes/domain/signos_vitales.dart';
import 'package:notemed/core/utils/fechas.dart';

class PacienteScreen extends ConsumerStatefulWidget {
  const PacienteScreen({super.key, required this.paciente});

  final Paciente paciente;

  @override
  ConsumerState<PacienteScreen> createState() => _PacienteScreenState();
}

class _PacienteScreenState extends ConsumerState<PacienteScreen> {
  late Paciente _paciente = widget.paciente;
  List<Infusion> _infusiones = const [];
  List<ProcedimientoInvasivo> _procedimientos = const [];
  List<NotaClinica> _notas = const [];
  EvaluacionDownton? _downton;
  EvaluacionBraden? _braden;
  bool _cargando = true;
  bool _generando = false;
  List<String> _erroresSignos = const [];

  final _tas = TextEditingController();
  final _tad = TextEditingController();
  final _fc = TextEditingController();
  final _fr = TextEditingController();
  final _spo2 = TextEditingController();
  final _temp = TextEditingController();
  final _observaciones = TextEditingController();

  RepositorioPacientes get _repo => ref.read(repositorioProvider);
  ServicioNotas get _servicio => ref.read(servicioNotasProvider);
  int get _id => _paciente.id!;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [_tas, _tad, _fc, _fr, _spo2, _temp, _observaciones]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    final signos = await _repo.signos(_id);
    final infusiones = await _repo.infusiones(_id);
    final procedimientos = await _repo.procedimientos(_id);
    final notas = await _repo.notas(_id);
    final downton = await _repo.downton(_id);
    final braden = await _repo.braden(_id);
    if (!mounted) return;
    setState(() {
      _infusiones = infusiones;
      _procedimientos = procedimientos;
      _notas = notas;
      _downton = downton;
      _braden = braden;
      _cargando = false;
    });
    String t(num? v) => v == null ? '' : '$v';
    _tas.text = t(signos.taSistolica);
    _tad.text = t(signos.taDiastolica);
    _fc.text = t(signos.fc);
    _fr.text = t(signos.fr);
    _spo2.text = t(signos.spo2);
    _temp.text = signos.temperatura == null
        ? ''
        : SignosVitales.formatearTemperatura(signos.temperatura!);
  }

  void _aviso(String mensaje) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));

  Future<T?> _abrir<T>(Widget pantalla) => Navigator.of(
    context,
  ).push<T>(MaterialPageRoute(builder: (_) => pantalla));

  SignosVitales _leerSignos() {
    int? entero(TextEditingController c) => int.tryParse(c.text.trim());
    return SignosVitales(
      taSistolica: entero(_tas),
      taDiastolica: entero(_tad),
      fc: entero(_fc),
      fr: entero(_fr),
      spo2: entero(_spo2),
      temperatura: double.tryParse(_temp.text.trim().replaceAll(',', '.')),
    );
  }

  /// Guarda los signos si son válidos. Devuelve `false` si hay errores.
  Future<bool> _guardarSignos({bool avisar = true}) async {
    final s = _leerSignos();
    setState(() => _erroresSignos = s.validar());
    if (_erroresSignos.isNotEmpty) return false;
    await _repo.guardarSignos(_id, s);
    if (avisar && mounted) _aviso('Signos vitales guardados');
    return true;
  }

  Future<void> _resultado(ResultadoSolicitud r) async {
    switch (r) {
      case BorradorGuardado(:final nota):
        await _abrirBorrador(nota);
      case SolicitudEnCola():
        _aviso(
          'Sin conexión: la solicitud quedó guardada y la nota se '
          'generará cuando vuelva la red.',
        );
    }
  }

  Future<void> _conManejoDeErrores(Future<void> Function() accion) async {
    setState(() => _generando = true);
    try {
      await accion();
    } on ErrorIA catch (e) {
      if (mounted) _aviso(e.mensaje);
    } on DatosPersonalesExpuestos catch (e) {
      if (mounted) _aviso('$e');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _generarNotaTurno() => _conManejoDeErrores(() async {
    if (!await _guardarSignos(avisar: false)) {
      _aviso('Corrija los signos vitales antes de generar la nota');
      return;
    }
    final datos = await _servicio.datosTurno(
      _paciente,
      observaciones: _observaciones.text,
    );
    await _resultado(await _servicio.notaTurno(datos));
    await _cargar();
  });

  Future<void> _notaFallecimiento() async {
    await _abrir<void>(
      FallecimientoScreen(
        onGenerar: (datos) => _conManejoDeErrores(() async {
          final r = await _servicio.notaFallecimiento(
            _paciente,
            datos,
            procedimientos: _procedimientos,
          );
          if (!mounted) return;
          Navigator.of(context).pop();
          await _resultado(r);
        }),
      ),
    );
    await _cargar();
  }

  Future<void> _abrirBorrador(NotaClinica nota) async {
    await _abrir<bool>(
      BorradorScreen(
        titulo: nota.tipo.etiqueta,
        textoInicial: nota.texto,
        revisar: ServicioNotas.revisor(nota),
        onFirmar: (texto, firma) async {
          await _repo.guardarNota(nota.firmar(texto, firma));
        },
      ),
    );
    await _cargar();
  }

  Future<void> _verNota(NotaClinica nota) async {
    if (nota.firma == null) return _abrirBorrador(nota);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(nota.tipo.etiqueta),
        content: SingleChildScrollView(
          child: Text(
            '${nota.texto}\n\nFirmada · Tarjeta profesional '
            '${nota.firma!.tarjetaProfesional} · '
            '${formatearFechaHora(nota.firma!.fecha)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _campoSigno(
    String etiqueta,
    String key,
    TextEditingController c, {
    String? sufijo,
    bool decimal = false,
    double ancho = 96,
  }) => SizedBox(
    width: ancho,
    child: TextField(
      key: Key(key),
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(
        labelText: etiqueta,
        suffixText: sufijo,
        isDense: true,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final titulo = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      appBar: AppBar(
        title: Text(_paciente.nombre),
        actions: [
          IconButton(
            tooltip: 'Editar datos',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _abrir<void>(
              PacienteFormScreen(
                inicial: _paciente,
                onGuardar: (p) async {
                  final navegador = Navigator.of(context);
                  try {
                    final guardado = await _repo.guardarPaciente(p);
                    ref
                      ..invalidate(pacientesProvider)
                      ..invalidate(pacienteProvider(_id));
                    setState(() => _paciente = guardado);
                    navegador.pop();
                  } on PacienteDuplicado catch (e) {
                    _aviso('$e');
                  }
                },
              ),
            ),
          ),
          PopupMenuButton<void>(
            itemBuilder: (_) => [
              PopupMenuItem(
                key: const Key('menu-fallecimiento'),
                onTap: _notaFallecimiento,
                child: const Text('Nota de fallecimiento'),
              ),
            ],
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                switch (ref.watch(pendientesProvider).value ?? 0) {
                  0 => const SizedBox.shrink(),
                  final n => Card(
                    key: const Key('aviso-pendientes'),
                    child: ListTile(
                      leading: const Icon(Icons.cloud_off),
                      title: Text(
                        n == 1
                            ? '1 nota pendiente por falta de red'
                            : '$n notas pendientes por falta de red',
                      ),
                    ),
                  ),
                },
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(_paciente.nombre),
                    subtitle: Text(
                      'Cédula ${_paciente.cedula} · '
                      '${_paciente.edad} años · Cama ${_paciente.cama}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Signos vitales', style: titulo),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _campoSigno(
                      'TA sist.',
                      'sv-tas',
                      _tas,
                      sufijo: 'mmHg',
                      ancho: 120,
                    ),
                    _campoSigno(
                      'TA diast.',
                      'sv-tad',
                      _tad,
                      sufijo: 'mmHg',
                      ancho: 120,
                    ),
                    _campoSigno('FC', 'sv-fc', _fc, sufijo: 'lpm'),
                    _campoSigno('FR', 'sv-fr', _fr, sufijo: 'rpm'),
                    _campoSigno('SpO2', 'sv-spo2', _spo2, sufijo: '%'),
                    _campoSigno(
                      'T',
                      'sv-temp',
                      _temp,
                      sufijo: '°C',
                      decimal: true,
                    ),
                  ],
                ),
                for (final e in _erroresSignos)
                  Text(
                    e,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('sv-guardar'),
                    onPressed: _guardarSignos,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar signos'),
                  ),
                ),
                const Divider(height: 32),
                Text('Infusiones', style: titulo),
                const SizedBox(height: 8),
                InfusionesForm(
                  infusiones: _infusiones,
                  onAgregar: (i) async {
                    final guardada = await _repo.agregarInfusion(_id, i);
                    setState(() => _infusiones = [..._infusiones, guardada]);
                  },
                  onEliminar: (i) async {
                    await _repo.eliminarInfusion(i.id!);
                    setState(
                      () => _infusiones = _infusiones
                          .where((x) => x.id != i.id)
                          .toList(),
                    );
                  },
                ),
                const Divider(height: 32),
                Text('Escalas de riesgo', style: titulo),
                Card(
                  child: ListTile(
                    key: const Key('pac-downton'),
                    leading: const Icon(Icons.elderly),
                    title: const Text('Escala de Downton'),
                    subtitle: Text(_downton?.toTexto() ?? 'Sin evaluar'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _abrir<void>(
                      DowntonScreen(
                        inicial: _downton ?? const EvaluacionDownton(),
                        onGuardar: (e) async {
                          final navegador = Navigator.of(context);
                          await _repo.guardarDownton(_id, e);
                          setState(() => _downton = e);
                          navegador.pop();
                        },
                      ),
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    key: const Key('pac-braden'),
                    leading: const Icon(Icons.healing),
                    title: const Text('Escala de Braden'),
                    subtitle: Text(
                      _braden?.total == null
                          ? 'Sin evaluar'
                          : '${_braden!.total} puntos · ${_braden!.nivel!.etiqueta}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _abrir<void>(
                      BradenScreen(
                        onGuardar: (e) async {
                          final navegador = Navigator.of(context);
                          await _repo.guardarBraden(_id, e);
                          setState(() => _braden = e);
                          navegador.pop();
                        },
                      ),
                    ),
                  ),
                ),
                const Divider(height: 32),
                Text('Procedimientos invasivos', style: titulo),
                for (final p in _procedimientos)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.medical_services_outlined),
                      title: Text(p.nombre),
                      subtitle: Text(p.toTexto()),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('pac-procedimiento'),
                    onPressed: () => _abrir<void>(
                      ProcedimientoFormScreen(
                        onGuardar: (p) async {
                          final navegador = Navigator.of(context);
                          final guardado = await _repo.agregarProcedimiento(
                            _id,
                            p,
                          );
                          setState(
                            () => _procedimientos = [
                              ..._procedimientos,
                              guardado,
                            ],
                          );
                          navegador.pop();
                        },
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Registrar procedimiento'),
                  ),
                ),
                const Divider(height: 32),
                TextField(
                  key: const Key('pac-observaciones'),
                  controller: _observaciones,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones del turno (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const Divider(height: 32),
                Text('Notas', style: titulo),
                if (_notas.isEmpty) const Text('Todavía no hay notas.'),
                for (final n in _notas)
                  Card(
                    child: ListTile(
                      key: Key('nota-${n.id}'),
                      leading: Icon(
                        n.firma == null
                            ? Icons.edit_note
                            : Icons.verified_outlined,
                      ),
                      title: Text(n.tipo.etiqueta),
                      subtitle: Text(
                        '${formatearFechaHora(n.creada)} · '
                        '${n.firma == null ? 'Borrador sin firmar' : 'Firmada'}',
                      ),
                      onTap: () => _verNota(n),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            key: const Key('btn-generar-nota'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _cargando || _generando ? null : _generarNotaTurno,
            icon: _generando
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(
              _generando ? 'Generando nota…' : 'Generar Nota de Turno',
            ),
          ),
        ),
      ),
    );
  }
}
