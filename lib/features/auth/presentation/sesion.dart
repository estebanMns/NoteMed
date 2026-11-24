/// Estado de la sesión (Riverpod).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:notemed/features/auth/data/autenticacion_simulada.dart';
import 'package:notemed/features/auth/domain/usuario.dart';

final autenticacionProvider = Provider<ServicioAutenticacion>(
  (ref) => const AutenticacionSimulada(),
);

final sesionProvider = NotifierProvider<SesionNotifier, Usuario?>(
  SesionNotifier.new,
);

class SesionNotifier extends Notifier<Usuario?> {
  SesionNotifier([this._inicial]);

  final Usuario? _inicial;

  @override
  Usuario? build() => _inicial;

  /// Devuelve `false` si el usuario o la clave no son válidos.
  Future<bool> iniciar(String usuario, String clave) async {
    final u = await ref
        .read(autenticacionProvider)
        .iniciarSesion(usuario, clave);
    if (u != null) state = u;
    return u != null;
  }

  void cerrar() => state = null;
}
