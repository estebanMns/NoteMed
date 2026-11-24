"""Seudonimización de datos del paciente antes de enviarlos al modelo de
lenguaje (Ley 1581 de 2012; PDF §3.5). Espejo de
lib/core/privacidad/anonimizador.dart.

  nombres           -> PAC-###
  documentos (6-10 dígitos) -> ID-###
  cama / habitación -> CAMA-###

Dentro de una instancia el mapeo es determinista. La tabla de
reidentificación vive solo en memoria y nunca se persiste ni se envía.
"""

from __future__ import annotations

import unicodedata
from collections.abc import Iterable
from types import MappingProxyType

import regex

_LETRA = r"[\p{L}\p{N}]"

_DOCUMENTO = regex.compile(r"(?<!" + _LETRA + r")(?:\d{1,3}(?:\.\d{3}){2,3}|\d{6,10})(?!" + _LETRA + r")")

_CAMA = regex.compile(
    r"(?<!" + _LETRA + r")(?:cama|habitaci[oó]n|hab\.)\s+"
    r"(?:n(?:o\.?|[°º]|\.)\s*)?[A-Za-z]?-?\d+[A-Za-z]?(?!" + _LETRA + r")",
    regex.IGNORECASE,
)

_TRATAMIENTO = regex.compile(
    r"(?<!" + _LETRA + r")"
    r"(?:Sr\.|Sra\.|Srta\.|señor|señora|señorita|don|doña|Don|Doña|Señor|Señora|Señorita)"
    r"\s+((?:\p{Lu}\p{Ll}+)(?:\s+\p{Lu}\p{Ll}+){0,2})"
)

_COLA_NUMERO = regex.compile(r"[A-Za-z]?-?\d+[A-Za-z]?$")
_ESPACIOS = regex.compile(r"\s+")

# Partículas de nombres compuestos que no se reemplazan solas.
_PARTICULAS = frozenset({"del", "las", "los", "san", "santa", "van", "von"})

_CLASES_VOCALES = {
    "a": "[aáàAÁÀ]",
    "e": "[eéèEÉÈ]",
    "i": "[iíìIÍÌ]",
    "o": "[oóòOÓÒ]",
    "u": "[uúüUÚÜ]",
    "n": "[nñNÑ]",
}


def normalizar(texto: str) -> str:
    """Minúsculas, sin tildes, con espacios colapsados."""
    descompuesto = unicodedata.normalize("NFKD", texto)
    sin_tildes = "".join(c for c in descompuesto if not unicodedata.combining(c))
    return _ESPACIOS.sub(" ", sin_tildes.lower()).strip()


def _es_parte_identificable(parte: str) -> bool:
    return len(parte) >= 3 and normalizar(parte) not in _PARTICULAS


def _patron_flexible(palabra: str) -> regex.Pattern[str]:
    """Patrón que reconoce `palabra` como palabra completa, sin importar
    mayúsculas ni tildes."""
    partes: list[str] = [r"(?<!" + _LETRA + r")"]
    for c in normalizar(palabra):
        if c == " ":
            partes.append(r"\s+")
        else:
            partes.append(_CLASES_VOCALES.get(c, regex.escape(c)))
    partes.append(r"(?!" + _LETRA + r")")
    return regex.compile("".join(partes), regex.IGNORECASE)


class Anonimizador:
    def __init__(self) -> None:
        self._tabla: dict[str, str] = {}
        self._contadores: dict[str, int] = {}

    @property
    def tabla_reidentificacion(self) -> MappingProxyType[str, str]:
        """Vista de solo lectura: "PREFIJO|clave" -> código. Uso local y autorizado."""
        return MappingProxyType(self._tabla)

    def _codigo(self, prefijo: str, clave: str) -> str:
        k = f"{prefijo}|{clave}"
        if k not in self._tabla:
            n = self._contadores.get(prefijo, 0) + 1
            self._contadores[prefijo] = n
            self._tabla[k] = f"{prefijo}-{n:03d}"
        return self._tabla[k]

    def anonimizar(self, texto: str, nombres_conocidos: Iterable[str] = ()) -> str:
        salida = texto

        # 1. Nombres conocidos: nombre completo y después cada parte identificable.
        for nombre in nombres_conocidos:
            partes = [p for p in _ESPACIOS.split(nombre.strip()) if p]
            if not partes:
                continue
            codigo = self._codigo("PAC", normalizar(" ".join(partes)))
            candidatos = [" ".join(partes), *[p for p in partes if _es_parte_identificable(p)]]
            for c in candidatos:
                salida = _patron_flexible(c).sub(codigo, salida)

        # 2. Nombres precedidos de tratamiento de cortesía ("la señora Martínez").
        def _sustituir_tratamiento(m: regex.Match[str]) -> str:
            completo, nombre = m.group(0), m.group(1)
            tratamiento = completo[: len(completo) - len(nombre)]
            return tratamiento + self._codigo("PAC", normalizar(nombre))

        salida = _TRATAMIENTO.sub(_sustituir_tratamiento, salida)

        # 3. Cama / habitación (antes que documentos).
        def _sustituir_cama(m: regex.Match[str]) -> str:
            numero = _COLA_NUMERO.search(m.group(0))
            assert numero is not None  # el patrón de cama siempre termina en número
            return self._codigo("CAMA", numero.group(0).upper().replace("-", ""))

        salida = _CAMA.sub(_sustituir_cama, salida)

        # 4. Documentos de identidad (solo el número; el prefijo "C.C." se conserva).
        salida = _DOCUMENTO.sub(lambda m: self._codigo("ID", m.group(0).replace(".", "")), salida)
        return salida

    @staticmethod
    def contiene_datos_personales(texto: str, nombres: Iterable[str] = ()) -> bool:
        """True si queda algo que parezca documento, cama o alguno de los nombres.
        Los códigos ya anonimizados (PAC-001, CAMA-001, ID-001) NO cuentan:
        CAMA-001 no tiene espacio tras la palabra, así que no coincide."""
        if _DOCUMENTO.search(texto) or _CAMA.search(texto):
            return True
        for nombre in nombres:
            for parte in _ESPACIOS.split(nombre.strip()):
                if _es_parte_identificable(parte) and _patron_flexible(parte).search(texto):
                    return True
        return False
