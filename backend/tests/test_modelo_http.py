import httpx
import pytest

from app.domain.errores import LlmNoDisponible
from app.ia.modelo import ModeloHttp


def _modelo(handler) -> ModeloHttp:
    return ModeloHttp(
        "https://ia.example/v1", "clave-falsa", "modelo-x", 5, transporte=httpx.MockTransport(handler)
    )


def test_respuesta_correcta_y_formato_chat_completions():
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/v1/chat/completions"
        assert request.headers["Authorization"] == "Bearer clave-falsa"
        assert request.read()  # cuerpo JSON presente
        return httpx.Response(200, json={"choices": [{"message": {"content": "Nota redactada."}}]})

    assert _modelo(handler).generar("instr", "ctx") == "Nota redactada."


def test_error_http_se_traduce_a_dominio():
    modelo = _modelo(lambda r: httpx.Response(500))
    with pytest.raises(LlmNoDisponible):
        modelo.generar("instr", "ctx")


def test_respuesta_malformada_se_traduce_a_dominio():
    modelo = _modelo(lambda r: httpx.Response(200, json={"otra": 1}))
    with pytest.raises(LlmNoDisponible):
        modelo.generar("instr", "ctx")


def test_respuesta_vacia_se_rechaza():
    modelo = _modelo(lambda r: httpx.Response(200, json={"choices": [{"message": {"content": "  "}}]}))
    with pytest.raises(LlmNoDisponible):
        modelo.generar("instr", "ctx")
