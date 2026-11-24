from __future__ import annotations

from collections.abc import Iterator
from typing import Annotated

from fastapi import Depends, Header, Request
from sqlalchemy.orm import Session

from app.config import Settings
from app.domain.errores import NoAutenticado
from app.ia.orquestador import GeneradorBorrador
from app.seguridad import Actor, leer_token
from app.servicios.notas import ServicioNotas


def get_settings_dep(request: Request) -> Settings:
    return request.app.state.settings


def get_sesion(request: Request) -> Iterator[Session]:
    fabrica = request.app.state.fabrica_sesiones
    sesion = fabrica()
    try:
        yield sesion
    finally:
        sesion.close()


def get_actor(
    settings: Annotated[Settings, Depends(get_settings_dep)],
    authorization: Annotated[str | None, Header()] = None,
) -> Actor:
    if not authorization or not authorization.startswith("Bearer "):
        raise NoAutenticado("Falta el token de acceso.")
    return leer_token(authorization.removeprefix("Bearer ").strip(), settings)


def get_servicio(
    request: Request,
    sesion: Annotated[Session, Depends(get_sesion)],
) -> ServicioNotas:
    generador = GeneradorBorrador(request.app.state.modelo)
    return ServicioNotas(sesion, generador)
