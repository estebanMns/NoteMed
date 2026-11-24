"""Generación de texto para el contrato con la app (sección 1).

La app ya seudonimizó la solicitud. Aun así, el backend vuelve a comprobar que
no llegue ningún documento o cama sin codificar: es la última barrera antes del
modelo (Ley 1581 de 2012)."""

from __future__ import annotations

from app.domain.errores import DatosNoSeguros
from app.ia.modelo import ModeloLenguaje
from app.privacidad.anonimizador import Anonimizador


def generar_texto(modelo: ModeloLenguaje, sistema: str, solicitud: str) -> str:
    if Anonimizador.contiene_datos_personales(solicitud):
        raise DatosNoSeguros("La solicitud contiene documentos o camas sin seudonimizar.")
    return modelo.generar(sistema, solicitud)
