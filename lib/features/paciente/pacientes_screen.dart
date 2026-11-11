/// HU01: lista de pacientes guardados en el celular.
library;

import 'package:flutter/material.dart';

import '../../core/datos/repositorio_pacientes.dart';
import '../nota/servicio_notas.dart';
import 'paciente.dart';
import 'paciente_form_screen.dart';
import 'paciente_screen.dart';

class PacientesScreen extends StatefulWidget {
  const PacientesScreen({
    super.key,
    required this.repositorio,
    required this.servicioNotas,
  });

  final RepositorioPacientes repositorio;
  final ServicioNotas servicioNotas;

  @override
  State<PacientesScreen> createState() => _PacientesScreenState();
}

class _PacientesScreenState extends State<PacientesScreen> {
  late Future<List<Paciente>> _pacientes = widget.repositorio.pacientes();

  void _recargar() {
    if (!mounted) return;
    setState(() {
      _pacientes = widget.repositorio.pacientes();
    });
  }

  Future<void> _abrir(Widget pantalla) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => pantalla));
    _recargar();
  }

  void _nuevo() => _abrir(
    PacienteFormScreen(
      onGuardar: (p) async {
        final navegador = Navigator.of(context);
        final mensajero = ScaffoldMessenger.of(context);
        try {
          final guardado = await widget.repositorio.guardarPaciente(p);
          navegador.pop();
          _abrir(
            PacienteScreen(
              paciente: guardado,
              repositorio: widget.repositorio,
              servicioNotas: widget.servicioNotas,
            ),
          );
        } on PacienteDuplicado catch (e) {
          mensajero.showSnackBar(SnackBar(content: Text('$e')));
        }
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pacientes')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('pacientes-nuevo'),
        onPressed: _nuevo,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo paciente'),
      ),
      body: FutureBuilder<List<Paciente>>(
        future: _pacientes,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snap.data!;
          if (lista.isEmpty) {
            return const Center(child: Text('No hay pacientes registrados.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              for (final p in lista)
                Card(
                  child: ListTile(
                    key: Key('paciente-${p.id}'),
                    leading: CircleAvatar(child: Text(p.cama)),
                    title: Text(p.nombre),
                    subtitle: Text('Cédula ${p.cedula} · ${p.edad} años'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _abrir(
                      PacienteScreen(
                        paciente: p,
                        repositorio: widget.repositorio,
                        servicioNotas: widget.servicioNotas,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
