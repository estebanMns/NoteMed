"""Flujo completo de la API: paciente -> borrador -> revisión -> firma."""

import base64
import uuid

from tests.conftest import ModeloEspia

DATOS = "Paciente Ana Torres, cama 12, TA 120/80, FC 88."


def _crear_paciente(cliente, cabecera, pseudonimo="PAC-001"):
    r = cliente.post("/v1/pacientes", json={"pseudonimo": pseudonimo}, headers=cabecera)
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _borrador(cliente, cabecera, paciente_id, nota_id=None):
    return cliente.post(
        "/v1/notas/borradores",
        json={
            "id": nota_id or str(uuid.uuid4()),
            "paciente_id": paciente_id,
            "tipo": "evolucion",
            "datos": DATOS,
            "nombres_conocidos": ["Ana Torres"],
        },
        headers=cabecera,
    )


def test_flujo_completo_hasta_firma(cliente, enfermera, modelo: ModeloEspia):
    paciente_id = _crear_paciente(cliente, enfermera)
    r = _borrador(cliente, enfermera, paciente_id)
    assert r.status_code == 201
    nota = r.json()
    assert nota["estado"] == "borrador"
    assert nota["version"] == 1
    assert "Ana Torres" in nota["texto"]  # re-identificado para la enfermera
    assert nota["hallazgos"] == []  # cifras y códigos sustentados
    assert nota["prompt_version"]

    r = cliente.put(
        f"/v1/notas/{nota['id']}/revision",
        json={"version": 1, "texto": "Paciente Ana Torres. TA 120/80, FC 88."},
        headers=enfermera,
    )
    assert r.status_code == 200
    assert r.json()["estado"] == "revisada"
    assert r.json()["version"] == 2

    r = cliente.post(f"/v1/notas/{nota['id']}/firma", json={"version": 2}, headers=enfermera)
    assert r.status_code == 200, r.text
    firmada = r.json()
    assert firmada["estado"] == "firmada"
    assert firmada["firmada_por"] == "ENF-01"
    assert firmada["version"] == 3


def test_el_nombre_real_nunca_llega_al_modelo(cliente, enfermera, modelo: ModeloEspia):
    paciente_id = _crear_paciente(cliente, enfermera)
    _borrador(cliente, enfermera, paciente_id)
    enviado = modelo.contextos[-1]
    assert "Ana" not in enviado and "Torres" not in enviado
    assert "PAC-001" in enviado and "CAMA-001" in enviado


def test_reenvio_offline_es_idempotente(cliente, enfermera):
    paciente_id = _crear_paciente(cliente, enfermera)
    nota_id = str(uuid.uuid4())
    primera = _borrador(cliente, enfermera, paciente_id, nota_id)
    segunda = _borrador(cliente, enfermera, paciente_id, nota_id)
    assert primera.status_code == 201
    assert segunda.status_code == 200
    assert primera.json()["id"] == segunda.json()["id"]


def test_firma_bloqueada_por_sigla_prohibida(cliente, enfermera):
    paciente_id = _crear_paciente(cliente, enfermera)
    nota = _borrador(cliente, enfermera, paciente_id).json()
    cliente.put(
        f"/v1/notas/{nota['id']}/revision",
        json={"version": 1, "texto": "Paciente Ana Torres. TA 120/80, dosis QD."},
        headers=enfermera,
    )
    r = cliente.post(f"/v1/notas/{nota['id']}/firma", json={"version": 2}, headers=enfermera)
    assert r.status_code == 422
    cuerpo = r.json()
    assert cuerpo["error"] == "nota_no_firmable"
    assert any('"QD"' in m for m in cuerpo["motivos"])


def test_firma_bloqueada_por_cifra_no_sustentada(cliente, enfermera):
    paciente_id = _crear_paciente(cliente, enfermera)
    nota = _borrador(cliente, enfermera, paciente_id).json()
    cliente.put(
        f"/v1/notas/{nota['id']}/revision",
        json={"version": 1, "texto": "Paciente Ana Torres. TA 180/100, FC 88."},
        headers=enfermera,
    )
    r = cliente.post(f"/v1/notas/{nota['id']}/firma", json={"version": 2}, headers=enfermera)
    assert r.status_code == 422
    assert any('"180"' in m for m in r.json()["motivos"])


def test_conflicto_de_version(cliente, enfermera):
    paciente_id = _crear_paciente(cliente, enfermera)
    nota = _borrador(cliente, enfermera, paciente_id).json()
    r = cliente.put(f"/v1/notas/{nota['id']}/revision", json={"version": 99, "texto": "x"}, headers=enfermera)
    assert r.status_code == 409
    assert r.json()["error"] == "conflicto_version"


def test_no_se_firma_dos_veces(cliente, enfermera):
    paciente_id = _crear_paciente(cliente, enfermera)
    nota = _borrador(cliente, enfermera, paciente_id).json()
    cliente.put(
        f"/v1/notas/{nota['id']}/revision",
        json={"version": 1, "texto": "TA 120/80, FC 88."},
        headers=enfermera,
    )
    cliente.post(f"/v1/notas/{nota['id']}/firma", json={"version": 2}, headers=enfermera)
    r = cliente.post(f"/v1/notas/{nota['id']}/firma", json={"version": 3}, headers=enfermera)
    assert r.status_code == 409


