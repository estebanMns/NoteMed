/// TSK-28 · HU07: estado de la red leído del sistema operativo.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:notemed/core/red/estado_red.dart';

class EstadoRedDispositivo implements EstadoRed {
  EstadoRedDispositivo([Connectivity? conectividad])
    : _conectividad = conectividad ?? Connectivity();

  final Connectivity _conectividad;

  static bool _hayRed(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);

  @override
  Future<bool> conectado() async =>
      _hayRed(await _conectividad.checkConnectivity());

  @override
  Stream<bool> get cambios =>
      _conectividad.onConnectivityChanged.map(_hayRed).distinct();
}
