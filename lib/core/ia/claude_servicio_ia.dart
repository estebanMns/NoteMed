/// TSK-11 · HU03: implementación de [ServicioIA] con la API de Claude
/// (Anthropic). Dart no tiene SDK oficial, así que se usa HTTP directo.
///
/// La clave se pasa al compilar con `--dart-define=ANTHROPIC_API_KEY=...`.
/// Una clave dentro de la app se puede extraer del binario: para producción
/// conviene poner un servidor intermedio y cambiar [url].
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'servicio_ia.dart';

class ClaudeServicioIA implements ServicioIA {
  ClaudeServicioIA({
    required this.apiKey,
    http.Client? cliente,
    this.modelo = 'claude-opus-5-5',
    this.esfuerzo = 'medium',
    this.url = 'https://api.anthropic.com/v1/messages',
    this.tiempoMaximo = const Duration(seconds: 120),
  }) : _cliente = cliente ?? http.Client();

  final String apiKey;
  final String modelo;

  /// Nivel de esfuerzo (`low`, `medium`, `high`...). Una nota de turno no
  /// necesita más que `medium`.
  final String esfuerzo;
  final String url;
  final Duration tiempoMaximo;
  final http.Client _cliente;

  static const versionApi = '2026-10-21';

  /// Si un clasificador de seguridad declina la solicitud, la API la reintenta
  /// en el modelo de respaldo recomendado.
  static const betaRespaldo = 'server-side-fallback-2026-07-01';

  Map<String, String> get _encabezados => {
    'content-type': 'application/json',
    'x-api-key': apiKey,
    'anthropic-version': versionApi,
    'anthropic-beta': betaRespaldo,
  };

  Map<String, Object?> cuerpo({
    required String sistema,
    required String usuario,
  }) => {
    'model': modelo,
    'max_tokens': 16000,
    'system': sistema,
    'messages': [
      {'role': 'user', 'content': usuario},
    ],
    'output_config': {'effort': esfuerzo},
    'fallbacks': 'default',
  };

  @override
  Future<String> generar({
    required String sistema,
    required String usuario,
  }) async {
    final http.Response r;
    try {
      r = await _cliente
          .post(
            Uri.parse(url),
            headers: _encabezados,
            body: jsonEncode(cuerpo(sistema: sistema, usuario: usuario)),
          )
          .timeout(tiempoMaximo);
    } on TimeoutException {
      throw const ErrorIA(
        'La IA tardó demasiado en responder.',
        sinConexion: true,
      );
    } on http.ClientException catch (e) {
      throw ErrorIA(
        'No hay conexión con la IA: ${e.message}',
        sinConexion: true,
      );
    }

    final Map<String, Object?> json;
    try {
      json = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, Object?>;
    } on FormatException {
      throw ErrorIA(
        'Respuesta inválida de la IA (HTTP ${r.statusCode}).',
        codigo: r.statusCode,
      );
    }

    if (r.statusCode != 200) {
      final error = json['error'];
      final detalle = error is Map ? error['message'] : null;
      throw ErrorIA(
        _mensajeHttp(r.statusCode, detalle as String?),
        codigo: r.statusCode,
        // 429, 5xx y 529 (sobrecarga) se pueden reintentar más tarde.
        sinConexion: r.statusCode == 429 || r.statusCode >= 500,
      );
    }

    switch (json['stop_reason']) {
      case 'refusal':
        throw const ErrorIA(
          'La IA declinó redactar esta nota. '
          'Revise los datos o redacte la nota manualmente.',
        );
      case 'max_tokens':
        throw const ErrorIA('La respuesta de la IA quedó incompleta.');
    }

    final texto = [
      for (final b in (json['content'] as List? ?? const []))
        if (b is Map && b['type'] == 'text') b['text'] as String,
    ].join().trim();
    if (texto.isEmpty) throw const ErrorIA('La IA devolvió una nota vacía.');
    return texto;
  }

  static String _mensajeHttp(int codigo, String? detalle) {
    final base = switch (codigo) {
      400 => 'Solicitud inválida',
      401 => 'Clave de la API inválida',
      403 => 'Sin permiso para usar la API',
      429 => 'Límite de solicitudes alcanzado; intente más tarde',
      >= 500 => 'El servicio de IA no está disponible; intente más tarde',
      _ => 'Error de la IA',
    };
    return detalle == null
        ? '$base (HTTP $codigo).'
        : '$base (HTTP $codigo): $detalle';
  }
}
