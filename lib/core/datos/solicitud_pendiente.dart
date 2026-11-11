/// TSK-28 · HU07: solicitud a la IA que no se pudo enviar por falta de red.
/// Queda guardada en la base local hasta que vuelva la conexión.
library;

import '../../features/nota/nota_clinica.dart';

class SolicitudPendiente {
  const SolicitudPendiente({
    this.id,
    required this.pacienteId,
    required this.tipo,
    required this.datos,
    required this.creada,
    this.intentos = 0,
    this.ultimoError,
  });

  final int? id;
  final int pacienteId;
  final TipoNota tipo;

  /// Datos completos para volver a generar la nota (ver `DatosTurno.toMap`).
  final Map<String, Object?> datos;
  final DateTime creada;
  final int intentos;
  final String? ultimoError;

  SolicitudPendiente conId(int id) => SolicitudPendiente(
    id: id,
    pacienteId: pacienteId,
    tipo: tipo,
    datos: datos,
    creada: creada,
    intentos: intentos,
    ultimoError: ultimoError,
  );
}
