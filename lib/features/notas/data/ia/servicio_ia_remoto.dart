/// Cliente del backend de NoteMed (componente de IA). El backend guarda la
/// clave del modelo de lenguaje y orquesta los prompts; la app solo envía
/// la solicitud ya anonimizada. Contrato en `docs/contrato_api.md`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:notemed/features/notas/domain/prompts/version_prompts.dart';
import 'package:notemed/features/notas/domain/servicio_ia.dart';

class ServicioIARemoto implements ServicioIA {
  ServicioIARemoto({
    required this.urlBase,
    this.token,
    http.Client? cliente,
    this.tiempoMaximo = const Duration(seconds: 90),
  }) : _cliente = cliente ?? http.Client();

  /// Por ejemplo `https://notemed.hospital.local/api`.
  final String urlBase;

  /// Token de la sesión (Bearer), si el backend lo exige.
  final String? Function()? token;
  final Duration tiempoMaximo;
  final http.Client _cliente;

  static const ruta = '/v1/ia/borradores';

  @override
  bool get funcionaSinRed => false;

  @override
  Future<String> generar({
    required String sistema,
    required String usuario,
  }) async {
    final t = token?.call();
    final http.Response r;
    try {
      r = await _cliente
          .post(
            Uri.parse('$urlBase$ruta'),
            headers: {
              'content-type': 'application/json',
              if (t != null) 'authorization': 'Bearer $t',
            },
            body: jsonEncode({
              'versionPrompts': versionPrompts,
              'sistema': sistema,
              'solicitud': usuario,
            }),
          )
          .timeout(tiempoMaximo);
    } on TimeoutException {
      throw const ErrorIA('El servidor tardó demasiado.', sinConexion: true);
    } on http.ClientException catch (e) {
      throw ErrorIA(
        'No hay conexión con el servidor: ${e.message}',
        sinConexion: true,
      );
    }

    Map<String, Object?> json;
    try {
      json = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, Object?>;
    } on FormatException {
      json = const {};
    }

    if (r.statusCode != 200) {
      final detalle = json['error'] as String?;
      throw ErrorIA(
        'El servidor respondió con error (HTTP ${r.statusCode})'
        '${detalle == null ? '.' : ': $detalle'}',
        codigo: r.statusCode,
        sinConexion: r.statusCode == 429 || r.statusCode >= 500,
      );
    }
    final texto = (json['texto'] as String? ?? '').trim();
    if (texto.isEmpty) {
      throw const ErrorIA('El servidor devolvió una nota vacía.');
    }
    return texto;
  }
}
