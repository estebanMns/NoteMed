"""Plantillas de prompt versionadas (PDF §3.2: los prompts se versionan como
código y se evalúan con casos sintéticos antes de cada entrega).

Cambiar un prompt exige subir PROMPT_VERSION; cada nota guarda la versión
usada para poder auditar y medir su calidad."""

from app.domain.nota import TipoNota

PROMPT_VERSION = "2026.11-v1"

_BASE = (
    "Eres asistente de documentación de enfermería en una UCI. Redacta una nota "
    "clínica en español usando SOLO los datos recibidos. Reglas: no inventes datos, "
    "diagnósticos ni valores; conserva los códigos PAC-###, CAMA-### e ID-### tal como "
    "aparecen; usa solo siglas aprobadas (TA, FC, FR, SpO2, IV, VO, UCI, SBAR); "
    "escribe en tercera persona, sin opiniones, de forma cronológica."
)

_TIPO = {
    TipoNota.RECIBO: (
        "Recibo y entrega de turno en formato SBAR (Situación, Antecedentes, Evaluación, Recomendación)."
    ),
    TipoNota.EVOLUCION: "Evolución de enfermería del turno.",
    TipoNota.TRASLADO: "Nota de traslado del paciente.",
    TipoNota.PROCEDIMIENTO: "Nota de procedimiento realizado.",
    TipoNota.FALLECIMIENTO: "Nota de fallecimiento, solo con hechos registrados.",
}


def instruccion_para(tipo: TipoNota) -> str:
    return f"{_BASE}\nTipo de nota: {_TIPO[tipo]}"
