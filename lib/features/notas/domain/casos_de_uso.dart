/// Casos de uso de la generación y firma de notas (PDF §3.6, capa de casos de
/// uso). Solo dependen de dominio y de los puertos, nunca de Flutter.
library;

import '../../../core/privacidad/anonimizador.dart';
import '../../../core/validacion/filtro_siglas.dart';
import 'llm_gateway.dart';
import 'nota_clinica.dart';

/// Resultado del borrador: el texto ya re-identificado y los hallazgos del
/// filtro de siglas. Si hay hallazgos, la enfermera debe corregirlos antes de
/// poder firmar.
class ResultadoBorrador {
  const ResultadoBorrador({required this.texto, required this.hallazgos});

  final String texto;
  final List<Hallazgo> hallazgos;

  bool get listoParaRevisar => hallazgos.isEmpty;
}

/// Instrucciones (prompts) por tipo de nota. Están versionadas en código; el
/// PDF pide tratarlas como código y evaluarlas con casos sintéticos.
const String promptVersion = 'v1';

const String _base =
    'Eres asistente de documentación de enfermería en UCI. Redacta una nota '
    'en español usando SOLO los datos recibidos. No inventes datos ni '
    'diagnósticos. Usa los códigos PAC-###, CAMA-### e ID-### tal como '
    'aparecen. Usa solo siglas aprobadas (TA, FC, FR, SpO2, IV, VO, UCI). '
    'Devuelve texto narrativo sin opiniones.';

String instruccionPara(TipoNota tipo) => '$_base\nTipo de nota: '
    '${tipo.etiqueta}.';

class GenerarBorrador {
  const GenerarBorrador({
    required this.llm,
    this.filtro = const FiltroSiglas(),
  });

  final LlmGateway llm;
  final FiltroSiglas filtro;

  /// [datos] son los datos estructurados de la valoración (texto).
  /// [nombresPacientes] son los nombres completos conocidos; se usan para
  /// anonimizar antes de enviar y para re-identificar la respuesta.
  Future<ResultadoBorrador> ejecutar({
    required TipoNota tipo,
    required String datos,
    required Iterable<String> nombresPacientes,
  }) async {
    final nombres = nombresPacientes.toList();
    final anon = Anonimizador();
    final entrada = anon.anonimizar(datos, nombresConocidos: nombres);

    // Barrera de seguridad: si algo identificable sobrevive, no se envía.
    if (Anonimizador.contieneDatosPersonales(entrada, nombres: nombres)) {
      throw StateError(
          'Quedan datos personales en la entrada; no se envía al modelo.');
    }

    final salida = await llm.generar(
      instruccion: instruccionPara(tipo),
      contexto: entrada,
    );

    final texto = reidentificar(salida, anon, nombres);
    return ResultadoBorrador(
      texto: texto,
      hallazgos: filtro.analizar(texto),
    );
  }

  /// Vuelve a poner nombre, cama e ID a partir de la tabla en memoria de la
  /// misma instancia de [Anonimizador]. Nunca se persiste la tabla.
  static String reidentificar(
    String texto,
    Anonimizador anon,
    List<String> nombres,
  ) {
    var salida = texto;
    for (final e in anon.tablaReidentificacion.entries) {
      final sep = e.key.indexOf('|');
      final prefijo = e.key.substring(0, sep);
      final clave = e.key.substring(sep + 1);
      final original =
          prefijo == 'PAC' ? _nombreOriginal(clave, nombres) : clave;
      salida = salida.replaceAll(
        RegExp('${RegExp.escape(e.value)}(?!\\d)'),
        original,
      );
    }
    return salida;
  }

  static String _nombreOriginal(String claveNormalizada, List<String> nombres) {
    for (final n in nombres) {
      final limpio = n.trim().split(RegExp(r'\s+')).join(' ');
      if (Anonimizador.normalizar(limpio) == claveNormalizada) return limpio;
    }
    return claveNormalizada;
  }
}

/// Firma una nota revisada. Reglas (PDF §1.8, Ley 911 art. 38):
///  * debe estar en estado `revisada`;
///  * no puede estar vacía;
///  * no puede contener siglas prohibidas o desconocidas.
class FirmarNota {
  const FirmarNota({this.filtro = const FiltroSiglas()});

  final FiltroSiglas filtro;

  NotaClinica ejecutar(
    NotaClinica nota, {
    required String firmante,
    required DateTime ahora,
  }) {
    final motivos = <String>[];
    if (firmante.trim().isEmpty) {
      motivos.add('Falta el firmante.');
    }
    if (nota.estado != EstadoNota.revisada) {
      motivos.add('La nota debe revisarse antes de firmar.');
    }
    if (nota.texto.trim().isEmpty) {
      motivos.add('La nota está vacía.');
    }
    motivos.addAll(filtro.analizar(nota.texto).map((h) => h.mensaje));

    if (motivos.isNotEmpty) throw NotaNoFirmableException(motivos);
    return nota.firmar(firmante: firmante.trim(), ahora: ahora);
  }
}
