"""Punto de entrada de la API. Crear la app con `create_app` permite inyectar
motor, modelo y configuración en las pruebas."""

from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
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

    # Formato de error acordado con la app (docs/contrato_api.md):
    # {"error": "mensaje para mostrar", "codigo": "identificador", ...}
    @app.exception_handler(ErrorDominio)
    async def _error_dominio(_request: Request, error: ErrorDominio) -> JSONResponse:
        if isinstance(error, NotaNoFirmable):
            status, codigo = 422, "nota_no_firmable"
            contenido = {
                "error": "La nota no cumple las reglas de firma.",
                "codigo": codigo,
                "motivos": error.motivos,
            }
        else:
            status, codigo = _CODIGOS.get(type(error), (400, "error_dominio"))
            contenido = {"error": str(error), "codigo": codigo}
        return JSONResponse(contenido, status_code=status)

    @app.exception_handler(RequestValidationError)
    async def _datos_invalidos(_request: Request, error: RequestValidationError) -> JSONResponse:
        detalle = [
            {"campo": ".".join(str(p) for p in e["loc"][1:]), "problema": e["msg"]} for e in error.errors()
        ]
        return JSONResponse(
            {"error": "Los datos enviados no son válidos.", "codigo": "datos_invalidos", "detalle": detalle},
            status_code=422,
        )

    @app.get("/health", tags=["sistema"])
    def health() -> dict[str, str]:
        return {"estado": "ok"}

    app.include_router(router)
    return app
