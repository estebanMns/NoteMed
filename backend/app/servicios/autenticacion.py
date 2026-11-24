"""Inicio de sesión (contrato sección 2): usuario y clave -> JWT.

Los usuarios los da de alta una persona administradora (scripts/crear_usuario.py
o la pantalla del jefe). No hay registro público."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import Settings
from app.db.modelos import UsuarioORM
from app.domain.errores import CredencialesInvalidas, UsuarioExistente
from app.seguridad import Rol, crear_token, hash_clave, verificar_clave
from app.servicios.sesiones import Reloj, ServicioSesiones, ahora_utc

ROLES_VALIDOS = ("enfermera", "jefe")

# Hash ficticio para gastar el mismo tiempo cuando el usuario no existe
# (así no se puede saber qué usuarios existen midiendo la respuesta).
_HASH_FICTICIO = hash_clave("clave-ficticia-para-igualar-tiempos")


@dataclass(frozen=True)
class Sesion:
    token: str
    expira: datetime
    usuario: str
    tarjeta_profesional: str
    rol: str


class ServicioAutenticacion:
    def __init__(self, sesion: Session, settings: Settings, reloj: Reloj = ahora_utc) -> None:
        self._s = sesion
        self._settings = settings
        self._reloj = reloj

    def crear_usuario(self, usuario: str, clave: str, tarjeta_profesional: str, rol: str) -> UsuarioORM:
        if rol not in ROLES_VALIDOS:
            raise ValueError(f"Rol desconocido: {rol}")
        if self._s.scalar(select(UsuarioORM).where(UsuarioORM.usuario == usuario)):
            raise UsuarioExistente("Ya existe ese usuario.")
        registro = UsuarioORM(
            id=str(uuid4()),
            usuario=usuario,
            clave_hash=hash_clave(clave),
            tarjeta_profesional=tarjeta_profesional,
            rol=rol,
            activo=True,
        )
        self._s.add(registro)
        self._s.commit()
        return registro

    def iniciar_sesion(self, usuario: str, clave: str) -> Sesion:
        registro = self._s.scalar(select(UsuarioORM).where(UsuarioORM.usuario == usuario))
        hash_a_comparar = registro.clave_hash if registro else _HASH_FICTICIO
        clave_ok = verificar_clave(clave, hash_a_comparar)
        if registro is None or not clave_ok or not registro.activo:
            raise CredencialesInvalidas("Usuario o clave incorrectos.")
        if registro.rol not in ROLES_VALIDOS:
            raise CredencialesInvalidas("Usuario sin rol válido.")

        jti, expira = ServicioSesiones(self._s, self._settings, self._reloj).abrir(registro)
        rol: Rol = "jefe" if registro.rol == "jefe" else "enfermera"
        token = crear_token(registro.usuario, rol, self._settings, self._reloj(), jti)
        return Sesion(token, expira, registro.usuario, registro.tarjeta_profesional, rol)
