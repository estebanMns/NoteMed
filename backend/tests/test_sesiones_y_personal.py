"""Sesiones con cierre por inactividad (2 minutos) y administración del personal (jefe)."""

from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from tests.conftest import CLAVE_PRUEBA, iniciar_sesion_como

# Parte de la hora real: PyJWT valida iat y exp contra el reloj del sistema.
AHORA = datetime.now(UTC).replace(microsecond=0)


class Reloj:
    """Reloj simulado: las pruebas avanzan el tiempo sin esperar de verdad."""

    def __init__(self, inicio: datetime) -> None:
        self.ahora = inicio

    def __call__(self) -> datetime:
        return self.ahora

    def avanzar(self, **kwargs: float) -> None:
        self.ahora += timedelta(**kwargs)


@pytest.fixture
def reloj() -> Reloj:
    return Reloj(AHORA)


@pytest.fixture
def cliente(settings: Settings, reloj: Reloj) -> TestClient:
    app = create_app(settings=settings)
    app.state.reloj = reloj
    return TestClient(app)


def _cabecera(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _token(cliente: TestClient, usuario: str, clave: str = CLAVE_PRUEBA) -> dict[str, str]:
    r = cliente.post("/v1/auth/sesiones", json={"usuario": usuario, "clave": clave})
    assert r.status_code == 200, r.text
    return _cabecera(r.json()["token"])


# ---------- inactividad ----------


def test_sesion_activa_sigue_viva_mientras_se_use(cliente, reloj, jefe):
    # `jefe` inicia sesión en AHORA; cada uso renueva la actividad.
    for _ in range(4):
        reloj.avanzar(minutes=1.5)
        assert cliente.get("/v1/usuarios", headers=jefe).status_code == 200


def test_tras_2_minutos_sin_actividad_el_token_expira(cliente, reloj, jefe):
    assert cliente.get("/v1/usuarios", headers=jefe).status_code == 200
    reloj.avanzar(minutes=2, seconds=1)
    r = cliente.get("/v1/usuarios", headers=jefe)
    assert r.status_code == 401
    assert r.json()["codigo"] == "sesion_inactiva"
    assert "inactividad" in r.json()["error"]


def test_despues_de_expirar_el_mismo_token_ya_no_sirve(cliente, reloj, jefe):
    reloj.avanzar(minutes=3)
    assert cliente.get("/v1/usuarios", headers=jefe).status_code == 401
    # Aunque vuelva la actividad, la sesión quedó revocada: hay que iniciar sesión otra vez.
    reloj.avanzar(seconds=5)
    r = cliente.get("/v1/usuarios", headers=jefe)
    assert r.status_code == 401
    assert r.json()["codigo"] == "sesion_cerrada"


def test_la_regla_aplica_a_las_enfermeras_tambien(cliente, reloj, enfermera):
    reloj.avanzar(minutes=2, seconds=30)
    r = cliente.post(
        "/v1/ia/borradores",
        json={"versionPrompts": "1", "sistema": "x", "solicitud": "TA 120/80"},
        headers=enfermera,
    )
    assert r.status_code == 401
    assert r.json()["codigo"] == "sesion_inactiva"


def test_cierre_de_sesion_revoca_el_token(cliente, enfermera):
    assert cliente.post("/v1/auth/cierre", headers=enfermera).status_code == 204
    r = cliente.post(
        "/v1/ia/borradores", json={"versionPrompts": "1", "sistema": "x", "solicitud": "y"}, headers=enfermera
    )
    assert r.status_code == 401
    assert r.json()["codigo"] == "sesion_cerrada"


# ---------- administración del personal (solo jefe) ----------


def test_la_enfermera_no_administra_el_personal(cliente, enfermera):
    assert cliente.get("/v1/usuarios", headers=enfermera).status_code == 403
    r = cliente.post(
        "/v1/usuarios",
        headers=enfermera,
        json={"usuario": "nueva1", "clave": "clave-nueva-123", "tarjetaProfesional": "TP-1"},
    )
    assert r.status_code == 403


def test_jefe_agrega_edita_y_da_de_baja_una_enfermera(cliente, jefe):
    r = cliente.post(
        "/v1/usuarios",
        headers=jefe,
        json={"usuario": "enfermera3", "clave": "clave-nueva-123", "tarjetaProfesional": "TP-30003"},
    )
    assert r.status_code == 201
    assert r.json() == {
        "usuario": "enfermera3",
        "tarjetaProfesional": "TP-30003",
        "rol": "enfermera",
        "activo": True,
    }

    lista = cliente.get("/v1/usuarios", headers=jefe).json()
    assert "enfermera3" in [u["usuario"] for u in lista]

    r = cliente.put("/v1/usuarios/enfermera3", headers=jefe, json={"tarjetaProfesional": "TP-30099"})
    assert r.status_code == 200
    assert r.json()["tarjetaProfesional"] == "TP-30099"

    assert cliente.delete("/v1/usuarios/enfermera3", headers=jefe).status_code == 204
    activas = [u["usuario"] for u in cliente.get("/v1/usuarios", headers=jefe).json()]
    assert "enfermera3" not in activas
    todas = cliente.get("/v1/usuarios?incluir_inactivos=true", headers=jefe).json()
    assert {
        "usuario": "enfermera3",
        "tarjetaProfesional": "TP-30099",
        "rol": "enfermera",
        "activo": False,
    } in todas


def test_dar_de_baja_impide_entrar_y_cierra_sus_sesiones(cliente, jefe):
    cliente.post(
        "/v1/usuarios",
        headers=jefe,
        json={"usuario": "enfermera4", "clave": "clave-nueva-123", "tarjetaProfesional": "TP-40004"},
    )
    enf = _token(cliente, "enfermera4", "clave-nueva-123")
    assert (
        cliente.post(
            "/v1/ia/borradores", json={"versionPrompts": "1", "sistema": "x", "solicitud": "y"}, headers=enf
        ).status_code
        == 200
    )

    cliente.delete("/v1/usuarios/enfermera4", headers=jefe)

    r = cliente.post("/v1/auth/sesiones", json={"usuario": "enfermera4", "clave": "clave-nueva-123"})
    assert r.status_code == 401
    r = cliente.post(
        "/v1/ia/borradores", json={"versionPrompts": "1", "sistema": "x", "solicitud": "y"}, headers=enf
    )
    assert r.status_code == 401


def test_al_cambiar_la_clave_se_cierran_las_sesiones_anteriores(cliente, jefe):
    cliente.post(
        "/v1/usuarios",
        headers=jefe,
        json={"usuario": "enfermera5", "clave": "clave-vieja-123", "tarjetaProfesional": "TP-50005"},
    )
    vieja = _token(cliente, "enfermera5", "clave-vieja-123")
    assert (
        cliente.put("/v1/usuarios/enfermera5", headers=jefe, json={"clave": "clave-nueva-456"}).status_code
        == 200
    )
    r = cliente.post(
        "/v1/ia/borradores", json={"versionPrompts": "1", "sistema": "x", "solicitud": "y"}, headers=vieja
    )
    assert r.status_code == 401
    _token(cliente, "enfermera5", "clave-nueva-456")  # la nueva sí funciona


def test_el_jefe_no_puede_darse_de_baja_a_si_mismo(cliente, jefe):
    r = cliente.delete("/v1/usuarios/JEF-01", headers=jefe)
    assert r.status_code == 403


def test_el_jefe_no_edita_otras_cuentas_de_jefe(cliente, jefe, settings):
    iniciar_sesion_como(cliente, "JEF-02", "jefe", tarjeta="TP-20002")
    r = cliente.put("/v1/usuarios/JEF-02", headers=jefe, json={"tarjetaProfesional": "TP-x"})
    assert r.status_code == 404


def test_validaciones_del_alta(cliente, jefe):
    r = cliente.post(
        "/v1/usuarios",
        headers=jefe,
        json={"usuario": "Ana Torres", "clave": "clave-nueva-123", "tarjetaProfesional": "TP-1"},
    )
    assert r.status_code == 422
    r = cliente.post(
        "/v1/usuarios",
        headers=jefe,
        json={"usuario": "corta1", "clave": "corta", "tarjetaProfesional": "TP-1"},
    )
    assert r.status_code == 422
    assert r.json()["codigo"] == "datos_invalidos"


def test_no_se_puede_crear_un_usuario_repetido(cliente, jefe):
    body = {"usuario": "enfermera6", "clave": "clave-nueva-123", "tarjetaProfesional": "TP-6"}
    assert cliente.post("/v1/usuarios", headers=jefe, json=body).status_code == 201
    assert cliente.post("/v1/usuarios", headers=jefe, json=body).status_code == 409
