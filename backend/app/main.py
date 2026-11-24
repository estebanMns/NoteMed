"""Punto de entrada de la API. Crear la app con `create_app` permite inyectar
motor, modelo y configuración en las pruebas."""

from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from sqlalchemy.engine import Engine

from app.api.rutas import router
from app.config import Settings, get_settings
from app.db.sesion import crear_motor, crear_tablas, fabrica_sesiones
from app.domain.errores import (
    ConflictoVersion,
    DatosNoSeguros,
    ErrorDominio,
    LlmNoDisponible,
    NoAutenticado,
    NoAutorizado,
    NotaNoEncontrada,
    NotaNoFirmable,
    PacienteExistente,
    PacienteNoEncontrado,
    TransicionInvalida,
)
from app.ia.modelo import ModeloLenguaje, crear_modelo

_CODIGOS: dict[type[ErrorDominio], tuple[int, str]] = {
    NotaNoEncontrada: (404, "nota_no_encontrada"),
    PacienteNoEncontrado: (404, "paciente_no_encontrado"),
    PacienteExistente: (409, "paciente_existente"),
    ConflictoVersion: (409, "conflicto_version"),
    TransicionInvalida: (409, "transicion_invalida"),
    NoAutorizado: (403, "no_autorizado"),
    NoAutenticado: (401, "no_autenticado"),
    DatosNoSeguros: (422, "datos_no_seguros"),
    LlmNoDisponible: (503, "ia_no_disponible"),
}


def create_app(
    settings: Settings | None = None,
    modelo: ModeloLenguaje | None = None,
    motor: Engine | None = None,
) -> FastAPI:
    settings = settings or get_settings()
    motor = motor or crear_motor(settings.database_url)
    if settings.entorno != "produccion":
        crear_tablas(motor)  # En producción el esquema lo aplica Alembic.

    app = FastAPI(
        title="NoteMed API", version="1.0.0", docs_url="/docs" if settings.entorno != "produccion" else None
    )
    app.state.settings = settings
    app.state.modelo = modelo or crear_modelo(settings)
    app.state.fabrica_sesiones = fabrica_sesiones(motor)

    @app.exception_handler(ErrorDominio)
    async def _error_dominio(_request: Request, error: ErrorDominio) -> JSONResponse:
        if isinstance(error, NotaNoFirmable):
            status, codigo = 422, "nota_no_firmable"
            contenido = {
                "error": codigo,
                "mensaje": "La nota no cumple las reglas de firma.",
                "motivos": error.motivos,
            }
        else:
            status, codigo = _CODIGOS.get(type(error), (400, "error_dominio"))
            contenido = {"error": codigo, "mensaje": str(error)}
        return JSONResponse(contenido, status_code=status)

    @app.get("/health", tags=["sistema"])
    def health() -> dict[str, str]:
        return {"estado": "ok"}

    app.include_router(router)
    return app
