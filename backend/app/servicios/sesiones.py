"""Sesiones: apertura, validación por inactividad, cierre y revocación.

Regla de seguridad: si una sesión no tiene actividad durante
`sesion_inactividad_minutos` (2 por defecto), se revoca y la siguiente petición
recibe 401. Cada petición válida renueva la actividad."""

from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from uuid import uuid4

from sqlalchemy import update
from sqlalchemy.orm import Session

from app.config import Settings
from app.db.modelos import SesionORM, UsuarioORM
from app.domain.errores import SesionInvalida
from app.seguridad import Actor

Reloj = Callable[[], datetime]


def ahora_utc() -> datetime:
    return datetime.now(UTC)


def _utc(momento: datetime) -> datetime:
    """SQLite devuelve fechas sin zona horaria; se tratan como UTC."""
    return momento if momento.tzinfo is not None else momento.replace(tzinfo=UTC)


class ServicioSesiones:
    def __init__(self, sesion: Session, settings: Settings, reloj: Reloj = ahora_utc) -> None:
        self._s = sesion
        self._settings = settings
        self._reloj = reloj

    def abrir(self, usuario: UsuarioORM) -> tuple[str, datetime]:
        """Crea la sesión y devuelve su identificador (jti) y la fecha de vencimiento máxima."""
        ahora = self._reloj()
        jti = str(uuid4())
        expira = ahora + timedelta(hours=self._settings.jwt_horas_expiracion)
        self._s.add(
            SesionORM(
                id=jti,
                usuario_id=usuario.id,
                creada_en=ahora,
                ultima_actividad=ahora,
                expira=expira,
                revocada=False,
            )
        )
        self._s.commit()
        return jti, expira

    def validar(self, actor: Actor) -> None:
        """Comprueba la sesión de una petición y renueva su actividad."""
        if not actor.jti:
            raise SesionInvalida("Sesión sin identificador. Inicie sesión de nuevo.", "sesion_invalida")
        sesion = self._s.get(SesionORM, actor.jti)
        if sesion is None or sesion.revocada:
            raise SesionInvalida("La sesión fue cerrada. Inicie sesión de nuevo.", "sesion_cerrada")

        ahora = self._reloj()
        if ahora >= _utc(sesion.expira):
            raise SesionInvalida("La sesión venció. Inicie sesión de nuevo.", "sesion_vencida")

        limite = timedelta(minutes=self._settings.sesion_inactividad_minutos)
        if ahora - _utc(sesion.ultima_actividad) > limite:
            self._revocar([sesion.id])
            raise SesionInvalida(
                "La sesión se cerró por inactividad. Inicie sesión de nuevo.", "sesion_inactiva"
            )

        usuario = self._s.get(UsuarioORM, sesion.usuario_id)
        if usuario is None or not usuario.activo or usuario.usuario != actor.sub:
            raise SesionInvalida("El usuario ya no está activo.", "usuario_inactivo")

        sesion.ultima_actividad = ahora
        self._s.commit()

    def cerrar(self, jti: str) -> None:
        self._revocar([jti])

    def revocar_de_usuario(self, usuario_id: str) -> None:
        self._s.execute(update(SesionORM).where(SesionORM.usuario_id == usuario_id).values(revocada=True))
        self._s.commit()

    def _revocar(self, ids: list[str]) -> None:
        self._s.execute(update(SesionORM).where(SesionORM.id.in_(ids)).values(revocada=True))
        self._s.commit()
