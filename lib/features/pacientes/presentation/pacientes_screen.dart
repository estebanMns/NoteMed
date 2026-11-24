/// HU01: lista de pacientes guardados en el celular.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:notemed/app/providers.dart';
import 'package:notemed/app/router.dart';
import 'package:notemed/features/pacientes/domain/repositorio_pacientes.dart';
import 'package:notemed/features/pacientes/presentation/paciente_form_screen.dart';

class PacientesScreen extends ConsumerWidget {
  const PacientesScreen({super.key});

  Future<void> _abrirPaciente(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    await context.push(Rutas.paciente(id));
    ref.invalidate(pacientesProvider);
  }

  void _nuevo(BuildContext context, WidgetRef ref) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (formulario) => PacienteFormScreen(
            onGuardar: (p) async {
              final navegador = Navigator.of(formulario);
              final mensajero = ScaffoldMessenger.of(formulario);
              try {
                final guardado = await ref
                    .read(repositorioProvider)
                    .guardarPaciente(p);
                ref.invalidate(pacientesProvider);
                navegador.pop();
                if (context.mounted) {
                  await _abrirPaciente(context, ref, guardado.id!);
                }
              } on PacienteDuplicado catch (e) {
                mensajero.showSnackBar(SnackBar(content: Text('$e')));
              }
            },
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pacientes')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('pacientes-nuevo'),
        onPressed: () => _nuevo(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo paciente'),
      ),
      body: ref
          .watch(pacientesProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (lista) => lista.isEmpty
                ? const Center(child: Text('No hay pacientes registrados.'))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      for (final p in lista)
                        Card(
                          child: ListTile(
                            key: Key('paciente-${p.id}'),
                            leading: CircleAvatar(child: Text(p.cama)),
                            title: Text(p.nombre),
                            subtitle: Text(
                              'Cédula ${p.cedula} · ${p.edad} años',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _abrirPaciente(context, ref, p.id!),
                          ),
                        ),
                    ],
                  ),
          ),
    );
  }
}
