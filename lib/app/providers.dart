/// Inyección de dependencias con Riverpod. Aquí se decide qué
/// implementación concreta usa cada interfaz del dominio; las pantallas solo
/// conocen los providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'package:notemed/core/red/estado_red.dart';
import 'package:notemed/core/red/estado_red_dispositivo.dart';
import 'package:notemed/features/metricas/data/repositorio_metricas_sqlite.dart';
import 'package:notemed/features/metricas/domain/metrica_nota.dart';
import 'package:notemed/features/metricas/domain/repositorio_metricas.dart';
import 'package:notemed/features/notas/application/servicio_notas.dart';
import 'package:notemed/features/notas/data/ia/claude_servicio_ia.dart';
import 'package:notemed/features/notas/data/ia/servicio_ia_remoto.dart';
import 'package:notemed/features/notas/data/ia/servicio_ia_simulado.dart';
import 'package:notemed/features/notas/domain/servicio_ia.dart';
import 'package:notemed/features/pacientes/data/repositorio_sqlite.dart';
import 'package:notemed/features/pacientes/domain/paciente.dart';
import 'package:notemed/features/pacientes/domain/repositorio_pacientes.dart';

/// URL del backend: `flutter run --dart-define=NOTEMED_API_URL=https://...`
const _urlBackend = String.fromEnvironment('NOTEMED_API_URL');

/// Solo para demostraciones: `--dart-define=ANTHROPIC_API_KEY=...`
const _claveClaude = String.fromEnvironment('ANTHROPIC_API_KEY');

enum ModoIA {
  simulada('IA simulada (sin internet)'),
  servidor('IA del servidor del hospital'),
  claudeDirecto('Claude directo (solo demostración)');

  const ModoIA(this.etiqueta);
  final String etiqueta;
}

/// Qué IA usa la app, según cómo se compiló.
final modoIAProvider = Provider<ModoIA>(
  (ref) => _urlBackend.isNotEmpty
      ? ModoIA.servidor
      : _claveClaude.isNotEmpty
      ? ModoIA.claudeDirecto
      : ModoIA.simulada,
);

/// Base de datos abierta en `main()`. Se sobrescribe al iniciar la app.
final baseDatosProvider = Provider<Database>(
  (ref) => throw UnimplementedError('Abra la base de datos en main()'),
);

final repositorioProvider = Provider<RepositorioPacientes>(
  (ref) => RepositorioSqlite(ref.watch(baseDatosProvider)),
);

final repositorioMetricasProvider = Provider<RepositorioMetricas>(
  (ref) => RepositorioMetricasSqlite(ref.watch(baseDatosProvider)),
);

/// Métricas de validación (tasa de aceptación y de edición).
final resumenMetricasProvider = FutureProvider<ResumenMetricas>(
  (ref) async =>
      ResumenMetricas(await ref.watch(repositorioMetricasProvider).metricas()),
);

final estadoRedProvider = Provider<EstadoRed>((ref) => EstadoRedDispositivo());

final servicioIAProvider = Provider<ServicioIA>(
  (ref) => switch (ref.watch(modoIAProvider)) {
    ModoIA.simulada => const ServicioIASimulado(),
    ModoIA.servidor => ServicioIARemoto(urlBase: _urlBackend),
    ModoIA.claudeDirecto => ClaudeServicioIA(apiKey: _claveClaude),
  },
);

/// Casos de uso de las notas. Al crearse empieza a procesar la cola de
/// solicitudes que quedaron sin red.
final servicioNotasProvider = Provider<ServicioNotas>((ref) {
  final servicio = ServicioNotas(
    repositorio: ref.watch(repositorioProvider),
    ia: ref.watch(servicioIAProvider),
    red: ref.watch(estadoRedProvider),
    metricas: ref.watch(repositorioMetricasProvider),
  );
  servicio.cola.iniciar();
  ref.onDispose(servicio.cola.detener);
  return servicio;
});

/// Cantidad de notas esperando red, para el aviso en pantalla.
final pendientesProvider = StreamProvider<int>((ref) async* {
  final cantidad = ref.watch(servicioNotasProvider).cola.cantidad;
  yield cantidad.value;
  yield* cantidad.cambios;
});

/// Pacientes guardados en el celular. Se invalida al crear o editar uno.
final pacientesProvider = FutureProvider<List<Paciente>>(
  (ref) => ref.watch(repositorioProvider).pacientes(),
);

final pacienteProvider = FutureProvider.family<Paciente?, int>(
  (ref, id) => ref.watch(repositorioProvider).paciente(id),
);
