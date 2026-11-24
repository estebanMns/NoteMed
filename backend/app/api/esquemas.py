"""Contratos de la API. `extra="forbid"` rechaza campos desconocidos."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

from app.domain.nota import EstadoNota, TipoNota

Pseudonimo = Annotated[str, StringConstraints(pattern=r"^PAC-\d{3,}$")]
Texto = Annotated[str, StringConstraints(max_length=20000)]


class _Entrada(BaseModel):
    model_config = ConfigDict(extra="forbid")


class PacienteEntrada(_Entrada):
    pseudonimo: Pseudonimo


class PacienteSalida(BaseModel):
    id: str
    pseudonimo: str


class BorradorEntrada(_Entrada):
    # UUID creado por el cliente: permite reenviar sin duplicar (sincronización offline).
    id: UUID
    paciente_id: str = Field(min_length=1, max_length=36)
    tipo: TipoNota
    datos: Annotated[str, StringConstraints(min_length=1, max_length=8000)]
    # Nombres solo para seudonimizar; el servidor no los guarda.
    nombres_conocidos: list[Annotated[str, StringConstraints(max_length=120)]] = Field(
        default_factory=list, max_length=10
    )


class RevisionEntrada(_Entrada):
    version: int = Field(ge=1)
    texto: Texto


class FirmaEntrada(_Entrada):
    version: int = Field(ge=1)


class NotaSalida(BaseModel):
    id: str
    paciente_id: str
    tipo: TipoNota
    estado: EstadoNota
    version: int
    texto: str
    texto_borrador: str
    hallazgos: list[str]
    prompt_version: str
    creada_por: str
    creada_en: datetime
    firmada_por: str | None
    firmada_en: datetime | None


class MetricasSalida(BaseModel):
    notas_totales: int
    notas_firmadas: int
    aceptadas_sin_edicion: int
    edicion_promedio_pct: float
