"""Autenticación por JWT (HS256) con roles. El token identifica por código
de usuario (`sub`), nunca por nombre real."""

from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Literal

import jwt

from app.config import Settings
from app.domain.errores import NoAutenticado

Rol = Literal["enfermera", "jefe"]
_ROLES: frozenset[str] = frozenset({"enfermera", "jefe"})
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


# Parámetros de scrypt (OWASP: n >= 2**14, r = 8, p = 1).
_SCRYPT_N, _SCRYPT_R, _SCRYPT_P = 2**14, 8, 1


def hash_clave(clave: str) -> str:
    """Clave derivada con scrypt y sal aleatoria. Nunca se guarda la clave en claro."""
    sal = secrets.token_bytes(16)
    derivada = hashlib.scrypt(
        clave.encode("utf-8"), salt=sal, n=_SCRYPT_N, r=_SCRYPT_R, p=_SCRYPT_P, dklen=32
    )
    sal_b64 = base64.b64encode(sal).decode("ascii")
    hash_b64 = base64.b64encode(derivada).decode("ascii")
    return f"scrypt${_SCRYPT_N}${_SCRYPT_R}${_SCRYPT_P}${sal_b64}${hash_b64}"


def verificar_clave(clave: str, almacenada: str) -> bool:
    try:
        _, n, r, p, sal_b64, hash_b64 = almacenada.split("$")
        esperado = base64.b64decode(hash_b64)
        derivada = hashlib.scrypt(
            clave.encode("utf-8"),
            salt=base64.b64decode(sal_b64),
            n=int(n),
            r=int(r),
            p=int(p),
            dklen=len(esperado),
        )
    except (ValueError, TypeError):
        return False
    return hmac.compare_digest(derivada, esperado)
