/// Clave de cifrado de la base local. Se genera una sola vez (256 bits
/// aleatorios) y se guarda en el almacenamiento seguro del sistema: Keystore
/// en Android y Keychain en iOS. Nunca se escribe en el código ni en disco
/// sin cifrar.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ClaveBaseDatos {
  ClaveBaseDatos([FlutterSecureStorage? almacen])
    : _almacen = almacen ?? const FlutterSecureStorage();

  static const nombre = 'notemed_clave_bd';
  final FlutterSecureStorage _almacen;

  Future<String> obtener() async {
    final guardada = await _almacen.read(key: nombre);
    if (guardada != null && guardada.isNotEmpty) return guardada;
    final nueva = generar();
    await _almacen.write(key: nombre, value: nueva);
    return nueva;
  }

  static String generar([Random? azar]) {
    final r = azar ?? Random.secure();
    return base64UrlEncode([for (var i = 0; i < 32; i++) r.nextInt(256)]);
  }
}
