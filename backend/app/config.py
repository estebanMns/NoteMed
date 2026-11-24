"""Configuración desde variables de entorno (12-factor). Nunca hay secretos
en el código: los valores reales llegan por el entorno o un .env local."""

from functools import lru_cache
from typing import Literal

from pydantic import Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="NOTEMED_", extra="ignore")

    entorno: Literal["desarrollo", "pruebas", "produccion"] = "desarrollo"
    database_url: str = "sqlite:///./notemed.db"

    jwt_secret: SecretStr = Field(default=SecretStr("cambiar-en-produccion-minimo-32-caracteres"))
    jwt_horas_expiracion: int = 8
    # Cierre por inactividad: si nadie usa la sesión durante este tiempo, se revoca.
    sesion_inactividad_minutos: float = 2.0

    llm_proveedor: Literal["simulado", "http"] = "simulado"
    llm_base_url: str = ""
    llm_api_key: SecretStr = SecretStr("")
    llm_modelo: str = ""
    llm_timeout_s: float = 20.0

    # El contrato con la app (sección 1) deja el token "cuando exista la
    # autenticación". Mientras la sección 2 no esté implementada, desactive
    # esta exigencia SOLO en desarrollo.
    ia_requiere_token: bool = True

    @model_validator(mode="after")
    def _validar(self) -> "Settings":
        if self.entorno == "produccion":
            secreto = self.jwt_secret.get_secret_value()
            if len(secreto) < 32 or secreto.startswith("cambiar"):
                raise ValueError(
                    "NOTEMED_JWT_SECRET debe tener al menos 32 caracteres aleatorios en producción"
                )
            if self.llm_proveedor == "http" and not (self.llm_base_url and self.llm_modelo):
                raise ValueError("Con llm_proveedor=http se requieren llm_base_url y llm_modelo")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
