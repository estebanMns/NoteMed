from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.seguridad import crear_token

SECRETO = "secreto-de-pruebas-con-mas-de-32-caracteres"


class ModeloEspia:
    """Doble de prueba del modelo: registra el contexto que recibe y responde
    con un borrador que reutiliza los códigos de la entrada."""

    def __init__(self, respuesta: str | None = None) -> None:
        self.contextos: list[str] = []
        self.respuesta = respuesta

    def generar(self, instruccion: str, contexto: str) -> str:
        self.contextos.append(contexto)
        if self.respuesta is not None:
            return self.respuesta
        return "Paciente PAC-001 en CAMA-001. TA 120/80, FC 88."


@pytest.fixture
def settings() -> Settings:
    return Settings(entorno="pruebas", database_url="sqlite:///:memory:", jwt_secret=SECRETO)


@pytest.fixture
def modelo() -> ModeloEspia:
    return ModeloEspia()


@pytest.fixture
def cliente(settings: Settings, modelo: ModeloEspia) -> TestClient:
    return TestClient(create_app(settings=settings, modelo=modelo))


def cabecera(settings: Settings, sub: str, rol: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {crear_token(sub, rol, settings)}"}  # type: ignore[arg-type]


@pytest.fixture
def enfermera(settings: Settings) -> dict[str, str]:
    return cabecera(settings, "ENF-01", "enfermero")


@pytest.fixture
def otra_enfermera(settings: Settings) -> dict[str, str]:
    return cabecera(settings, "ENF-02", "enfermero")


@pytest.fixture
def supervisor(settings: Settings) -> dict[str, str]:
    return cabecera(settings, "SUP-01", "supervisor")
