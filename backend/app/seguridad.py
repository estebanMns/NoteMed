"""Autenticación por JWT (HS256) con roles. El token identifica por código
de usuario (`sub`), nunca por nombre real."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Literal

import jwt

from app.config import Settings
from app.domain.errores import NoAutenticado

Rol = Literal["enfermero", "supervisor"]
_ROLES: frozenset[str] = frozenset({"enfermero", "supervisor"})
_ALGORITMO = "HS256"


@dataclass(frozen=True)
class Actor:
    sub: str
    rol: Rol


def crear_token(sub: str, rol: Rol, settings: Settings, ahora: datetime | None = None) -> str:
    if rol not in _ROLES:
        raise ValueError(f"Rol desconocido: {rol}")
    emitido = ahora or datetime.now(UTC)
    payload = {
        "sub": sub,
        "rol": rol,
        "iat": emitido,
        "exp": emitido + timedelta(hours=settings.jwt_horas_expiracion),
    }
    return jwt.encode(payload, settings.jwt_secret.get_secret_value(), algorithm=_ALGORITMO)


def leer_token(token: str, settings: Settings) -> Actor:
    try:
        datos = jwt.decode(token, settings.jwt_secret.get_secret_value(), algorithms=[_ALGORITMO])
    except jwt.PyJWTError as error:
        raise NoAutenticado("Token inválido o vencido.") from error
    rol = datos.get("rol")
    sub = datos.get("sub")
    if not isinstance(sub, str) or not sub or rol not in _ROLES:
        raise NoAutenticado("Token sin identidad o rol válidos.")
    return Actor(sub=sub, rol=rol)