def test_otra_enfermera_no_ve_ni_firma_la_nota(cliente, enfermera, otra_enfermera):
    paciente_id = _crear_paciente(cliente, enfermera)
    nota = _borrador(cliente, enfermera, paciente_id).json()
    assert cliente.get(f"/v1/notas/{nota['id']}", headers=otra_enfermera).status_code == 403
    r = cliente.put(
        f"/v1/notas/{nota['id']}/revision", json={"version": 1, "texto": "TA 120/80"}, headers=otra_enfermera
    )
    assert r.status_code == 403


def test_supervisor_lee_pero_no_firma(cliente, enfermera, supervisor):
    paciente_id = _crear_paciente(cliente, enfermera)
    nota = _borrador(cliente, enfermera, paciente_id).json()
    assert cliente.get(f"/v1/notas/{nota['id']}", headers=supervisor).status_code == 200
    r = cliente.post(f"/v1/notas/{nota['id']}/firma", json={"version": 1}, headers=supervisor)
    assert r.status_code == 403


def test_sin_token_o_token_falso_da_401(cliente):
    assert cliente.get("/v1/notas/x").status_code == 401
    assert cliente.get("/v1/notas/x", headers={"Authorization": "Bearer falso"}).status_code == 401


def test_metricas_solo_para_supervisor(cliente, enfermera, supervisor):
    paciente_id = _crear_paciente(cliente, enfermera)
    nota = _borrador(cliente, enfermera, paciente_id).json()
    cliente.put(
        f"/v1/notas/{nota['id']}/revision",
        json={"version": 1, "texto": "Paciente Ana Torres. TA 120/80, FC 88."},
        headers=enfermera,
    )
    cliente.post(f"/v1/notas/{nota['id']}/firma", json={"version": 2}, headers=enfermera)

    assert cliente.get("/v1/metricas/borradores", headers=enfermera).status_code == 403
    r = cliente.get("/v1/metricas/borradores", headers=supervisor)
    assert r.status_code == 200
    datos = r.json()
    assert datos["notas_totales"] == 1
    assert datos["notas_firmadas"] == 1
    assert datos["aceptadas_sin_edicion"] == 0
    assert datos["edicion_promedio_pct"] > 0


def test_exporta_documento_fhir(cliente, enfermera):
    paciente_id = _crear_paciente(cliente, enfermera)
    nota = _borrador(cliente, enfermera, paciente_id).json()
    r = cliente.get(f"/v1/notas/{nota['id']}/fhir", headers=enfermera)
    assert r.status_code == 200
    recurso = r.json()
    assert recurso["resourceType"] == "DocumentReference"
    assert recurso["status"] == "preliminary"
    texto = base64.b64decode(recurso["content"][0]["attachment"]["data"]).decode()
    assert "Ana Torres" in texto


def test_pseudonimo_invalido_se_rechaza(cliente, enfermera):
    r = cliente.post("/v1/pacientes", json={"pseudonimo": "Ana Torres"}, headers=enfermera)
    assert r.status_code == 422


def test_campos_desconocidos_se_rechazan(cliente, enfermera):
    r = cliente.post("/v1/pacientes", json={"pseudonimo": "PAC-009", "nombre": "Ana"}, headers=enfermera)
    assert r.status_code == 422


def test_paciente_duplicado_da_409(cliente, enfermera):
    _crear_paciente(cliente, enfermera, "PAC-010")
    r = cliente.post("/v1/pacientes", json={"pseudonimo": "PAC-010"}, headers=enfermera)
    assert r.status_code == 409


def test_revision_con_cama_y_documento_originales_se_puede_firmar(cliente, enfermera):
    """Regresión: el número de cama y el documento son correctos aunque la
    entrada seudonimizada solo tenga los códigos CAMA-001 e ID-001."""
    paciente_id = _crear_paciente(cliente, enfermera, "PAC-020")
    nota_id = str(uuid.uuid4())
    r = cliente.post(
        "/v1/notas/borradores",
        json={
            "id": nota_id,
            "paciente_id": paciente_id,
            "tipo": "recibo",
            "datos": "Paciente Ana Torres, C.C. 1.023.456.789, cama 12. TA 120/80.",
            "nombres_conocidos": ["Ana Torres"],
        },
        headers=enfermera,
    )
    assert r.status_code == 201
    texto = "Paciente Ana Torres, C.C. 1.023.456.789, cama 12. TA 120/80."
    cliente.put(f"/v1/notas/{nota_id}/revision", json={"version": 1, "texto": texto}, headers=enfermera)
    r = cliente.post(f"/v1/notas/{nota_id}/firma", json={"version": 2}, headers=enfermera)
    assert r.status_code == 200, r.text
