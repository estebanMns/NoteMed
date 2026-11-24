"""Modelo relacional (PDF §3.5: BD relacional con integridad referencial y
propiedades ACID). Los identificadores son UUID generados por el cliente, lo
que permite sincronizar notas creadas sin conexión sin duplicarlas."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

from app.domain.nota import EstadoNota, TipoNota


class Base(DeclarativeBase):
    pass


class PacienteORM(Base):
    __tablename__ = "pacientes"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    # Solo el seudónimo (PAC-###). El nombre real vive en el sistema del hospital.
    pseudonimo: Mapped[str] = mapped_column(String(32), unique=True)
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    notas: Mapped[list[NotaORM]] = relationship(back_populates="paciente")


class NotaORM(Base):
    __tablename__ = "notas"
    __table_args__ = (
        CheckConstraint(
            "estado IN ('" + "','".join(e.value for e in EstadoNota) + "')",
            name="ck_notas_estado",
        ),
        CheckConstraint(
            "tipo IN ('" + "','".join(t.value for t in TipoNota) + "')",
            name="ck_notas_tipo",
        ),
        CheckConstraint("version >= 1", name="ck_notas_version"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    paciente_id: Mapped[str] = mapped_column(ForeignKey("pacientes.id", ondelete="RESTRICT"), index=True)
    tipo: Mapped[str] = mapped_column(String(20))
    estado: Mapped[str] = mapped_column(String(12))
    version: Mapped[int] = mapped_column(Integer, default=1)

    texto_borrador: Mapped[str] = mapped_column(Text)
    texto_final: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Datos seudonimizados de entrada: permiten re-verificar la nota al revisarla.
    entrada_anonima: Mapped[str] = mapped_column(Text)
    hallazgos_json: Mapped[str] = mapped_column(Text, default="[]")
    prompt_version: Mapped[str] = mapped_column(String(32))

    creada_por: Mapped[str] = mapped_column(String(64))
    creada_en: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revisada_en: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    firmada_por: Mapped[str | None] = mapped_column(String(64), nullable=True)
    firmada_en: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    paciente: Mapped[PacienteORM] = relationship(back_populates="notas")


class EventoAuditoriaORM(Base):
    """Bitácora de solo inserción: el repositorio nunca actualiza ni borra filas."""

    __tablename__ = "eventos_auditoria"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    nota_id: Mapped[str] = mapped_column(ForeignKey("notas.id", ondelete="RESTRICT"), index=True)
    accion: Mapped[str] = mapped_column(String(32))
    actor: Mapped[str] = mapped_column(String(64))
    ocurrido_en: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    detalle_json: Mapped[str] = mapped_column(Text, default="{}")

    # La relación ORM hace que el unit of work inserte primero la nota.
    nota: Mapped[NotaORM] = relationship()
