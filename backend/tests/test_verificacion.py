from app.ia.verificacion import verificar

ENTRADA = "Paciente PAC-001, CAMA-001, TA 120/80, FC 88."


def test_borrador_fiel_no_tiene_hallazgos():
    assert verificar("Paciente PAC-001 en CAMA-001. TA 120/80, FC 88.", ENTRADA).limpio


def test_detecta_cifra_inventada():
    v = verificar("TA 150/90 en PAC-001.", ENTRADA)
    valores = {h.valor for h in v.datos if h.tipo == "cifra_no_sustentada"}
    assert {"150", "90"} <= valores
    assert not v.limpio


def test_detecta_codigo_que_no_es_del_paciente():
    v = verificar("Paciente PAC-002 estable.", ENTRADA)
    assert [h.tipo for h in v.datos] == ["codigo_desconocido"]


def test_siglas_tambien_se_verifican():
    v = verificar("Paciente PAC-001, dosis QD.", ENTRADA)
    assert len(v.siglas) == 1
