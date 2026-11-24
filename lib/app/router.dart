/// Rutas de la app (go_router). Los formularios internos de la pantalla del
/// paciente (escalas, procedimientos, borrador) se abren con
/// `Navigator.push` porque devuelven un resultado a esa pantalla.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:notemed/app/providers.dart';
import 'package:notemed/features/inicio/presentation/inicio_screen.dart';
import 'package:notemed/features/notas/presentation/entrega_turno_screen.dart';
import 'package:notemed/features/pacientes/presentation/paciente_screen.dart';
import 'package:notemed/features/pacientes/presentation/pacientes_screen.dart';
import 'package:notemed/features/valoracion/presentation/braden_screen.dart';
import 'package:notemed/features/valoracion/presentation/downton_screen.dart';

abstract final class Rutas {
  static const inicio = '/';
  static const pacientes = '/pacientes';
  static String paciente(int id) => '/pacientes/$id';
  static const braden = '/braden';
  static const downton = '/downton';
  static const turno = '/turno';
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: Rutas.inicio,
        builder: (_, _) => const InicioScreen(),
        routes: [
          GoRoute(
            path: 'pacientes',
            builder: (_, _) => const PacientesScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, estado) =>
                    _PacienteRuta(int.parse(estado.pathParameters['id']!)),
              ),
            ],
          ),
          GoRoute(path: 'braden', builder: (_, _) => const BradenScreen()),
          GoRoute(path: 'downton', builder: (_, _) => const DowntonScreen()),
          GoRoute(path: 'turno', builder: (_, _) => const EntregaTurnoScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Carga el paciente por id para que la ruta funcione también como enlace.
class _PacienteRuta extends ConsumerWidget {
  const _PacienteRuta(this.id);

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(pacienteProvider(id))
        .when(
          data: (p) => p == null
              ? const Scaffold(
                  body: Center(child: Text('El paciente no existe.')),
                )
              : PacienteScreen(paciente: p),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
        );
  }
}
