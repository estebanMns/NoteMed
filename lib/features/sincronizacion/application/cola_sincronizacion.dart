/// TSK-28 · HU07: procesa las solicitudes guardadas sin conexión cuando la
/// red vuelve. Una solicitud solo se borra de la cola cuando se procesó bien,
/// así que apagar la red o cerrar la app no pierde información.
library;

import 'dart:async';

import 'package:notemed/core/utils/valor_observable.dart';

import 'package:notemed/features/notas/domain/servicio_ia.dart';
import 'package:notemed/core/red/estado_red.dart';
import 'package:notemed/features/pacientes/domain/repositorio_pacientes.dart';
import 'package:notemed/features/sincronizacion/domain/solicitud_pendiente.dart';

class ColaSincronizacion {
  ColaSincronizacion({
    required this.repositorio,
    required this.red,
    required this.procesar,
    this.requiereRed = true,
  });

  final RepositorioPacientes repositorio;
  final EstadoRed red;

  /// Genera y guarda la nota de una solicitud. Si lanza, la solicitud
  /// queda en la cola.
  final Future<void> Function(SolicitudPendiente) procesar;

  /// `false` cuando la IA funciona en el celular: la cola se procesa aunque
  /// no haya red.
  final bool requiereRed;

  /// Cantidad de solicitudes en espera, para mostrar en pantalla.
  final ValorObservable<int> cantidad = ValorObservable(0);

  StreamSubscription<bool>? _suscripcion;
  Future<int>? _enCurso;

  /// Empieza a escuchar la red y procesa lo que haya pendiente.
  Future<void> iniciar() async {
    _suscripcion ??= red.cambios
        .where((c) => c)
        .listen((_) => procesarPendientes());
    await procesarPendientes();
  }

  Future<void> detener() async {
    await _suscripcion?.cancel();
    _suscripcion = null;
    await _enCurso;
  }

  Future<SolicitudPendiente> encolar(SolicitudPendiente s) async {
    final guardada = await repositorio.encolar(s);
    await actualizarCantidad();
    return guardada;
  }

  Future<void> actualizarCantidad() async =>
      cantidad.value = (await repositorio.pendientes()).length;

  /// Procesa la cola en orden. Devuelve cuántas solicitudes se completaron.
  /// Si ya hay un procesamiento en curso, espera ese mismo.
  Future<int> procesarPendientes() =>
      _enCurso ??= _procesar().whenComplete(() => _enCurso = null);

  Future<int> _procesar() async {
    var completadas = 0;
    try {
      if (requiereRed && !await red.conectado()) return 0;
      for (final s in await repositorio.pendientes()) {
        try {
          await procesar(s);
          await repositorio.eliminarPendiente(s.id!);
          completadas++;
        } on ErrorIA catch (e) {
          await repositorio.registrarIntento(s.id!, e.mensaje);
          // Sin red no tiene sentido seguir con las demás.
          if (e.sinConexion) break;
        } catch (e) {
          await repositorio.registrarIntento(s.id!, '$e');
        }
      }
    } finally {
      await actualizarCantidad();
    }
    return completadas;
  }
}
