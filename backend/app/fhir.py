"""Mapeo de la nota a un recurso FHIR R4 DocumentReference (subconjunto).
Base de la interoperabilidad con la HCE (Ley 2015 de 2020, PDF §2.2.8).

Solo se expone el seudónimo del paciente; no hay nombres en el recurso."""

from __future__ import annotations

import base64
from typing import Any

from app.db.modelos import NotaORM


def _iso(valor: Any) -> str | None:
    return valor.isoformat() if valor is not None else None


def documento_fhir(nota: NotaORM) -> dict[str, Any]:
    texto = nota.texto_final or nota.texto_borrador
    firmada = nota.estado == "firmada"
    recurso: dict[str, Any] = {
        "resourceType": "DocumentReference",
        "id": nota.id,
        "status": "current" if firmada else "preliminary",
        "docStatus": "final" if firmada else "preliminary",
        "type": {"text": f"Nota de enfermería: {nota.tipo}"},
        "subject": {"reference": f"Patient/{nota.paciente_id}"},
        "date": _iso(nota.firmada_en or nota.creada_en),
        "author": [{"display": nota.firmada_por or nota.creada_por}],
        "content": [
            {
                "attachment": {
                    "contentType": "text/plain; charset=utf-8",
                    "data": base64.b64encode(texto.encode("utf-8")).decode("ascii"),
                }
            }
        ],
    }
    if firmada:
        recurso["date"] = _iso(nota.firmada_en)
    return recurso
