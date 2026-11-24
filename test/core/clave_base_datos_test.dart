import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notemed/core/datos/clave_base_datos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la clave tiene 256 bits aleatorios', () {
    final a = ClaveBaseDatos.generar();
    expect(base64Url.decode(a), hasLength(32));
    expect(ClaveBaseDatos.generar(), isNot(a));
  });

  test('se genera una vez y se guarda en el almacenamiento seguro', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final clave = ClaveBaseDatos();
    final primera = await clave.obtener();
    expect(await clave.obtener(), primera);
    expect(
      await const FlutterSecureStorage().read(key: ClaveBaseDatos.nombre),
      primera,
    );
  });

  test('usa la clave que ya estaba guardada', () async {
    FlutterSecureStorage.setMockInitialValues({ClaveBaseDatos.nombre: 'abc'});
    expect(await ClaveBaseDatos().obtener(), 'abc');
  });
}
