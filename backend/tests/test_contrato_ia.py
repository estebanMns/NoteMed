"""Contrato con la app, sección 1 (docs/contrato_api.md): POST /v1/ia/borradores."""

from fastapi.testclient import TestClient

from app.config import Settings
from app.domain.errores import LlmNoDisponible
from app.main import create_app
from tests.conftest import iniciar_sesion_como

SOLICITUD = (
    "Paciente: PAC-001, cédula ID-001, 67 años, CAMA-001\n"
    "Signos vitales: TA 120/80 mmHg, FC 84 lpm\n"
    "Infusiones: \n- Noradrenalina 0.1 mcg/kg/min a 8 mL/h"
)
CUERPO = {"versionPrompts": "1.1.0", "sistema": "Instrucciones de prueba.", "solicitud": SOLICITUD}


class _Modelo:
    def __init__(self, texto: str = "[S] Situación: PAC-001 en CAMA-001 estable.", falla: bool = False):
        self.llamadas: list[tuple[str, str]] = []
        self.texto = texto
        self.falla = falla

    def generar(self, instruccion: str, contexto: str) -> str:
        self.llamadas.append((instruccion, contexto))
        if self.falla:
            raise LlmNoDisponible("sin respuesta")
        return self.texto


def _cliente(settings: Settings, modelo: _Modelo) -> TestClient:
    return TestClient(create_app(settings=settings, modelo=modelo))


def _cliente_autenticado(settings: Settings, modelo: _Modelo) -> TestClient:
    cliente = _cliente(settings, modelo)
    cliente.headers.update(iniciar_sesion_como(cliente, "ENF-01", "enfermera"))
    return cliente


def test_devuelve_texto_y_pasa_las_instrucciones_tal_cual(settings):
    modelo = _Modelo()
    r = _cliente_autenticado(settings, modelo).post("/v1/ia/borradores", json=CUERPO)
    assert r.status_code == 200
    assert r.json() == {"texto": "[S] Situación: PAC-001 en CAMA-001 estable."}
    assert modelo.llamadas == [("Instrucciones de prueba.", SOLICITUD)]


def test_sin_token_da_401_con_mensaje_para_mostrar(settings):
    r = _cliente(settings, _Modelo()).post("/v1/ia/borradores", json=CUERPO)
    assert r.status_code == 401
    assert isinstance(r.json()["error"], str) and r.json()["error"]


def test_token_opcional_solo_en_desarrollo_si_se_desactiva(settings):
    dev = settings.model_copy(update={"ia_requiere_token": False})
    r = _cliente(dev, _Modelo()).post("/v1/ia/borradores", json=CUERPO)
    assert r.status_code == 200


def test_rechaza_solicitud_con_cama_sin_seudonimizar(settings):
    modelo = _Modelo()
    cuerpo = {**CUERPO, "solicitud": "Paciente PAC-001 en cama 12"}
    r = _cliente_autenticado(settings, modelo).post("/v1/ia/borradores", json=cuerpo)
    assert r.status_code == 422
    assert r.json()["codigo"] == "datos_no_seguros"
    assert modelo.llamadas == []  # nunca llega al modelo


def test_fallo_del_modelo_da_503_para_que_la_app_encole(settings):
    r = _cliente_autenticado(settings, _Modelo(falla=True)).post("/v1/ia/borradores", json=CUERPO)
    assert r.status_code == 503
    assert "error" in r.json()


def test_cuerpo_invalido_da_422_con_error(settings):
    r = _cliente_autenticado(settings, _Modelo()).post("/v1/ia/borradores", json={"sistema": ""})
    assert r.status_code == 422
    body = r.json()
    assert body["codigo"] == "datos_invalidos"
    assert "error" in body and "detalle" in body


def test_campos_extra_se_rechazan(settings):
    r = _cliente_autenticado(settings, _Modelo()).post("/v1/ia/borradores", json={**CUERPO, "x": 1})
    assert r.status_code == 422
