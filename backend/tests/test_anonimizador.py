import pytest

from app.privacidad.anonimizador import Anonimizador, normalizar


def test_nombre_documento_y_cama():
    salida = Anonimizador().anonimizar(
        "Paciente María Pérez, C.C. 1.023.456.789, en cama 12.", ["María Pérez"]
    )
    assert salida == "Paciente PAC-001, C.C. ID-001, en CAMA-001."


def test_documento_sin_puntos_y_habitaciones():
    salida = Anonimizador().anonimizar("Documento 52345678, habitación 304B, hab. 7")
    assert salida == "Documento ID-001, CAMA-001, CAMA-002"


def test_cama_con_no_y_numero_sign():
    assert Anonimizador().anonimizar("Cama No. 5 y cama N° 6") == "CAMA-001 y CAMA-002"


def test_tratamiento_de_cortesia_sin_lista():
    salida = Anonimizador().anonimizar("Entrega: don Pedro Salas, Hab. 12, estable.")
    assert "Pedro" not in salida and "Salas" not in salida
    assert "PAC-001" in salida


def test_mismo_dato_mismo_codigo_en_una_instancia():
    anon = Anonimizador()
    uno = anon.anonimizar("Ana Torres", ["Ana Torres"])
    dos = anon.anonimizar("ANA TORRES ingresó", ["Ana Torres"])
    assert uno == "PAC-001"
    assert dos.startswith("PAC-001")


def test_codigos_ya_anonimizados_no_cuentan_como_datos_personales():
    assert not Anonimizador.contiene_datos_personales("Paciente PAC-001, CAMA-001, ID-001")


def test_detecta_datos_que_quedan():
    assert Anonimizador.contiene_datos_personales("Paciente en cama 3")
    assert Anonimizador.contiene_datos_personales("Documento 1023456789")
    assert Anonimizador.contiene_datos_personales("Ana llegó", nombres=["Ana Torres"])


def test_tabla_de_reidentificacion_es_solo_lectura():
    anon = Anonimizador()
    anon.anonimizar("Ana Torres", ["Ana Torres"])
    tabla = anon.tabla_reidentificacion
    assert tabla == {"PAC|ana torres": "PAC-001"}
    with pytest.raises(TypeError):
        tabla["x"] = "y"  # type: ignore[index]


def test_normalizar_quita_tildes_y_mayusculas():
    assert normalizar("  MARÍA   Pérez ") == "maria perez"
