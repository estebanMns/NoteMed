"""Endpoints REST v1. La lógica vive en `ServicioNotas`; aquí solo HTTP."""

from __future__ import annotations

import json
from typing import Annotated

from fastapi import APIRouter, Depends, Response, status
from fastapi.responses import JSONResponse

from app.api.dependencias import get_actor, get_servicio
from app.api.esquemas import (
    BorradorEntrada,
    FirmaEntrada,
    MetricasSalida,
    NotaSalida,
    PacienteEntrada,
    PacienteSalida,
    RevisionEntrada,
)
from app.db.modelos import NotaORM
from app.domain.nota import TipoNota
from app.fhir import documento_fhir
from app.seguridad import Actor
from app.servicios.notas import ServicioNotas

router = APIRouter(prefix="/v1")
Servicio = Annotated[ServicioNotas, Depends(get_servicio)]
ActorDep = Annotated[Actor, Depends(get_actor)]


def _nota_salida(nota: NotaORM) -> NotaSalida:
    return NotaSalida(
        id=nota.id,
        paciente_id=nota.paciente_id,
        tipo=TipoNota(nota.tipo),
        estado=nota.estado,  # type: ignore[arg-type]
        version=nota.version,
        texto=nota.texto_final or nota.texto_borrador,
        texto_borrador=nota.texto_borrador,
        hallazgos=json.loads(nota.hallazgos_json),
        prompt_version=nota.prompt_version,
        creada_por=nota.creada_por,
        creada_en=nota.creada_en,
        firmada_por=nota.firmada_por,
        firmada_en=nota.firmada_en,
    )


@router.post("/pacientes", response_model=PacienteSalida, status_code=status.HTTP_201_CREATED)
def crear_paciente(entrada: PacienteEntrada, actor: ActorDep, servicio: Servicio) -> PacienteSalida:
    paciente = servicio.crear_paciente(actor, entrada.pseudonimo)
    return PacienteSalida(id=paciente.id, pseudonimo=paciente.pseudonimo)


@router.get("/pacientes/{paciente_id}/notas", response_model=list[NotaSalida])
def notas_del_paciente(paciente_id: str, actor: ActorDep, servicio: Servicio) -> list[NotaSalida]:
    return [_nota_salida(n) for n in servicio.notas_del_paciente(actor, paciente_id)]


@router.post("/notas/borradores", response_model=NotaSalida)
def crear_borrador(
    entrada: BorradorEntrada,
    response: Response,
    actor: ActorDep,
    servicio: Servicio,
) -> NotaSalida:
    resultado = servicio.crear_borrador(
        actor,
        nota_id=str(entrada.id),
        paciente_id=entrada.paciente_id,
        tipo=entrada.tipo,
        datos=entrada.datos,
        nombres_conocidos=entrada.nombres_conocidos,
    )
    response.status_code = status.HTTP_201_CREATED if resultado.creada else status.HTTP_200_OK
    return _nota_salida(resultado.nota)


@router.get("/notas/{nota_id}", response_model=NotaSalida)
def obtener_nota(nota_id: str, actor: ActorDep, servicio: Servicio) -> NotaSalida:
    return _nota_salida(servicio.obtener(actor, nota_id))


@router.put("/notas/{nota_id}/revision", response_model=NotaSalida)
def revisar_nota(nota_id: str, entrada: RevisionEntrada, actor: ActorDep, servicio: Servicio) -> NotaSalida:
    return _nota_salida(servicio.revisar(actor, nota_id, entrada.version, entrada.texto))


@router.post("/notas/{nota_id}/firma", response_model=NotaSalida)
def firmar_nota(nota_id: str, entrada: FirmaEntrada, actor: ActorDep, servicio: Servicio) -> NotaSalida:
    return _nota_salida(servicio.firmar(actor, nota_id, entrada.version))


@router.get("/notas/{nota_id}/fhir")
def nota_como_fhir(nota_id: str, actor: ActorDep, servicio: Servicio) -> JSONResponse:
    recurso = documento_fhir(servicio.obtener(actor, nota_id))
    return JSONResponse(recurso, media_type="application/fhir+json")


@router.get("/metricas/borradores", response_model=MetricasSalida)
def metricas(actor: ActorDep, servicio: Servicio) -> MetricasSalida:
    m = servicio.metricas_borradores(actor)
    return MetricasSalida(
        notas_totales=m.notas_totales,
        notas_firmadas=m.notas_firmadas,
        aceptadas_sin_edicion=m.aceptadas_sin_edicion,
        edicion_promedio_pct=m.edicion_promedio_pct,
    )
