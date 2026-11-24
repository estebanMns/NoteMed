import pytest

from app.domain.errores import TransicionInvalida
from app.domain.nota import EstadoNota, revisar, validar_firma
from app.siglas.filtro import FiltroSiglas


def test_firma_exige_revision():
    motivos = validar_firma("TA 120/80", EstadoNota.BORRADOR, "ENF-01", FiltroSiglas())
    assert "La nota debe revisarse antes de firmar." in motivos


def test_firma_rechaza_texto_vacio_y_firmante_vacio():
    motivos = validar_firma("   ", EstadoNota.REVISADA, " ", FiltroSiglas())
    assert "La nota está vacía." in motivos
    assert "Falta el firmante." in motivos


def test_firma_valida():
    assert validar_firma("TA 120/80", EstadoNota.REVISADA, "ENF-01", FiltroSiglas()) == []


def test_firmada_no_se_revisa():
    with pytest.raises(TransicionInvalida):
        revisar(EstadoNota.FIRMADA, "otro texto")


def test_revisar_pasa_a_revisada():
    assert revisar(EstadoNota.BORRADOR, "texto").estado is EstadoNota.REVISADA
