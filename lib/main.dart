import 'package:flutter/material.dart';

import 'core/datos/base_datos_local.dart';
import 'core/datos/estado_red.dart';
import 'core/datos/repositorio_pacientes.dart';
import 'core/ia/claude_servicio_ia.dart';
import 'core/ia/servicio_ia.dart';
import 'features/nota/servicio_notas.dart';
import 'features/paciente/pacientes_screen.dart';
import 'features/riesgos/braden/braden_screen.dart';
import 'features/riesgos/downton/downton_screen.dart';
import 'features/turno/entrega_turno_screen.dart';

/// Clave de la API de Claude: `flutter run --dart-define=ANTHROPIC_API_KEY=...`
const _claveIA = String.fromEnvironment('ANTHROPIC_API_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repositorio = RepositorioSqlite(await BaseDatosLocal.abrir());
  final ServicioIA ia = _claveIA.isEmpty
      ? const ServicioIANoConfigurado()
      : ClaudeServicioIA(apiKey: _claveIA);
  final servicioNotas = ServicioNotas(
    repositorio: repositorio,
    ia: ia,
    red: EstadoRedDispositivo(),
  );
  // Si quedaron solicitudes sin enviar, se procesan al volver la red.
  servicioNotas.cola.iniciar();
  runApp(
    NoteMedApp(
      dependencias: Dependencias(
        repositorio: repositorio,
        servicioNotas: servicioNotas,
      ),
    ),
  );
}

class Dependencias {
  const Dependencias({required this.repositorio, required this.servicioNotas});

  final RepositorioPacientes repositorio;
  final ServicioNotas servicioNotas;
}

class NoteMedApp extends StatelessWidget {
  const NoteMedApp({super.key, this.dependencias});

  /// Base local y servicios. Sin ellas solo funcionan las herramientas que
  /// no guardan datos.
  final Dependencias? dependencias;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoteMed',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: HomeScreen(dependencias: dependencias),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.dependencias});

  final Dependencias? dependencias;

  @override
  Widget build(BuildContext context) {
    void abrir(Widget pantalla) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => pantalla));
    final d = dependencias;

    return Scaffold(
      appBar: AppBar(title: const Text('NoteMed')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              key: const Key('menu-pacientes'),
              enabled: d != null,
              leading: const Icon(Icons.people_outline),
              title: const Text('Pacientes'),
              subtitle: const Text('Registro, notas de turno y fallecimiento'),
              onTap: d == null
                  ? null
                  : () => abrir(
                      PacientesScreen(
                        repositorio: d.repositorio,
                        servicioNotas: d.servicioNotas,
                      ),
                    ),
            ),
          ),
          Card(
            child: ListTile(
              key: const Key('menu-braden'),
              leading: const Icon(Icons.healing),
              title: const Text('Escala de Braden'),
              subtitle: const Text('Riesgo de lesiones por presión'),
              onTap: () => abrir(const BradenScreen()),
            ),
          ),
          Card(
            child: ListTile(
              key: const Key('menu-downton'),
              leading: const Icon(Icons.elderly),
              title: const Text('Escala de Downton'),
              subtitle: const Text('Riesgo de caídas'),
              onTap: () => abrir(const DowntonScreen()),
            ),
          ),
          Card(
            child: ListTile(
              key: const Key('menu-turno'),
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Entrega de turno'),
              subtitle: const Text('Nota SBAR y balance de líquidos'),
              onTap: () => abrir(const EntregaTurnoScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
