/// Usuarios sintéticos para desarrollo y pruebas con el personal (no son
/// personas reales). La clave de todos es `notemed123`; solo se guarda su
/// hash SHA-256. Se reemplaza por la autenticación del backend.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:notemed/features/auth/domain/usuario.dart';

class AutenticacionSimulada implements ServicioAutenticacion {
  const AutenticacionSimulada();

  static const claveDemo = 'notemed123';

  static const _hashClave =
      'bb744bf22387bf91b9bf003bf40f48ec474916d606486ad64707a4b2a958b710';

  static const usuarios = <String, Usuario>{
    'enfermera1': Usuario(
      usuario: 'enfermera1',
      tarjetaProfesional: 'TP-10001',
      rol: Rol.enfermera,
    ),
    'enfermera2': Usuario(
      usuario: 'enfermera2',
      tarjetaProfesional: 'TP-10002',
      rol: Rol.enfermera,
    ),
    'jefe1': Usuario(
      usuario: 'jefe1',
      tarjetaProfesional: 'TP-20001',
      rol: Rol.jefe,
    ),
  };

  @override
  Future<Usuario?> iniciarSesion(String usuario, String clave) async {
    final u = usuarios[usuario.trim().toLowerCase()];
    final hash = sha256.convert(utf8.encode(clave)).toString();
    return u != null && hash == _hashClave ? u : null;
  }
}
