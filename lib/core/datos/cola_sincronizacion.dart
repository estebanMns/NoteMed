/// TSK-28 · HU07: procesa las solicitudes guardadas sin conexión cuando la
/// red vuelve. Una solicitud solo se borra de la cola cuando se procesó bien,
/// así que apagar la red o cerrar la app no pierde información.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ia/servicio_ia.dart';
import 'estado_red.dart';
import 'repositorio_pacientes.dart';
import 'solicitud_pendiente.dart';

class ColaSincronizacion {
  ColaSincronizacion({
    required this.repositorio,
    required this.red,
    required this.procesar,
  });

  final RepositorioPacientes repositorio;
  final EstadoRed red;

  /// Genera y guarda la nota de una solicitud. Si lanza, la solicitud
  /// queda en la cola.
  final Future<void> Function(SolicitudPendiente) procesar;

  /// Cantidad de solicitudes en espera, para mostrar en pantalla.
  final ValueNotifier<int> cantidad = ValueNotifier(0);

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
      if (!await red.conectado()) return 0;
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
