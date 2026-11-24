"""Inicio de sesión (contrato sección 2): usuario y clave -> JWT con rol."""

import jwt
import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.db.modelos import UsuarioORM
from app.main import create_app
from app.seguridad import hash_clave, verificar_clave
from app.servicios.autenticacion import ServicioAutenticacion
from tests.conftest import SECRETO

CLAVE = "clave-de-prueba-123"
SOLICITUD_IA = {"versionPrompts": "1.1.0", "sistema": "x", "solicitud": "TA 120/80"}


@pytest.fixture
def app(settings: Settings):
    return create_app(settings=settings, modelo=None)


@pytest.fixture
def cliente(app) -> TestClient:
    return TestClient(app)


def _alta(app, usuario: str, rol: str, tarjeta: str = "TP-10001") -> None:
    sesion = app.state.fabrica_sesiones()
    try:
        ServicioAutenticacion(sesion, app.state.settings).crear_usuario(usuario, CLAVE, tarjeta, rol)
    finally:
        sesion.close()


@pytest.fixture
def enfermera(app):
    _alta(app, "enfermera1", "enfermera")


@pytest.fixture
def jefe(app):
    _alta(app, "jefe1", "jefe", tarjeta="TP-20001")


def test_login_devuelve_jwt_con_el_rol_del_usuario(cliente, enfermera):
    r = cliente.post("/v1/auth/sesiones", json={"usuario": "enfermera1", "clave": CLAVE})
    assert r.status_code == 200
    cuerpo = r.json()
    assert set(cuerpo) == {"token", "expira", "usuario"}
    assert cuerpo["usuario"] == {
        "usuario": "enfermera1",
        "tarjetaProfesional": "TP-10001",
        "rol": "enfermera",
    }
    datos = jwt.decode(cuerpo["token"], SECRETO, algorithms=["HS256"])
    assert datos["sub"] == "enfermera1"
    assert datos["rol"] == "enfermera"


def test_el_token_del_login_abre_la_api(cliente, enfermera):
    token = cliente.post("/v1/auth/sesiones", json={"usuario": "enfermera1", "clave": CLAVE}).json()["token"]
    r = cliente.post("/v1/ia/borradores", json=SOLICITUD_IA, headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200


def test_el_jefe_ve_metricas_y_la_enfermera_no(cliente, enfermera, jefe):
    tok_enf = cliente.post("/v1/auth/sesiones", json={"usuario": "enfermera1", "clave": CLAVE}).json()[
        "token"
    ]
    tok_jefe = cliente.post("/v1/auth/sesiones", json={"usuario": "jefe1", "clave": CLAVE}).json()["token"]
    assert (
        cliente.get("/v1/metricas/borradores", headers={"Authorization": f"Bearer {tok_enf}"}).status_code
        == 403
    )
    assert (
        cliente.get("/v1/metricas/borradores", headers={"Authorization": f"Bearer {tok_jefe}"}).status_code
        == 200
    )


def test_clave_incorrecta_y_usuario_inexistente_dan_el_mismo_error(cliente, enfermera):
    mala = cliente.post("/v1/auth/sesiones", json={"usuario": "enfermera1", "clave": "otra-clave-999"})
    inexistente = cliente.post("/v1/auth/sesiones", json={"usuario": "nadie", "clave": CLAVE})
    assert mala.status_code == inexistente.status_code == 401
    assert mala.json() == inexistente.json()
    assert mala.json()["codigo"] == "credenciales_invalidas"


def test_la_clave_se_guarda_derivada_no_en_claro(app, enfermera):
    sesion = app.state.fabrica_sesiones()
    registro = sesion.query(UsuarioORM).filter_by(usuario="enfermera1").one()
    assert CLAVE not in registro.clave_hash
    assert verificar_clave(CLAVE, registro.clave_hash)
    assert not verificar_clave("otra", registro.clave_hash)
    sesion.close()


def test_usuario_inactivo_no_puede_entrar(app, enfermera, cliente):
    sesion = app.state.fabrica_sesiones()
    registro = sesion.query(UsuarioORM).filter_by(usuario="enfermera1").one()
    registro.activo = False
    sesion.commit()
    sesion.close()
    r = cliente.post("/v1/auth/sesiones", json={"usuario": "enfermera1", "clave": CLAVE})
    assert r.status_code == 401


def test_no_se_puede_dar_de_alta_dos_veces_el_mismo_usuario(app, enfermera):
    sesion = app.state.fabrica_sesiones()
    try:
        with pytest.raises(Exception, match="Ya existe"):
            ServicioAutenticacion(sesion, app.state.settings).crear_usuario(
                "enfermera1", CLAVE, "TP-2", "enfermera"
            )
    finally:
        sesion.close()


def test_rol_inexistente_se_rechaza_al_dar_de_alta(app):
    sesion = app.state.fabrica_sesiones()
    try:
        with pytest.raises(ValueError, match="Rol desconocido"):
            ServicioAutenticacion(sesion, app.state.settings).crear_usuario("x1", CLAVE, "TP-3", "supervisor")
    finally:
        sesion.close()


def test_token_firmado_con_otro_secreto_se_rechaza(cliente):
    falso = jwt.encode(
        {"sub": "enfermera1", "rol": "enfermera", "exp": 9999999999},
        "otro-secreto-de-32-caracteres-xx",
        algorithm="HS256",
    )
    r = cliente.post("/v1/ia/borradores", json=SOLICITUD_IA, headers={"Authorization": f"Bearer {falso}"})
    assert r.status_code == 401


def test_hash_scrypt_es_salado():
    assert hash_clave("misma") != hash_clave("misma")
