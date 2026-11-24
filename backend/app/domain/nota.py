"""Reglas de la nota clínica. Funciones puras, sin base de datos ni HTTP.

Ciclo de vida (Human-in-the-Loop, PDF §2.2.6):
    borrador -> revisada -> firmada (inmutable)
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum

from app.domain.errores import TransicionInvalida
from app.siglas.filtro import FiltroSiglas


class TipoNota(StrEnum):
    RECIBO = "recibo"
    EVOLUCION = "evolucion"
    TRASLADO = "traslado"
    PROCEDIMIENTO = "procedimiento"
    FALLECIMIENTO = "fallecimiento"


class EstadoNota(StrEnum):
    BORRADOR = "borrador"
    REVISADA = "revisada"
    FIRMADA = "firmada"


def validar_firma(texto: str, estado: EstadoNota, firmante: str, filtro: FiltroSiglas) -> list[str]:
    """Devuelve los motivos por los que la nota NO puede firmarse (lista vacía = puede).
    Reglas: estado revisada, texto no vacío, firmante presente y sin siglas
    prohibidas o desconocidas (Ley 911, art. 38)."""
    motivos: list[str] = []
    if not firmante.strip():
        motivos.append("Falta el firmante.")
    if estado != EstadoNota.REVISADA:
        motivos.append("La nota debe revisarse antes de firmar.")
    if not texto.strip():
        motivos.append("La nota está vacía.")
    motivos.extend(h.mensaje for h in filtro.analizar(texto))
    return motivos


@dataclass(frozen=True)
class Transicion:
    """Resultado de cambiar de estado; la capa de servicio lo persiste."""

    estado: EstadoNota
    texto_final: str | None = None


def revisar(estado: EstadoNota, texto_revisado: str) -> Transicion:
    if estado == EstadoNota.FIRMADA:
        raise TransicionInvalida("Una nota firmada no se modifica.")
    return Transicion(EstadoNota.REVISADA, texto_revisado)
