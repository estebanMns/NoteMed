"""Autenticación: contraseñas con scrypt y sesiones con JWT (HS256).

Roles: `enfermera` (registra y firma sus notas) y `jefe` (administra el personal
y consulta métricas). El token identifica por código de usuario (`sub`), nunca
por nombre real. El claim `jti` apunta a la sesión guardada en la base de datos,
que es la que controla la inactividad."""

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
ROLES: frozenset[str] = frozenset({"enfermera", "jefe"})
_ALGORITMO = "HS256"

# Parámetros de scrypt (OWASP: n >= 2**14, r = 8, p = 1).
_SCRYPT_N, _SCRYPT_R, _SCRYPT_P = 2**14, 8, 1


@dataclass(frozen=True)
class Actor:
    sub: str
    rol: str
    jti: str | None = None


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


def crear_token(
    sub: str,
    rol: Rol,
    settings: Settings,
    ahora: datetime | None = None,
    jti: str | None = None,
) -> str:
    if rol not in ROLES:
        raise ValueError(f"Rol desconocido: {rol}")
    emitido = ahora or datetime.now(UTC)
    payload: dict[str, object] = {
        "sub": sub,
        "rol": rol,
        "iat": emitido,
        "exp": emitido + timedelta(hours=settings.jwt_horas_expiracion),
    }
    if jti is not None:
        payload["jti"] = jti
    return jwt.encode(payload, settings.jwt_secret.get_secret_value(), algorithm=_ALGORITMO)


def leer_token(token: str, settings: Settings) -> Actor:
    try:
        datos = jwt.decode(token, settings.jwt_secret.get_secret_value(), algorithms=[_ALGORITMO])
    except jwt.PyJWTError as error:
        raise NoAutenticado("Sesión inválida o vencida. Inicie sesión de nuevo.") from error
    sub = datos.get("sub")
    rol = datos.get("rol")
    jti = datos.get("jti")
    if not isinstance(sub, str) or not sub or rol not in ROLES:
        raise NoAutenticado("Sesión sin identidad o rol válidos.")
    return Actor(sub=sub, rol=str(rol), jti=jti if isinstance(jti, str) else None)
