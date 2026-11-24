/// HU03 / HU04 / HU05 / HU07: casos de uso de las notas. Pide el borrador a
/// la IA, lo guarda en la base local (o deja la solicitud en la cola si no
/// hay red, TSK-28), firma la nota (Human-in-the-Loop) registrando la
/// métrica de edición y agrega notas aclaratorias a notas ya firmadas.
library;

import 'package:notemed/features/sincronizacion/application/cola_sincronizacion.dart';
import 'package:notemed/core/red/estado_red.dart';
import 'package:notemed/features/pacientes/domain/repositorio_pacientes.dart';
import 'package:notemed/features/sincronizacion/domain/solicitud_pendiente.dart';
import 'package:notemed/features/notas/domain/servicio_ia.dart';
import 'package:notemed/features/notas/application/generador_nota_fallecimiento.dart';
import 'package:notemed/features/pacientes/domain/paciente.dart';
import 'package:notemed/features/pacientes/domain/signos_vitales.dart';
import 'package:notemed/features/pacientes/domain/procedimiento_invasivo.dart';
import 'package:notemed/features/notas/application/generador_nota_turno.dart';
import 'package:notemed/features/notas/domain/nota_clinica.dart';
import 'package:notemed/features/notas/domain/revision_nota.dart';
import 'package:notemed/features/notas/domain/turno/datos_turno.dart';
import 'package:notemed/features/notas/domain/fallecimiento/datos_fallecimiento.dart';
import 'package:notemed/features/notas/domain/firma_enfermera.dart';
import 'package:notemed/features/notas/domain/prompts/prompt_evolucion.dart';
import 'package:notemed/features/notas/domain/prompts/prompt_traslado.dart';
import 'package:notemed/features/notas/domain/prompts/version_prompts.dart';
import 'package:notemed/features/notas/domain/traslado/datos_traslado.dart';
import 'package:notemed/features/metricas/domain/metrica_nota.dart';
import 'package:notemed/features/metricas/domain/repositorio_metricas.dart';
import 'package:notemed/features/validacion/domain/diccionario_medico.dart';

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
    required this.ia,
    required this.red,
    this.metricas,
    DateTime Function()? ahora,
  }) : _turno = GeneradorNotaTurno(ia),
       _fallecimiento = GeneradorNotaFallecimiento(ia),
       _ahora = ahora ?? DateTime.now {
    cola = ColaSincronizacion(
      repositorio: repositorio,
      red: red,
      procesar: _procesarPendiente,
      requiereRed: !ia.funcionaSinRed,
    );
  }

  final RepositorioPacientes repositorio;
  final ServicioIA ia;
  final EstadoRed red;

  /// Dónde se registran las métricas de validación. Opcional.
  final RepositorioMetricas? metricas;
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
      prom: await repositorio.prom(id),
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

  Future<ResultadoSolicitud> notaEvolucion(DatosTurno d) => _solicitar(
    SolicitudPendiente(
      pacienteId: d.paciente.id!,
      tipo: TipoNota.evolucion,
      datos: d.toMap(),
      creada: _ahora(),
    ),
  );

  Future<ResultadoSolicitud> notaTraslado(DatosTurno d, DatosTraslado t) =>
      _solicitar(
        SolicitudPendiente(
          pacienteId: d.paciente.id!,
          tipo: TipoNota.traslado,
          datos: {'turno': d.toMap(), 'traslado': t.toMap()},
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
    if (!ia.funcionaSinRed && !await red.conectado()) {
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
    const dicc = DiccionarioMedico.aprobado;
    final String texto;
    final Map<String, Object?> referencia;
    switch (s.tipo) {
      case TipoNota.turno:
        final d = DatosTurno.fromMap(s.datos);
        texto = (await _turno.generar(d)).texto;
        referencia = {'signos': d.signos.toMap()};
      case TipoNota.evolucion:
        final d = DatosTurno.fromMap(s.datos);
        texto = (await _turno.generar(
          d,
          sistema: instruccionesNotaEvolucion(dicc),
        )).texto;
        referencia = {'signos': d.signos.toMap()};
      case TipoNota.traslado:
        final d = DatosTurno.fromMap(_mapa(s.datos['turno']));
        final t = DatosTraslado.fromMap(_mapa(s.datos['traslado']));
        texto = (await _turno.generar(
          d,
          sistema: instruccionesNotaTraslado(dicc),
          solicitud: construirSolicitudTraslado(d, t),
        )).texto;
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
      case TipoNota.aclaracion:
        throw StateError('Las notas aclaratorias no las redacta la IA');
    }
    return repositorio.guardarNota(
      NotaClinica(
        pacienteId: s.pacienteId,
        tipo: s.tipo,
        texto: texto,
        creada: _ahora(),
        referencia: referencia,
        versionPrompts: versionPrompts,
      ),
    );
  }

  /// HU05 · Human-in-the-Loop: la enfermera firma el [borrador] con el
  /// [texto] que revisó. Registra la métrica de aceptación y edición.
  /// Lanza [NotaFirmadaInmutable] si la nota ya estaba firmada.
  Future<NotaClinica> firmar(
    NotaClinica borrador,
    String texto,
    FirmaEnfermera firma, {
    Duration? tiempoRevision,
  }) async {
    final firmada = await repositorio.guardarNota(
      borrador.firmar(texto, firma),
    );
    if (borrador.tipo.generadaPorIA) {
      await metricas?.registrar(
        MetricaNota.de(borrador, firmada, tiempoRevision: tiempoRevision),
      );
    }
    return firmada;
  }

  /// Agrega una nota aclaratoria firmada a [original], que debe estar
  /// firmada. La nota original no cambia.
  Future<NotaClinica> aclarar(
    NotaClinica original,
    String texto,
    FirmaEnfermera firma,
  ) {
    if (!original.firmada || original.id == null) {
      throw ArgumentError('Solo se aclaran notas firmadas');
    }
    return repositorio.guardarNota(
      NotaClinica(
        pacienteId: original.pacienteId,
        tipo: TipoNota.aclaracion,
        texto: texto,
        creada: _ahora(),
        aclaraA: original.id,
      ).firmar(texto, firma),
    );
  }

  static Map<String, Object?> _mapa(Object? o) =>
      Map<String, Object?>.from(o! as Map);

  /// Revisión del texto de [nota] mientras se edita (TSK-17 / TSK-23).
  static RevisorNota revisor(NotaClinica nota) {
    switch (nota.tipo) {
      case TipoNota.turno || TipoNota.evolucion || TipoNota.traslado:
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
      case TipoNota.aclaracion:
        return revisorAclaracion;
    }
  }

  /// Las aclaraciones las escribe la enfermera: solo se revisan las siglas.
  static ({List<String> mensajes, bool bloquea}) revisorAclaracion(
    String texto,
  ) => (
    mensajes: [
      for (final h in DiccionarioMedico.aprobado.filtro.analizar(texto))
        h.mensaje,
    ],
    bloquea: false,
  );
}
