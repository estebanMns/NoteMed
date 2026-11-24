"""Administración del personal de enfermería. Solo la jefa o el jefe puede
usarlo, y solo gestiona cuentas de enfermera (no otras cuentas de jefe).

Borrar = dar de baja: la cuenta queda inactiva y sus sesiones se revocan.
No se borra la fila porque las notas firmadas guardan quién las creó y la
historia clínica debe seguir siendo atribuible (Resolución 1995 de 1999)."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import Settings
from app.db.modelos import UsuarioORM
from app.domain.errores import NoAutorizado, UsuarioNoEncontrado
from app.seguridad import Actor, hash_clave
from app.servicios.autenticacion import ServicioAutenticacion
from app.servicios.sesiones import Reloj, ServicioSesiones, ahora_utc


class ServicioUsuarios:
    def __init__(self, sesion: Session, settings: Settings, reloj: Reloj = ahora_utc) -> None:
        self._s = sesion
        self._settings = settings
        self._reloj = reloj

    @staticmethod
    def _exigir_jefe(actor: Actor) -> None:
        if actor.rol != "jefe":
            raise NoAutorizado("Solo la jefa o el jefe de enfermería administra el personal.")

    def _enfermera(self, usuario: str) -> UsuarioORM:
        registro = self._s.scalar(
            select(UsuarioORM).where(UsuarioORM.usuario == usuario, UsuarioORM.rol == "enfermera")
        )
        if registro is None:
            raise UsuarioNoEncontrado("No existe ese usuario de enfermería.")
        return registro

    def listar(self, actor: Actor, incluir_inactivos: bool = False) -> list[UsuarioORM]:
        self._exigir_jefe(actor)
        consulta = select(UsuarioORM).where(UsuarioORM.rol == "enfermera").order_by(UsuarioORM.usuario)
        if not incluir_inactivos:
            consulta = consulta.where(UsuarioORM.activo.is_(True))
        return list(self._s.scalars(consulta))

    def crear(self, actor: Actor, usuario: str, clave: str, tarjeta_profesional: str) -> UsuarioORM:
        self._exigir_jefe(actor)
        return ServicioAutenticacion(self._s, self._settings, self._reloj).crear_usuario(
            usuario, clave, tarjeta_profesional, "enfermera"
        )

    def editar(
        self,
        actor: Actor,
        usuario: str,
        tarjeta_profesional: str | None = None,
        clave: str | None = None,
    ) -> UsuarioORM:
        self._exigir_jefe(actor)
        registro = self._enfermera(usuario)
        if tarjeta_profesional is not None:
            registro.tarjeta_profesional = tarjeta_profesional
        if clave is not None:
            registro.clave_hash = hash_clave(clave)
            # Al cambiar la clave se cierran las sesiones abiertas con la anterior.
            ServicioSesiones(self._s, self._settings, self._reloj).revocar_de_usuario(registro.id)
        self._s.commit()
        return registro

    def dar_de_baja(self, actor: Actor, usuario: str) -> None:
        self._exigir_jefe(actor)
        if usuario == actor.sub:
            raise NoAutorizado("No puede dar de baja su propia cuenta.")
        registro = self._enfermera(usuario)
        registro.activo = False
        self._s.commit()
        ServicioSesiones(self._s, self._settings, self._reloj).revocar_de_usuario(registro.id)
