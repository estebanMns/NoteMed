/// Menú principal de la app.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:notemed/app/providers.dart';
import 'package:notemed/app/router.dart';

class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget opcion({
      required String key,
      required IconData icono,
      required String titulo,
      required String subtitulo,
      required String ruta,
    }) => Card(
      child: ListTile(
        key: Key(key),
        leading: Icon(icono),
        title: Text(titulo),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(ruta),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('NoteMed')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Chip(
              key: const Key('modo-ia'),
              avatar: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: Text(ref.watch(modoIAProvider).etiqueta),
            ),
          ),
          opcion(
            key: 'menu-pacientes',
            icono: Icons.people_outline,
            titulo: 'Pacientes',
            subtitulo: 'Valoración, notas de turno y fallecimiento',
            ruta: Rutas.pacientes,
          ),
          opcion(
            key: 'menu-braden',
            icono: Icons.healing,
            titulo: 'Escala de Braden',
            subtitulo: 'Riesgo de lesiones por presión',
            ruta: Rutas.braden,
          ),
          opcion(
            key: 'menu-downton',
            icono: Icons.elderly,
            titulo: 'Escala de Downton',
            subtitulo: 'Riesgo de caídas',
            ruta: Rutas.downton,
          ),
          opcion(
            key: 'menu-turno',
            icono: Icons.swap_horiz,
            titulo: 'Entrega de turno',
            subtitulo: 'Nota SBAR y balance de líquidos',
            ruta: Rutas.turno,
          ),
        ],
      ),
    );
  }
}
