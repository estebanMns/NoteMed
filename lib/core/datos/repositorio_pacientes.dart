/// TSK-25 · HU07: acceso a los datos de los pacientes guardados en el
/// celular. La implementación de la app es [RepositorioSqlite].
library;

import '../../features/nota/nota_clinica.dart';
import '../../features/paciente/infusion.dart';
import '../../features/paciente/paciente.dart';
import '../../features/paciente/signos_vitales.dart';
import '../../features/procedimientos/procedimiento_invasivo.dart';
import '../../features/riesgos/braden/braden_escala.dart';
import '../../features/riesgos/downton/downton_escala.dart';
import 'solicitud_pendiente.dart';

/// Ya existe un paciente con la misma cédula.
class PacienteDuplicado implements Exception {
  const PacienteDuplicado(this.cedula);
  final String cedula;

  @override
  String toString() => 'Ya existe un paciente con la cédula $cedula.';
}

abstract interface class RepositorioPacientes {
  /// Crea el paciente si no tiene id, o lo actualiza. Lanza
  /// [PacienteDuplicado] si la cédula ya existe.
  Future<Paciente> guardarPaciente(Paciente p);
  Future<List<Paciente>> pacientes();
  Future<Paciente?> paciente(int id);

  /// Borra el paciente y todo lo que tiene registrado.
  Future<void> eliminarPaciente(int id);

  Future<void> guardarSignos(int pacienteId, SignosVitales s);
  Future<SignosVitales> signos(int pacienteId);

  Future<Infusion> agregarInfusion(int pacienteId, Infusion i);
  Future<void> eliminarInfusion(int id);
  Future<List<Infusion>> infusiones(int pacienteId);

  Future<ProcedimientoInvasivo> agregarProcedimiento(
    int pacienteId,
    ProcedimientoInvasivo p,
  );
  Future<List<ProcedimientoInvasivo>> procedimientos(int pacienteId);

  Future<void> guardarDownton(int pacienteId, EvaluacionDownton e);
  Future<EvaluacionDownton?> downton(int pacienteId);
  Future<void> guardarBraden(int pacienteId, EvaluacionBraden e);
  Future<EvaluacionBraden?> braden(int pacienteId);

  /// Crea la nota si no tiene id, o la actualiza (por ejemplo al firmar).
  Future<NotaClinica> guardarNota(NotaClinica n);

  /// Notas del paciente, de la más reciente a la más antigua.
  Future<List<NotaClinica>> notas(int pacienteId);

  // TSK-28: cola de solicitudes a la IA hechas sin conexión.
  Future<SolicitudPendiente> encolar(SolicitudPendiente s);
  Future<List<SolicitudPendiente>> pendientes();
  Future<void> eliminarPendiente(int id);
  Future<void> registrarIntento(int id, String error);
}
