"""Filtro de siglas (Ley 911 de 2004, art. 38). Espejo de
lib/core/validacion/filtro_siglas.dart. tests/test_siglas.py compara estas
listas con el archivo Dart para que no se desincronicen."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum

import regex

SIGLAS_PERMITIDAS: dict[str, str] = {
    "TA": "tensión arterial",
    "FC": "frecuencia cardiaca",
    "FR": "frecuencia respiratoria",
    "SpO2": "saturación de oxígeno",
    "SatO2": "saturación de oxígeno",
    "IV": "intravenoso",
    "VO": "vía oral",
    "IM": "intramuscular",
    "SNG": "sonda nasogástrica",
    "UCI": "unidad de cuidados intensivos",
    "EKG": "electrocardiograma",
    "ECG": "electrocardiograma",
    "HTA": "hipertensión arterial",
    "EPOC": "enfermedad pulmonar obstructiva crónica",
    "VIH": "virus de inmunodeficiencia humana",
    "PVC": "presión venosa central",
    "TAM": "tensión arterial media",
    "IMC": "índice de masa corporal",
    "SBAR": "situación, antecedentes, evaluación, recomendación",
}

SIGLAS_PROHIBIDAS: dict[str, str] = {
    "SC": "subcutáneo (o superficie corporal: especifique)",
    "SL": "sublingual",
    "QD": "diario",
    "QOD": "interdiario",
    "HS": "al acostarse",
    "IU": "unidades internacionales",
    "UI": "unidades internacionales",
    "IT": "intratecal",
    "AD": "oído derecho",
    "AI": "oído izquierdo",
    "OD": "ojo derecho",
    "OI": "ojo izquierdo",
    "BID": "cada 12 horas",
    "TID": "cada 8 horas",
    "QID": "cada 6 horas",
    "PRN": "si es necesario",
    "NPO": "nada por vía oral",
    "DM": "diabetes mellitus",
    "IAM": "infarto agudo de miocardio",
    "ICC": "insuficiencia cardiaca congestiva",
    "IRA": "insuficiencia renal aguda (o infección respiratoria aguda: especifique)",
    "MgSO4": "sulfato de magnesio",
    "MS": "sulfato de morfina (o sulfato de magnesio: especifique)",
}

# Token candidato: empieza en mayúscula, 2 a 6 caracteres, no es código
# de anonimización (PAC-001) ni parte de una palabra.
_TOKEN = regex.compile(r"(?<![\p{L}\p{N}])(\p{Lu}[\p{L}\p{N}]{1,5})(?![\p{L}\p{N}])(?!-\d)")
_TIENE_OTRA_MAYUSCULA = regex.compile(r"^\p{Lu}.*\p{Lu}")


class TipoHallazgo(StrEnum):
    PROHIBIDA = "prohibida"
    DESCONOCIDA = "desconocida"


@dataclass(frozen=True)
class Hallazgo:
    sigla: str
    inicio: int
    fin: int
    tipo: TipoHallazgo
    sugerencia: str | None = None

    @property
    def mensaje(self) -> str:
        if self.tipo is TipoHallazgo.PROHIBIDA:
            return (
                f'La sigla "{self.sigla}" no está permitida. '
                f"Escriba: {self.sugerencia or 'el término completo'}."
            )
        return f'La sigla "{self.sigla}" no está en la lista aprobada. Escriba el término completo.'


class FiltroSiglas:
    def __init__(
        self,
        permitidas: dict[str, str] | None = None,
        prohibidas: dict[str, str] | None = None,
    ) -> None:
        self.permitidas = SIGLAS_PERMITIDAS if permitidas is None else permitidas
        self.prohibidas = SIGLAS_PROHIBIDAS if prohibidas is None else prohibidas

    def _es_candidata(self, token: str) -> bool:
        return (
            bool(_TIENE_OTRA_MAYUSCULA.match(token)) or token in self.permitidas or token in self.prohibidas
        )

    def analizar(self, texto: str) -> list[Hallazgo]:
        hallazgos: list[Hallazgo] = []
        for m in _TOKEN.finditer(texto):
            token = m.group(1)
            if token in self.permitidas or not self._es_candidata(token):
                continue
            sugerencia = self.prohibidas.get(token)
            hallazgos.append(
                Hallazgo(
                    sigla=token,
                    inicio=m.start(),
                    fin=m.end(),
                    tipo=TipoHallazgo.PROHIBIDA if sugerencia else TipoHallazgo.DESCONOCIDA,
                    sugerencia=sugerencia,
                )
            )
        return hallazgos
