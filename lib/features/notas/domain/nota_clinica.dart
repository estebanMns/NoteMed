/// HU05: nota clínica guardada (borrador o firmada).
///
/// Una nota firmada no se puede modificar (Ley 911 de 2004, art. 38: sin
/// tachaduras ni enmendaduras; Resolución 1995 de 1999). Para corregirla se
/// agrega una nota aclaratoria firmada que la referencia.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:notemed/features/notas/domain/firma_enfermera.dart';

enum TipoNota {
  turno('Nota de turno'),
  evolucion('Nota de evolución'),
  traslado('Nota de traslado'),
  fallecimiento('Nota de fallecimiento'),
  aclaracion('Nota aclaratoria');

  const TipoNota(this.etiqueta);
  final String etiqueta;

  /// Las notas aclaratorias las escribe la enfermera; las demás las redacta
  /// la IA como borrador.
  bool get generadaPorIA => this != aclaracion;
}

enum EstadoNota { borrador, firmada }

/// Se intentó cambiar una nota que ya estaba firmada.
class NotaFirmadaInmutable implements Exception {
  const NotaFirmadaInmutable([this.id]);
  final int? id;

  @override
  String toString() =>
      'La nota ya está firmada y no se puede modificar. '
      'Agregue una nota aclaratoria.';
}

class NotaClinica {
  const NotaClinica({
    this.id,
    required this.pacienteId,
    required this.tipo,
    required this.texto,
    required this.creada,
    this.referencia = const {},
    this.firma,
    this.versionPrompts,
    this.aclaraA,
    this.hash,
  });

  final int? id;
  final int pacienteId;
  final TipoNota tipo;
  final String texto;
  final DateTime creada;

  /// Datos con los que se revisa el texto: los signos vitales (turno) o la
  /// solicitud original (fallecimiento).
  final Map<String, Object?> referencia;

  /// `null` mientras sea borrador.
  final FirmaEnfermera? firma;

  /// Versión de los prompts con que la IA generó el borrador.
  final String? versionPrompts;

  /// En una nota aclaratoria: id de la nota firmada que aclara.
  final int? aclaraA;

  /// SHA-256 del contenido firmado. Permite detectar si la nota se alteró
  /// después de la firma.
  final String? hash;

  EstadoNota get estado =>
      firma == null ? EstadoNota.borrador : EstadoNota.firmada;

  bool get firmada => firma != null;

  NotaClinica _copia({
    int? id,
    String? texto,
    FirmaEnfermera? firma,
    String? hash,
  }) => NotaClinica(
    id: id ?? this.id,
    pacienteId: pacienteId,
    tipo: tipo,
    texto: texto ?? this.texto,
    creada: creada,
    referencia: referencia,
    firma: firma ?? this.firma,
    versionPrompts: versionPrompts,
    aclaraA: aclaraA,
    hash: hash ?? this.hash,
  );

  NotaClinica conId(int id) => _copia(id: id);

  /// Devuelve la nota firmada con [textoFinal]. Lanza [NotaFirmadaInmutable]
  /// si ya estaba firmada.
  NotaClinica firmar(String textoFinal, FirmaEnfermera f) {
    if (firmada) throw NotaFirmadaInmutable(id);
    final sinHash = _copia(texto: textoFinal, firma: f);
    return sinHash._copia(hash: sinHash.calcularHash());
  }

  /// Hash del contenido que respalda la firma: paciente, tipo, texto, fechas,
  /// tarjeta profesional, trazos de la firma y nota aclarada.
  String calcularHash() {
    final f = firma;
    final contenido = jsonEncode({
      'pacienteId': pacienteId,
      'tipo': tipo.name,
      'texto': texto,
      'creada': creada.toIso8601String(),
      'aclaraA': aclaraA,
      'versionPrompts': versionPrompts,
      'firma': f?.toMap(),
    });
    return sha256.convert(utf8.encode(contenido)).toString();
  }

  /// `true` si la nota está firmada y su contenido no cambió desde la firma.
  bool get integra => firmada && hash != null && hash == calcularHash();
}
