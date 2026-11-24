from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.domain.errores import UsuarioExistente
from app.main import create_app
from app.servicios.autenticacion import ServicioAutenticacion

SECRETO = "secreto-de-pruebas-con-mas-de-32-caracteres"
CLAVE_PRUEBA = "clave-de-prueba-123"


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


def iniciar_sesion_como(
    cliente: TestClient, usuario: str, rol: str, tarjeta: str = "TP-10001"
) -> dict[str, str]:
    """Da de alta al usuario (si no existe) e inicia sesión por la API, como la app."""
    app = cliente.app
    sesion = app.state.fabrica_sesiones()
    try:
        ServicioAutenticacion(sesion, app.state.settings, app.state.reloj).crear_usuario(
            usuario, CLAVE_PRUEBA, tarjeta, rol
        )
    except UsuarioExistente:
        pass
    finally:
        sesion.close()
    r = cliente.post("/v1/auth/sesiones", json={"usuario": usuario, "clave": CLAVE_PRUEBA})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['token']}"}


@pytest.fixture
def enfermera(cliente: TestClient) -> dict[str, str]:
    return iniciar_sesion_como(cliente, "ENF-01", "enfermera")


@pytest.fixture
def otra_enfermera(cliente: TestClient) -> dict[str, str]:
    return iniciar_sesion_como(cliente, "ENF-02", "enfermera")


@pytest.fixture
def jefe(cliente: TestClient) -> dict[str, str]:
    return iniciar_sesion_como(cliente, "JEF-01", "jefe", tarjeta="TP-20001")
