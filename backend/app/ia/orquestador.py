"""Caso de uso: generar un borrador de nota con IA (PDF §3.6, casos de uso).

Pasos, en orden:
  1. Seudonimizar los datos (Ley 1581).
  2. Barrera: si queda algo identificable, NO se llama al modelo.
  3. Generar con el prompt versionado.
  4. Verificar la salida contra la entrada (cadena de verificación).
  5. Re-identificar localmente para la enfermera.
"""

from __future__ import annotations

from dataclasses import dataclass

import regex

from app.domain.errores import DatosNoSeguros
from app.domain.nota import TipoNota
from app.ia.modelo import ModeloLenguaje
from app.ia.prompts import PROMPT_VERSION, instruccion_para
from app.ia.verificacion import Verificacion, verificar
from app.privacidad.anonimizador import Anonimizador, normalizar

_ESPACIOS = regex.compile(r"\s+")


@dataclass(frozen=True)
class Borrador:
    texto: str
    entrada_anonima: str
    verificacion: Verificacion
    valores_identificadores: tuple[str, ...] = ()
    prompt_version: str = PROMPT_VERSION


def reidentificar(texto: str, anon: Anonimizador, nombres: list[str]) -> str:
    """Devuelve nombres, camas e IDs originales a partir de la tabla en memoria."""
    originales: dict[str, str] = {}
    for n in nombres:
        limpio = " ".join(_ESPACIOS.split(n.strip()))
        originales.setdefault(normalizar(limpio), limpio)

    salida = texto
    for clave_completa, codigo in anon.tabla_reidentificacion.items():
        prefijo, _, clave = clave_completa.partition("|")
        if prefijo == "PAC":
            original = originales.get(clave, clave)
        elif prefijo == "CAMA":
            original = f"cama {clave}"
        else:
            original = clave
        patron = regex.compile(regex.escape(codigo) + r"(?!\d)")

        def _sustituir(_m: regex.Match[str], valor: str = original) -> str:
            return valor

        salida = patron.sub(_sustituir, salida)
    return salida


class GeneradorBorrador:
    def __init__(self, modelo: ModeloLenguaje) -> None:
        self._modelo = modelo

    def ejecutar(self, tipo: TipoNota, datos: str, nombres_pacientes: list[str]) -> Borrador:
        anon = Anonimizador()
        entrada = anon.anonimizar(datos, nombres_conocidos=nombres_pacientes)

        if Anonimizador.contiene_datos_personales(entrada, nombres=nombres_pacientes):
            raise DatosNoSeguros("Quedan datos personales en la entrada; no se envía al modelo.")

        valores = anon.valores_identificadores()
        salida = self._modelo.generar(instruccion_para(tipo), entrada)
        verificacion = verificar(salida, entrada, valores_identificadores=valores)
        texto = reidentificar(salida, anon, nombres_pacientes)
        return Borrador(
            texto=texto,
            entrada_anonima=entrada,
            verificacion=verificacion,
            valores_identificadores=valores,
        )
