"""Motor y sesiones. En SQLite se activan las claves foráneas (por defecto están desactivadas)."""

from __future__ import annotations

from collections.abc import Iterator

from sqlalchemy import create_engine, event
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.modelos import Base


def crear_motor(url: str) -> Engine:
    es_sqlite = url.startswith("sqlite")
    kwargs: dict[str, object] = {}
    if es_sqlite:
        kwargs["connect_args"] = {"check_same_thread": False}
        if ":memory:" in url:
            kwargs["poolclass"] = StaticPool
    motor = create_engine(url, **kwargs)

    if es_sqlite:

        @event.listens_for(motor, "connect")
        def _activar_fk(conexion, _registro):
            cursor = conexion.cursor()
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.close()

    return motor


def crear_tablas(motor: Engine) -> None:
    """Solo para desarrollo y pruebas. En producción el esquema lo gestiona Alembic."""
    Base.metadata.create_all(motor)


def fabrica_sesiones(motor: Engine) -> sessionmaker[Session]:
    return sessionmaker(bind=motor, expire_on_commit=False, autoflush=False)


def sesion_desde(fabrica: sessionmaker[Session]) -> Iterator[Session]:
    sesion = fabrica()
    try:
        yield sesion
    finally:
        sesion.close()
