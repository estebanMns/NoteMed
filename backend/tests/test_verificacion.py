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


def test_cama_original_no_es_dato_inventado():
    # La entrada ya dice CAMA-001; el número real (12) llega como valor conocido.
    v = verificar("Paciente PAC-001 en cama 12.", ENTRADA, valores_identificadores=["12"])
    assert v.limpio


def test_documento_con_puntos_se_compara_como_un_numero():
    entrada = "Paciente PAC-001, ID-001, TA 120/80."
    v = verificar("Paciente PAC-001, C.C. 1.023.456.789.", entrada, valores_identificadores=["1023456789"])
    assert v.limpio


def test_cifra_que_no_es_ni_de_la_entrada_ni_identificador_sigue_marcada():
    v = verificar("Paciente PAC-001 en cama 99.", ENTRADA, valores_identificadores=["12"])
    assert any("99" in m for m in v.mensajes())
