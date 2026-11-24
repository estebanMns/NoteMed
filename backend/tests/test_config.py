import pytest
from pydantic import ValidationError

from app.config import Settings


def test_produccion_exige_secreto_fuerte():
    with pytest.raises(ValidationError):
        Settings(entorno="produccion", jwt_secret="corto", database_url="sqlite:///x.db")


def test_proveedor_http_exige_url_y_modelo():
    with pytest.raises(ValidationError):
        Settings(entorno="produccion", jwt_secret="x" * 40, llm_proveedor="http")


def test_produccion_rechaza_el_secreto_de_ejemplo():
    with pytest.raises(ValidationError):
        Settings(
            entorno="produccion",
            jwt_secret="cambiar-en-produccion-minimo-32-caracteres",
            database_url="sqlite:///x.db",
        )


def test_produccion_acepta_secreto_aleatorio():
    cfg = Settings(
        entorno="produccion", jwt_secret="k9J2mQ7vX1zR4tL8pN3wB6yH0sD5fG2a", database_url="sqlite:///x.db"
    )
    assert cfg.entorno == "produccion"
