/// IA simulada para desarrollo, pruebas en el hospital sin backend y uso sin
/// internet. Es determinista: arma la nota copiando los datos de la
/// solicitud en el formato que piden las instrucciones, así que nunca
/// inventa valores. No reemplaza al modelo de lenguaje real: la redacción es
/// mecánica y sirve para probar el flujo completo (Human-in-the-Loop).
library;

import 'package:notemed/features/notas/domain/servicio_ia.dart';

class ServicioIASimulado implements ServicioIA {
  const ServicioIASimulado({this.demora = const Duration(milliseconds: 600)});

  /// Pausa para que la pantalla muestre "Generando nota…" como con la IA real.
  final Duration demora;

  @override
  bool get funcionaSinRed => true;

  @override
  Future<String> generar({
    required String sistema,
    required String usuario,
  }) async {
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    final campos = leerCampos(usuario);
    final s = sistema.toLowerCase();
    if (s.contains('nota de enfermería de fallecimiento')) {
      return _fallecimiento(campos);
    }
    if (s.contains('nota de traslado')) return _traslado(campos);
    if (s.contains('nota de evolución')) return _evolucion(campos);
    return _turno(campos);
  }

  /// Convierte las líneas `Etiqueta: valor` de la solicitud en un mapa. Las
  /// líneas que empiezan con `- ` son elementos de la lista anterior.
  static Map<String, String> leerCampos(String solicitud) {
    final campos = <String, String>{};
    String? actual;
    for (final linea in solicitud.split('\n')) {
      final t = linea.trim();
      if (t.isEmpty) continue;
      final m = RegExp(r'^([^:\-][^:]*):\s*(.*)$').firstMatch(t);
      if (m != null && !t.startsWith('- ')) {
        actual = m[1]!.trim();
        campos[actual] = m[2]!.trim();
      } else if (actual != null) {
        final item = t.startsWith('- ') ? t.substring(2) : t;
        final previo = campos[actual]!;
        campos[actual] = previo.isEmpty ? item : '$previo; $item';
      }
    }
    return campos;
  }

  static String _punto(String t) {
    final x = t.trim();
    if (x.isEmpty) return x;
    return RegExp(r'[.!?]$').hasMatch(x) ? x : '$x.';
  }

  static String _valor(Map<String, String> c, String clave) {
    final v = (c[clave] ?? '').trim();
    return v.isEmpty ? 'No registrado' : v;
  }

  /// `PAC-001, cédula ID-001, 67 años, CAMA-001` → identificación sin la
  /// cédula, que no hace falta en el texto de la nota.
  static String _identificacion(Map<String, String> c) {
    final partes = (c['Paciente'] ?? '').split(',').map((p) => p.trim());
    final nombre = partes.isEmpty ? 'Paciente' : partes.first;
    final edad = partes.firstWhere((p) => p.endsWith('años'), orElse: () => '');
    final cama = partes
        .firstWhere((p) => p.toLowerCase().startsWith('cama'), orElse: () => '')
        .replaceFirst(RegExp('^cama ', caseSensitive: false), '');
    return [
      'Paciente $nombre',
      if (edad.isNotEmpty) 'de $edad',
      if (cama.isNotEmpty) 'en cama $cama',
    ].join(' ');
  }

  static String _datosClinicos(Map<String, String> c) => [
    'Signos vitales: ${_valor(c, 'Signos vitales')}.',
    'Infusiones: ${_valor(c, 'Infusiones')}.',
    'Procedimientos invasivos: ${_valor(c, 'Procedimientos invasivos')}.',
  ].join(' ');

  static String _escalas(Map<String, String> c) => [
    _punto(
      c.containsKey('Escala de Downton')
          ? 'Escala de Downton: ${c['Escala de Downton']}'
          : 'Escala de Downton: No registrada',
    ),
    _punto(
      c.containsKey('Escala de Braden')
          ? 'Escala de Braden: ${c['Escala de Braden']}'
          : 'Escala de Braden: No registrada',
    ),
    if (c.containsKey('PROM')) _punto('Valoración PROM: ${c['PROM']}'),
  ].join(' ');

  static String _observaciones(Map<String, String> c) {
    final o = (c['Observaciones de enfermería'] ?? '').trim();
    return o.isEmpty || o == 'Ninguna'
        ? 'Sin observaciones adicionales registradas.'
        : 'Observaciones de enfermería: ${_punto(o)}';
  }

  static String _turno(Map<String, String> c) => [
    '[S] Situación: ${_identificacion(c)}, en la UCI. '
        'Signos vitales: ${_valor(c, 'Signos vitales')}.',
    '[B] Antecedentes: Infusiones: ${_valor(c, 'Infusiones')}. '
        'Procedimientos invasivos: ${_valor(c, 'Procedimientos invasivos')}.',
    '[A] Evaluación: ${_escalas(c)}',
    '[R] Recomendación: ${_observaciones(c)} '
        'Continuar el plan de cuidados registrado.',
  ].join('\n');

  static String _evolucion(Map<String, String> c) => [
    '${_identificacion(c)}, en la UCI.',
    _datosClinicos(c),
    _escalas(c),
    _observaciones(c),
  ].join('\n');

  static String _traslado(Map<String, String> c) => [
    'Traslado: ${_identificacion(c)}, desde la UCI hacia '
        '${_valor(c, 'Destino')}.',
    'Motivo: ${_punto(_valor(c, 'Motivo del traslado'))}',
    'Condición al traslado: ${_datosClinicos(c)} '
        'Estado de conciencia: ${_punto(_valor(c, 'Estado de conciencia'))}',
    'Medio y acompañamiento: ${_valor(c, 'Medio de transporte')}, '
        'acompañado por ${_valor(c, 'Acompañante')}. '
        'Recibe: ${_punto(_valor(c, 'Recibe'))}',
    _observaciones(c),
  ].join('\n');

  static String _fallecimiento(Map<String, String> c) => [
    'Fecha y hora del fallecimiento: '
        '${_valor(c, 'Fecha y hora del fallecimiento')}',
    'Certificado por: ${_valor(c, 'Certificado por')}',
    'Hallazgos: ${_valor(c, 'Signos observados')}',
    'Maniobras de reanimación: ${_valor(c, 'Maniobras de reanimación')}',
    'Dispositivos invasivos presentes: '
        '${_valor(c, 'Dispositivos invasivos presentes')}',
    'Cuidados post mortem: ${_valor(c, 'Cuidados post mortem realizados')}',
    'Información y entrega: ${_valor(c, 'Información y entrega a')}',
    'Observaciones: ${_valor(c, 'Observaciones')}',
  ].join('\n');
}
