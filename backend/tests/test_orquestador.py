import pytest

from app.domain.errores import DatosNoSeguros
from app.domain.nota import TipoNota
from app.ia.orquestador import GeneradorBorrador, reidentificar
from app.privacidad.anonimizador import Anonimizador
from tests.conftest import ModeloEspia


def test_reidentificar_restaura_nombre_y_cama():
    anon = Anonimizador()
    entrada = anon.anonimizar("Ana Torres, cama 12", nombres_conocidos=["Ana Torres"])
    assert entrada == "PAC-001, CAMA-001"
    assert reidentificar("PAC-001 en CAMA-001 estable.", anon, ["Ana Torres"]) == (
        "Ana Torres en cama 12 estable."
    )


def test_reidentificar_no_confunde_codigos_con_prefijo_comun():
    anon = Anonimizador()
    anon.anonimizar("cama 1 y cama 2")
    assert reidentificar("CAMA-001 y CAMA-002", anon, []) == "cama 1 y cama 2"


def test_borrador_con_cifra_inventada_queda_marcado():
    modelo = ModeloEspia("Paciente PAC-001 con TA 190/110.")
    borrador = GeneradorBorrador(modelo).ejecutar(
        TipoNota.EVOLUCION, "Paciente Ana Torres, TA 120/80.", ["Ana Torres"]
    )
    assert not borrador.verificacion.limpio
    assert any("190" in m for m in borrador.verificacion.mensajes())


def test_datos_no_seguros_impiden_llamar_al_modelo(monkeypatch):
    modelo = ModeloEspia()
    monkeypatch.setattr(Anonimizador, "anonimizar", lambda self, texto, nombres_conocidos=(): texto)
    with pytest.raises(DatosNoSeguros):
        GeneradorBorrador(modelo).ejecutar(TipoNota.EVOLUCION, "Ana Torres estable", ["Ana Torres"])
    assert modelo.contextos == []
