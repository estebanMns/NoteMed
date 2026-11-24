"""Casos de uso de notas y pacientes. Coordinan dominio, IA y persistencia.

Reglas de autorización:
  * crear, revisar y firmar: solo el enfermero autor de la nota;
  * consultar: el autor o un supervisor (solo lectura de métricas y notas).

Control de concurrencia: cada cambio exige la `version` leída por el cliente
y se aplica con UPDATE condicional (atómico en PostgreSQL), así dos
dispositivos no pisan cambios.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from datetime import UTC, datetime
from difflib import SequenceMatcher
from typing import Any, cast
from uuid import uuid4

from sqlalchemy import func, select, update
from sqlalchemy.engine import CursorResult
from sqlalchemy.orm import Session

from app.db.modelos import EventoAuditoriaORM, NotaORM, PacienteORM
from app.domain.errores import (
    ConflictoVersion,
    NoAutorizado,
    NotaNoEncontrada,
    NotaNoFirmable,
    PacienteExistente,
    PacienteNoEncontrado,
    TransicionInvalida,
)
from app.domain.nota import EstadoNota, TipoNota, revisar, validar_firma
from app.ia.orquestador import GeneradorBorrador
from app.ia.verificacion import verificar
from app.seguridad import Actor
from app.siglas.filtro import FiltroSiglas

_PSEUDONIMO = re.compile(r"^PAC-\d{3,}$")


def _ahora() -> datetime:
    return datetime.now(UTC)


@dataclass(frozen=True)
class MetricasBorradores:
    notas_totales: int
    notas_firmadas: int
    aceptadas_sin_edicion: int
    edicion_promedio_pct: float


@dataclass(frozen=True)
class ResultadoCreacion:
    nota: NotaORM
    creada: bool


class ServicioNotas:
    def __init__(
        self, sesion: Session, generador: GeneradorBorrador, filtro: FiltroSiglas | None = None
    ) -> None:
        self._s = sesion
        self._generador = generador
        self._filtro = filtro or FiltroSiglas()

    # ---------- pacientes ----------

    def crear_paciente(self, actor: Actor, pseudonimo: str) -> PacienteORM:
        self._exigir_enfermero(actor)
        if not _PSEUDONIMO.match(pseudonimo):
            raise ValueError("El pseudónimo debe tener la forma PAC-001.")
        if self._s.scalar(select(PacienteORM).where(PacienteORM.pseudonimo == pseudonimo)):
            raise PacienteExistente(f"Ya existe el paciente {pseudonimo}.")
        paciente = PacienteORM(id=str(uuid4()), pseudonimo=pseudonimo, creado_en=_ahora())
        self._s.add(paciente)
        self._s.commit()
        return paciente

    def obtener_paciente(self, paciente_id: str) -> PacienteORM:
        paciente = self._s.get(PacienteORM, paciente_id)
        if paciente is None:
            raise PacienteNoEncontrado("Paciente no encontrado.")
        return paciente

    def notas_del_paciente(self, actor: Actor, paciente_id: str) -> list[NotaORM]:
        self.obtener_paciente(paciente_id)
        consulta = select(NotaORM).where(NotaORM.paciente_id == paciente_id).order_by(NotaORM.creada_en)
        if actor.rol != "supervisor":
            consulta = consulta.where(NotaORM.creada_por == actor.sub)
        return list(self._s.scalars(consulta))

    # ---------- notas ----------

    def crear_borrador(
        self,
        actor: Actor,
        *,
        nota_id: str,
        paciente_id: str,
        tipo: TipoNota,
        datos: str,
        nombres_conocidos: list[str],
    ) -> ResultadoCreacion:
        self._exigir_enfermero(actor)
        existente = self._s.get(NotaORM, nota_id)
        if existente is not None:
            # Idempotencia para sincronización offline: reenviar la misma nota no la duplica.
            self._exigir_autor(actor, existente)
            return ResultadoCreacion(existente, creada=False)

        paciente = self.obtener_paciente(paciente_id)
        borrador = self._generador.ejecutar(tipo, datos, nombres_conocidos)

        nota = NotaORM(
            id=nota_id,
            paciente_id=paciente.id,
            tipo=tipo.value,
            estado=EstadoNota.BORRADOR.value,
            version=1,
            texto_borrador=borrador.texto,
            texto_final=None,
            entrada_anonima=borrador.entrada_anonima,
            hallazgos_json=json.dumps(borrador.verificacion.mensajes(), ensure_ascii=False),
            prompt_version=borrador.prompt_version,
            creada_por=actor.sub,
            creada_en=_ahora(),
        )
        self._s.add(nota)
        self._auditar(nota.id, "borrador_creado", actor, {"prompt_version": nota.prompt_version})
        self._s.commit()
        return ResultadoCreacion(nota, creada=True)

    def obtener(self, actor: Actor, nota_id: str) -> NotaORM:
        nota = self._s.get(NotaORM, nota_id)
        if nota is None:
            raise NotaNoEncontrada("Nota no encontrada.")
        if actor.rol != "supervisor":
            self._exigir_autor(actor, nota)
        return nota

    def revisar(self, actor: Actor, nota_id: str, version: int, texto: str) -> NotaORM:
        self._exigir_enfermero(actor)
        nota = self.obtener(actor, nota_id)
        self._exigir_version(nota, version)
        estado_actual = EstadoNota(nota.estado)
        transicion = revisar(estado_actual, texto)

        verificacion = verificar(texto, nota.entrada_anonima, self._filtro)
        self._actualizar_condicional(
            nota,
            version,
            {
                "estado": transicion.estado.value,
                "texto_final": transicion.texto_final,
                "hallazgos_json": json.dumps(verificacion.mensajes(), ensure_ascii=False),
                "revisada_en": _ahora(),
                "version": version + 1,
            },
        )
        self._auditar(nota.id, "nota_revisada", actor, {"hallazgos": len(verificacion.mensajes())})
        self._s.commit()
        return nota

    def firmar(self, actor: Actor, nota_id: str, version: int) -> NotaORM:
        self._exigir_enfermero(actor)
        nota = self.obtener(actor, nota_id)
        self._exigir_version(nota, version)
        if EstadoNota(nota.estado) is EstadoNota.FIRMADA:
            raise TransicionInvalida("La nota ya está firmada.")

        texto = nota.texto_final or nota.texto_borrador
        motivos = validar_firma(texto, EstadoNota(nota.estado), actor.sub, self._filtro)
        # Valores que no aparecen en los datos registrados también bloquean la firma.
        motivos.extend(v.mensaje for v in verificar(texto, nota.entrada_anonima, self._filtro).datos)
        if motivos:
            raise NotaNoFirmable(motivos)

        self._actualizar_condicional(
            nota,
            version,
            {
                "estado": EstadoNota.FIRMADA.value,
                "firmada_por": actor.sub,
                "firmada_en": _ahora(),
                "version": version + 1,
            },
        )
        self._auditar(nota.id, "nota_firmada", actor, {})
        self._s.commit()
        return nota

    # ---------- métricas (PDF §2.3.4: aceptación y edición) ----------

    def metricas_borradores(self, actor: Actor) -> MetricasBorradores:
        if actor.rol != "supervisor":
            raise NoAutorizado("Solo un supervisor consulta las métricas.")
        firmadas = list(self._s.scalars(select(NotaORM).where(NotaORM.estado == EstadoNota.FIRMADA.value)))
        total = self._s.scalar(select(func.count()).select_from(NotaORM))
        sin_edicion = sum(1 for n in firmadas if n.texto_final == n.texto_borrador)
        if firmadas:
            edicion = sum(
                (1 - SequenceMatcher(None, n.texto_borrador, n.texto_final or "").ratio()) * 100
                for n in firmadas
            ) / len(firmadas)
        else:
            edicion = 0.0
        return MetricasBorradores(
            notas_totales=int(total or 0),
            notas_firmadas=len(firmadas),
            aceptadas_sin_edicion=sin_edicion,
            edicion_promedio_pct=round(edicion, 1),
        )

    # ---------- internos ----------

    @staticmethod
    def _exigir_enfermero(actor: Actor) -> None:
        if actor.rol != "enfermero":
            raise NoAutorizado("Solo el personal de enfermería puede realizar esta acción.")

    @staticmethod
    def _exigir_autor(actor: Actor, nota: NotaORM) -> None:
        if nota.creada_por != actor.sub and actor.rol != "supervisor":
            raise NoAutorizado("La nota pertenece a otro profesional.")

    @staticmethod
    def _exigir_version(nota: NotaORM, version: int) -> None:
        if nota.version != version:
            raise ConflictoVersion(
                f"La nota cambió (versión actual {nota.version}). Recargue antes de guardar."
            )

    def _actualizar_condicional(self, nota: NotaORM, version_esperada: int, valores: dict) -> None:
        resultado = cast(
            CursorResult[Any],
            self._s.execute(
                update(NotaORM)
                .where(NotaORM.id == nota.id, NotaORM.version == version_esperada)
                .values(**valores)
                .execution_options(synchronize_session=False)
            ),
        )
        if resultado.rowcount != 1:
            self._s.rollback()
            raise ConflictoVersion("La nota fue modificada por otra sesión. Recargue antes de guardar.")
        self._s.refresh(nota)

    def _auditar(self, nota_id: str, accion: str, actor: Actor, detalle: dict) -> None:
        self._s.add(
            EventoAuditoriaORM(
                nota_id=nota_id,
                accion=accion,
                actor=actor.sub,
                ocurrido_en=_ahora(),
                detalle_json=json.dumps(detalle, ensure_ascii=False),
            )
        )
