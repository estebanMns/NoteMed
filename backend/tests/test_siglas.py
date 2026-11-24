"""Pruebas del filtro de siglas. Además comprueba que las listas Python y las
del archivo Dart sean idénticas, para que no se desincronicen."""

import re
from pathlib import Path

from app.siglas.filtro import (
    SIGLAS_PERMITIDAS,
    SIGLAS_PROHIBIDAS,
    FiltroSiglas,
    TipoHallazgo,
)

DART = Path(__file__).resolve().parents[2] / "lib" / "core" / "validacion" / "filtro_siglas.dart"


def _mapa_dart(nombre: str) -> dict[str, str]:
    texto = DART.read_text(encoding="utf-8")
    bloque = texto.split(f"const Map<String, String> {nombre} = {{", 1)[1].split("};", 1)[0]
    return dict(re.findall(r"'([^']+)': '([^']*)'", bloque))


def test_listas_coinciden_con_el_archivo_dart():
    assert _mapa_dart("siglasPermitidas") == SIGLAS_PERMITIDAS
    assert _mapa_dart("siglasProhibidas") == SIGLAS_PROHIBIDAS


def test_siglas_aprobadas_no_generan_hallazgo():
    assert FiltroSiglas().analizar("TA 120/80, FC 88, SpO2 96 %, IV") == []


def test_sigla_prohibida_con_sugerencia():
    hallazgos = FiltroSiglas().analizar("Metformina 500 mg QD")
    assert len(hallazgos) == 1
    assert hallazgos[0].sigla == "QD"
    assert hallazgos[0].tipo is TipoHallazgo.PROHIBIDA
    assert "diario" in hallazgos[0].mensaje


def test_sigla_desconocida():
    hallazgos = FiltroSiglas().analizar("Paciente con XQZ")
    assert [h.tipo for h in hallazgos] == [TipoHallazgo.DESCONOCIDA]


def test_codigos_de_anonimizacion_no_son_siglas():
    assert FiltroSiglas().analizar("PAC-001 en CAMA-001 con ID-001") == []


def test_palabras_comunes_no_son_siglas():
    assert FiltroSiglas().analizar("Paciente estable, sin cambios.") == []
