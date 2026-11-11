/// HU03 / HU04 / HU07: pide las notas a la IA, guarda el borrador en la base
/// local y, si no hay red, deja la solicitud en la cola (TSK-28).
library;

import '../../core/datos/cola_sincronizacion.dart';
import '../../core/datos/estado_red.dart';
import '../../core/datos/repositorio_pacientes.dart';
import '../../core/datos/solicitud_pendiente.dart';
import '../../core/ia/servicio_ia.dart';
import '../fallecimiento/nota_fallecimiento.dart';
import '../paciente/paciente.dart';
import '../paciente/signos_vitales.dart';
import '../procedimientos/procedimiento_invasivo.dart';
import '../turno/generador_nota_turno.dart';
import 'borrador_screen.dart';
import 'nota_clinica.dart';
import 'revision_nota.dart';

sealed class ResultadoSolicitud {
  const ResultadoSolicitud();
}

/// La IA respondió y el borrador quedó guardado.
class BorradorGuardado extends ResultadoSolicitud {
  const BorradorGuardado(this.nota);
  final NotaClinica nota;
}

/// No había red: la solicitud quedó en la cola.
class SolicitudEnCola extends ResultadoSolicitud {
  const SolicitudEnCola(this.solicitud);
  final SolicitudPendiente solicitud;
}

class ServicioNotas {
  ServicioNotas({
    required this.repositorio,
    required ServicioIA ia,
    required this.red,
    DateTime Function()? ahora,
  }) : _turno = GeneradorNotaTurno(ia),
       _fallecimiento = GeneradorNotaFallecimiento(ia),
       _ahora = ahora ?? DateTime.now {
    cola = ColaSincronizacion(
      repositorio: repositorio,
      red: red,
      procesar: _procesarPendiente,
    );
  }

  final RepositorioPacientes repositorio;
  final EstadoRed red;
  final GeneradorNotaTurno _turno;
  final GeneradorNotaFallecimiento _fallecimiento;
  final DateTime Function() _ahora;
  late final ColaSincronizacion cola;

  /// Reúne lo registrado del paciente en la base local.
  Future<DatosTurno> datosTurno(Paciente p, {String observaciones = ''}) async {
    final id = p.id!;
    return DatosTurno(
      paciente: p,
      signos: await repositorio.signos(id),
      infusiones: await repositorio.infusiones(id),
      downton: await repositorio.downton(id),
      braden: await repositorio.braden(id),
      procedimientos: await repositorio.procedimientos(id),
      observaciones: observaciones,
    );
  }

  Future<ResultadoSolicitud> notaTurno(DatosTurno d) => _solicitar(
    SolicitudPendiente(
      pacienteId: d.paciente.id!,
      tipo: TipoNota.turno,
      datos: d.toMap(),
      creada: _ahora(),
    ),
  );

  Future<ResultadoSolicitud> notaFallecimiento(
    Paciente p,
    DatosFallecimiento f, {
    List<ProcedimientoInvasivo> procedimientos = const [],
  }) => _solicitar(
    SolicitudPendiente(
      pacienteId: p.id!,
      tipo: TipoNota.fallecimiento,
      datos: {
        'paciente': p.toMap(),
        'fallecimiento': f.toMap(),
        'procedimientos': [for (final x in procedimientos) x.toMap()],
      },
      creada: _ahora(),
    ),
  );

  Future<ResultadoSolicitud> _solicitar(SolicitudPendiente s) async {
    if (!await red.conectado()) {
      return SolicitudEnCola(await cola.encolar(s));
    }
    try {
      return BorradorGuardado(await _generar(s));
    } on ErrorIA catch (e) {
      if (!e.sinConexion) rethrow;
      return SolicitudEnCola(await cola.encolar(s));
    }
  }

  Future<void> _procesarPendiente(SolicitudPendiente s) => _generar(s);

  /// Genera la nota y la guarda como borrador.
  Future<NotaClinica> _generar(SolicitudPendiente s) async {
    final String texto;
    final Map<String, Object?> referencia;
    switch (s.tipo) {
      case TipoNota.turno:
        final d = DatosTurno.fromMap(s.datos);
        texto = (await _turno.generar(d)).texto;
        referencia = {'signos': d.signos.toMap()};
      case TipoNota.fallecimiento:
        final paciente = Paciente.fromMap(_mapa(s.datos['paciente']));
        final datos = DatosFallecimiento.fromMap(
          _mapa(s.datos['fallecimiento']),
        );
        final procedimientos = [
          for (final x in s.datos['procedimientos'] as List? ?? const [])
            ProcedimientoInvasivo.fromMap(_mapa(x)),
        ];
        texto = (await _fallecimiento.generar(
          paciente,
          datos,
          procedimientos: procedimientos,
        )).texto;
        referencia = {
          'solicitud': construirSolicitudFallecimiento(
            paciente,
            datos,
            procedimientos: procedimientos,
          ),
        };
    }
    return repositorio.guardarNota(
      NotaClinica(
        pacienteId: s.pacienteId,
        tipo: s.tipo,
        texto: texto,
        creada: _ahora(),
        referencia: referencia,
      ),
    );
  }

  static Map<String, Object?> _mapa(Object? o) =>
      Map<String, Object?>.from(o! as Map);

  /// Revisión del texto de [nota] mientras se edita (TSK-17 / TSK-23).
  static RevisorNota revisor(NotaClinica nota) {
    switch (nota.tipo) {
      case TipoNota.turno:
        final signos = nota.referencia['signos'] == null
            ? const SignosVitales()
            : SignosVitales.fromMap(_mapa(nota.referencia['signos']));
        return (texto) {
          final r = revisarNota(texto, signos: signos);
          return (mensajes: r.mensajes, bloquea: r.bloqueaFirma);
        };
      case TipoNota.fallecimiento:
        final solicitud = nota.referencia['solicitud'] as String? ?? '';
        return (texto) {
          final r = revisarNota(texto, signos: const SignosVitales());
          final extra = const ValidadorNotaFallecimiento().problemas(
            texto,
            solicitud,
          );
          return (
            mensajes: [...extra, ...r.mensajes],
            bloquea: r.bloqueaFirma || extra.isNotEmpty,
          );
        };
    }
  }
}
