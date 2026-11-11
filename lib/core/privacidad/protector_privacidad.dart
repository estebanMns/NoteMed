/// TSK-29 / TSK-31 · HU08: oculta los datos personales del paciente antes de
/// enviar una solicitud a la IA y los restaura en la respuesta que se muestra
/// en el celular (Ley 1581 de 2012).
///
/// Cada solicitud usa su propio [ProtectorPrivacidad]: la tabla para
/// restaurar solo vive en memoria y nunca se envía ni se guarda.
library;

import 'anonimizador.dart';

/// Se lanza si, después de anonimizar, el texto todavía tiene algo que
/// parezca un dato personal. En ese caso la solicitud no se envía.
class DatosPersonalesExpuestos implements Exception {
  const DatosPersonalesExpuestos();

  @override
  String toString() =>
      'La solicitud todavía contiene datos personales y no se envió a la IA.';
}

class ProtectorPrivacidad {
  ProtectorPrivacidad({
    required this.nombre,
    required this.cedula,
    required this.cama,
  });

  final String nombre;
  final String cedula;
  final String cama;

  final Anonimizador _anonimizador = Anonimizador();

  /// TSK-29: reemplaza nombre, cédula y cama (y otros datos que reconozca el
  /// [Anonimizador]) por códigos. Lanza [DatosPersonalesExpuestos] si queda
  /// algún dato sin ocultar.
  String ocultar(String texto) {
    // La cédula se escribe sin puntos para que el anonimizador la reconozca
    // siempre igual, sin importar cómo la digitaron.
    final cedulaDigitos = cedula.replaceAll(RegExp(r'\D'), '');
    var entrada = texto;
    if (cedula.trim().isNotEmpty && cedulaDigitos.isNotEmpty) {
      entrada = entrada.replaceAll(cedula.trim(), cedulaDigitos);
    }
    final salida = _anonimizador.anonimizar(
      entrada,
      nombresConocidos: [nombre],
    );
    if (Anonimizador.contieneDatosPersonales(salida, nombres: [nombre])) {
      throw const DatosPersonalesExpuestos();
    }
    return salida;
  }

  /// Código → valor real que se muestra al restaurar.
  Map<String, String> get _valores {
    final valores = Map.of(_anonimizador.originales);
    final tabla = _anonimizador.tablaReidentificacion;
    final pac = tabla['PAC|${Anonimizador.normalizar(nombre)}'];
    if (pac != null) valores[pac] = nombre.trim();
    final id = tabla['ID|${cedula.replaceAll(RegExp(r'\D'), '')}'];
    if (id != null) valores[id] = cedula.trim();
    return valores;
  }

  /// TSK-31: cambia los códigos de [respuesta] por los datos reales. Los
  /// códigos que no salieron de esta solicitud se dejan igual.
  String restaurar(String respuesta) {
    final valores = _valores;
    // Si la IA escribe "cama CAMA-001", se evita repetir la palabra "cama".
    final conPalabraCama = RegExp(
      r'(?<![\p{L}])cama\s+(CAMA-\d{3,})(?!\d)',
      caseSensitive: false,
      unicode: true,
    );
    final sinDuplicar = respuesta.replaceAllMapped(conPalabraCama, (m) {
      final original = valores[m[1]!];
      return original ?? m[0]!;
    });
    return sinDuplicar.replaceAllMapped(
      Anonimizador.codigoAnonimo,
      (m) => valores[m[0]!] ?? m[0]!,
    );
  }
}
