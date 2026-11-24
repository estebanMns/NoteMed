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
from app.servicios.sesiones import ServicioSesiones


def get_settings_dep(request: Request) -> Settings:
    return request.app.state.settings


def get_sesion(request: Request) -> Iterator[Session]:
    fabrica = request.app.state.fabrica_sesiones
    sesion = fabrica()
    try:
        yield sesion
    finally:
        sesion.close()


def _token_de(authorization: str | None) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise NoAutenticado("Falta el token de acceso.")
    return authorization.removeprefix("Bearer ").strip()


def get_actor(
    request: Request,
    sesion: Annotated[Session, Depends(get_sesion)],
    authorization: Annotated[str | None, Header()] = None,
) -> Actor:
    """Valida el JWT y la sesión: si hubo inactividad, la sesión se cierra y se rechaza."""
    settings = request.app.state.settings
    actor = leer_token(_token_de(authorization), settings)
    ServicioSesiones(sesion, settings, request.app.state.reloj).validar(actor)
    return actor


def get_actor_ia(
    request: Request,
    sesion: Annotated[Session, Depends(get_sesion)],
    authorization: Annotated[str | None, Header()] = None,
) -> Actor | None:
    """Token obligatorio salvo que la configuración lo desactive (solo desarrollo)."""
    if not request.app.state.settings.ia_requiere_token:
        return None
    return get_actor(request, sesion, authorization)


def get_servicio(
    request: Request,
    sesion: Annotated[Session, Depends(get_sesion)],
) -> ServicioNotas:
    generador = GeneradorBorrador(request.app.state.modelo)
    return ServicioNotas(sesion, generador)
