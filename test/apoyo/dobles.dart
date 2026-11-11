// Dobles de prueba: IA simulada, red simulada y repositorio en memoria.
import 'dart:async';

import 'package:notemed/core/datos/estado_red.dart';
import 'package:notemed/core/datos/repositorio_pacientes.dart';
import 'package:notemed/core/datos/solicitud_pendiente.dart';
import 'package:notemed/core/ia/servicio_ia.dart';
import 'package:notemed/features/nota/nota_clinica.dart';
import 'package:notemed/features/paciente/infusion.dart';
import 'package:notemed/features/paciente/paciente.dart';
import 'package:notemed/features/paciente/signos_vitales.dart';
import 'package:notemed/features/procedimientos/procedimiento_invasivo.dart';
import 'package:notemed/features/riesgos/braden/braden_escala.dart';
import 'package:notemed/features/riesgos/downton/downton_escala.dart';

/// IA que guarda lo que recibe y responde con [responder].
class IASimulada implements ServicioIA {
  IASimulada([this.responder]);

  String Function(String sistema, String usuario)? responder;
  Object? error;
  final List<({String sistema, String usuario})> recibidas = [];

  @override
  Future<String> generar({
    required String sistema,
    required String usuario,
  }) async {
    recibidas.add((sistema: sistema, usuario: usuario));
    if (error != null) throw error!;
    return responder?.call(sistema, usuario) ?? 'Nota generada.';
  }
}

/// Red que se enciende y apaga desde la prueba.
class RedSimulada implements EstadoRed {
  RedSimulada({bool conectada = true}) : _estado = conectada;

  bool _estado;
  final _cambios = StreamController<bool>.broadcast();

  set conectada(bool v) {
    if (v == _estado) return;
    _estado = v;
    _cambios.add(v);
  }

  bool get conectada => _estado;

  @override
  Future<bool> conectado() async => _estado;

  @override
  Stream<bool> get cambios => _cambios.stream;

  Future<void> cerrar() => _cambios.close();
}

const pacienteEjemplo = Paciente(
  nombre: 'María Fernanda Gómez',
  cedula: '1085123456',
  edad: 67,
  cama: '12B',
);

/// Repositorio en memoria para las pruebas de widgets.
class RepositorioMemoria implements RepositorioPacientes {
  final Map<int, Paciente> _pacientes = {};
  final Map<int, SignosVitales> _signos = {};
  final Map<int, Infusion> _infusiones = {};
  final Map<int, int> _infusionPaciente = {};
  final Map<int, List<ProcedimientoInvasivo>> _procedimientos = {};
  final Map<int, EvaluacionDownton> _downton = {};
  final Map<int, EvaluacionBraden> _braden = {};
  final Map<int, NotaClinica> _notas = {};
  final Map<int, SolicitudPendiente> _cola = {};
  int _sec = 0;

  @override
  Future<Paciente> guardarPaciente(Paciente p) async {
    final dup = _pacientes.values.any(
      (x) => x.cedula == p.cedula && x.id != p.id,
    );
    if (dup) throw PacienteDuplicado(p.cedula);
    final g = p.id == null ? p.conId(++_sec) : p;
    _pacientes[g.id!] = g;
    return g;
  }

  @override
  Future<List<Paciente>> pacientes() async => _pacientes.values.toList();

  @override
  Future<Paciente?> paciente(int id) async => _pacientes[id];

  @override
  Future<void> eliminarPaciente(int id) async => _pacientes.remove(id);

  @override
  Future<void> guardarSignos(int pacienteId, SignosVitales s) async =>
      _signos[pacienteId] = s;

  @override
  Future<SignosVitales> signos(int pacienteId) async =>
      _signos[pacienteId] ?? const SignosVitales();

  @override
  Future<Infusion> agregarInfusion(int pacienteId, Infusion i) async {
    final g = i.conId(++_sec);
    _infusiones[g.id!] = g;
    _infusionPaciente[g.id!] = pacienteId;
    return g;
  }

  @override
  Future<void> eliminarInfusion(int id) async => _infusiones.remove(id);

  @override
  Future<List<Infusion>> infusiones(int pacienteId) async => [
    for (final e in _infusiones.entries)
      if (_infusionPaciente[e.key] == pacienteId) e.value,
  ];

  @override
  Future<ProcedimientoInvasivo> agregarProcedimiento(
    int pacienteId,
    ProcedimientoInvasivo p,
  ) async {
    final g = p.conId(++_sec);
    (_procedimientos[pacienteId] ??= []).add(g);
    return g;
  }

  @override
  Future<List<ProcedimientoInvasivo>> procedimientos(int pacienteId) async =>
      List.of(_procedimientos[pacienteId] ?? const []);

  @override
  Future<void> guardarDownton(int pacienteId, EvaluacionDownton e) async =>
      _downton[pacienteId] = e;

  @override
  Future<EvaluacionDownton?> downton(int pacienteId) async =>
      _downton[pacienteId];

  @override
  Future<void> guardarBraden(int pacienteId, EvaluacionBraden e) async =>
      _braden[pacienteId] = e;

  @override
  Future<EvaluacionBraden?> braden(int pacienteId) async => _braden[pacienteId];

  @override
  Future<NotaClinica> guardarNota(NotaClinica n) async {
    final g = n.id == null ? n.conId(++_sec) : n;
    _notas[g.id!] = g;
    return g;
  }

  @override
  Future<List<NotaClinica>> notas(int pacienteId) async => [
    for (final n in _notas.values.toList().reversed)
      if (n.pacienteId == pacienteId) n,
  ];

  @override
  Future<SolicitudPendiente> encolar(SolicitudPendiente s) async {
    final g = s.conId(++_sec);
    _cola[g.id!] = g;
    return g;
  }

  @override
  Future<List<SolicitudPendiente>> pendientes() async => _cola.values.toList();

  @override
  Future<void> eliminarPendiente(int id) async => _cola.remove(id);

  @override
  Future<void> registrarIntento(int id, String error) async {
    final s = _cola[id]!;
    _cola[id] = SolicitudPendiente(
      id: id,
      pacienteId: s.pacienteId,
      tipo: s.tipo,
      datos: s.datos,
      creada: s.creada,
      intentos: s.intentos + 1,
      ultimoError: error,
    );
  }
}
