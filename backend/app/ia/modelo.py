"""Puerto del modelo de lenguaje y sus adaptadores.

El resto del backend solo conoce `ModeloLenguaje`. Cambiar de proveedor es
cambiar de adaptador (Arquitectura Limpia, PDF §2.2.7)."""

from __future__ import annotations

from typing import Protocol

import httpx

from app.config import Settings
from app.domain.errores import LlmNoDisponible


class ModeloLenguaje(Protocol):
    def generar(self, instruccion: str, contexto: str) -> str: ...


class ModeloSimulado:
    """Adaptador determinista para desarrollo y pruebas (datos sintéticos)."""

    def generar(self, instruccion: str, contexto: str) -> str:
        lineas = [linea.strip() for linea in contexto.splitlines() if linea.strip()]
        return "Borrador generado a partir de los datos registrados:\n" + "\n".join(
            f"- {linea}" for linea in lineas
        )


class ModeloHttp:
    """Adaptador para APIs compatibles con chat completions (formato OpenAI)."""

    def __init__(
        self,
        base_url: str,
        api_key: str,
        modelo: str,
        timeout_s: float,
        transporte: httpx.BaseTransport | None = None,
    ) -> None:
        self._modelo = modelo
        self._cliente = httpx.Client(
            base_url=base_url.rstrip("/"),
            timeout=timeout_s,
            headers={"Authorization": f"Bearer {api_key}"},
            transport=transporte,
        )

    def generar(self, instruccion: str, contexto: str) -> str:
        cuerpo = {
            "model": self._modelo,
            "temperature": 0.2,
            "messages": [
                {"role": "system", "content": instruccion},
                {"role": "user", "content": contexto},
            ],
        }
        try:
            respuesta = self._cliente.post("/chat/completions", json=cuerpo)
            respuesta.raise_for_status()
            texto = respuesta.json()["choices"][0]["message"]["content"]
        except (httpx.HTTPError, KeyError, IndexError, TypeError, ValueError) as error:
            raise LlmNoDisponible("El servicio de redacción no respondió correctamente.") from error
        if not isinstance(texto, str) or not texto.strip():
            raise LlmNoDisponible("El servicio de redacción devolvió una respuesta vacía.")
        return texto


def crear_modelo(settings: Settings) -> ModeloLenguaje:
    if settings.llm_proveedor == "http":
        return ModeloHttp(
            base_url=settings.llm_base_url,
            api_key=settings.llm_api_key.get_secret_value(),
            modelo=settings.llm_modelo,
            timeout_s=settings.llm_timeout_s,
        )
    return ModeloSimulado()
