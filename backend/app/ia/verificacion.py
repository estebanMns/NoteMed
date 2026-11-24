"""Cadena de verificación determinista (PDF §2.2.5, Dhuliawala et al. 2023).

Contrasta el borrador con los datos de entrada ANTES de entregarlo a la
enfermera. Detecta alucinaciones concretas:
  * cifras que no aparecen en los datos (p. ej. una TA inventada);
  * códigos PAC/CAMA/ID que no existen en la entrada;
  * siglas prohibidas o desconocidas (filtro de la Ley 911).

Los hallazgos no bloquean el borrador, pero sí impiden firmar hasta que la
enfermera los corrija o los acepte (Human-in-the-Loop)."""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass

import regex

from app.siglas.filtro import FiltroSiglas, Hallazgo

_CODIGO = regex.compile(r"\b(?:PAC|CAMA|ID)-\d{3}\b")
_CIFRA = regex.compile(r"\d+")
_PUNTO_MILES = regex.compile(r"(?<=\d)\.(?=\d{3}\b)")


@dataclass(frozen=True)
class HallazgoDato:
    tipo: str  # "cifra_no_sustentada" | "codigo_desconocido"
    valor: str

    @property
    def mensaje(self) -> str:
        if self.tipo == "cifra_no_sustentada":
            return f'El valor "{self.valor}" no aparece en los datos registrados. Verifique.'
        return f'El código "{self.valor}" no corresponde a este paciente. Verifique.'


@dataclass(frozen=True)
class Verificacion:
    datos: list[HallazgoDato]
    siglas: list[Hallazgo]

    @property
    def limpio(self) -> bool:
        return not self.datos and not self.siglas

    def mensajes(self) -> list[str]:
        return [h.mensaje for h in self.datos] + [h.mensaje for h in self.siglas]


def _cifras(texto: str) -> list[str]:
    """Cifras de un texto. Los puntos de miles (1.023.456.789) se quitan para
    que un documento se compare como un solo número."""
    return _CIFRA.findall(_PUNTO_MILES.sub("", texto))


def verificar(
    borrador: str,
    entrada: str,
    filtro: FiltroSiglas | None = None,
    valores_identificadores: Iterable[str] = (),
) -> Verificacion:
    filtro = filtro or FiltroSiglas()
    codigos_entrada = set(_CODIGO.findall(entrada))
    cifras_entrada = set(_cifras(_CODIGO.sub(" ", entrada)))
    for valor in valores_identificadores:
        cifras_entrada.update(_cifras(valor))

    hallazgos: list[HallazgoDato] = []
    for codigo in dict.fromkeys(_CODIGO.findall(borrador)):
        if codigo not in codigos_entrada:
            hallazgos.append(HallazgoDato("codigo_desconocido", codigo))

    borrador_sin_codigos = _CODIGO.sub(" ", borrador)
    for cifra in dict.fromkeys(_cifras(borrador_sin_codigos)):
        if cifra not in cifras_entrada:
            hallazgos.append(HallazgoDato("cifra_no_sustentada", cifra))

    return Verificacion(datos=hallazgos, siglas=filtro.analizar(borrador))
