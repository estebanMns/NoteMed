# NoteMed · Backend y componente de IA

API REST (FastAPI) que recibe datos clínicos ya capturados en la app, los
seudonimiza, genera un **borrador** de nota con un modelo de lenguaje, verifica
el resultado contra los datos de entrada y guarda la nota con su ciclo de
revisión y firma. Corresponde a la parte de backend e IA del PDF (§3.4).

## Decisiones principales

| Tema | Decisión | Por qué |
|---|---|---|
| Lenguaje | Python 3.13, FastAPI, Pydantic v2 | Validación estricta de contratos y documentación OpenAPI |
| Persistencia | SQLAlchemy 2 · PostgreSQL 16 (producción) · SQLite (pruebas) | Integridad referencial y ACID (Res. 1995/1999) |
| Esquema | Alembic | Cambios de BD versionados; producción nunca usa `create_all` |
| Identidad | Usuario y clave (scrypt) → JWT con rol (`enfermera` o `jefe`). Sin registro público: lo da de alta una persona administradora | La clave nunca se guarda en claro; el token no lleva nombres |
| IA | Puerto `ModeloLenguaje` + adaptadores (`simulado`, `http` compatible con chat completions) | Cambiar de proveedor no toca la lógica clínica |
| Privacidad | Seudonimización antes del modelo + barrera que aborta si queda un dato identificable | Ley 1581; defensa en profundidad |
| Verificación | Cadena de verificación determinista: cifras y códigos deben existir en la entrada; filtro de siglas | Detecta alucinaciones (PDF §2.2.5) |
| Firma | Solo con revisión previa, sin siglas prohibidas ni valores no sustentados | Ley 911 art. 38; Human-in-the-Loop |
| Sincronización | `id` (UUID) generado por el cliente; reenviar devuelve la misma nota | Funciona con la cola offline de la app |
| Concurrencia | `version` obligatoria; `UPDATE ... WHERE version = :v` | Dos dispositivos no se pisan |
| Auditoría | Tabla `eventos_auditoria` de solo inserción | Trazabilidad de cada acción |
| Interoperabilidad | Export FHIR R4 `DocumentReference` (subconjunto) | Ley 2015 de 2020 |

## Estructura

```
backend/
├── app/
│   ├── main.py            fábrica de la app y manejo de errores
│   ├── config.py          configuración por variables de entorno
│   ├── seguridad.py       JWT y roles
│   ├── fhir.py            mapeo a DocumentReference
│   ├── domain/            reglas puras: estados de nota, errores de dominio
│   ├── privacidad/        anonimizador (Ley 1581)
│   ├── siglas/            filtro de siglas (Ley 911)
│   ├── ia/                prompts versionados, modelo, verificación, orquestador
│   ├── servicios/         casos de uso con autorización, concurrencia y auditoría
│   ├── db/                modelos relacionales y sesiones
│   └── api/               esquemas, dependencias y rutas
├── alembic/               migraciones
├── tests/                 pruebas unitarias y de la API
├── scripts/crear_token.py token de desarrollo
├── Dockerfile · docker-compose.yml
└── requirements.txt
```

## Endpoints (v1)

| Método | Ruta | Rol | Descripción |
|---|---|---|---|
| POST | `/v1/auth/sesiones` | público | Usuario y clave → JWT (contrato sección 2) |
| POST | `/v1/pacientes` | enfermera | Registra un paciente por seudónimo (`PAC-###`) |
| GET | `/v1/pacientes/{id}/notas` | autor / jefe | Notas del paciente |
| POST | `/v1/notas/borradores` | enfermera | Genera el borrador con IA (201; 200 si ya existía) |
| GET | `/v1/notas/{id}` | autor / jefe | Detalle, texto y hallazgos |
| PUT | `/v1/notas/{id}/revision` | autor | Guarda la revisión (requiere `version`) |
| POST | `/v1/notas/{id}/firma` | autor | Firma (requiere `version`) |
| GET | `/v1/notas/{id}/fhir` | autor / jefe | Documento FHIR |
| GET | `/v1/metricas/borradores` | jefe | Aceptación y tasa de edición |
| GET | `/health` | público | Estado del servicio |

Errores con cuerpo `{"error": "...", "mensaje": "...", "motivos": [...]}`:
401 sin token válido · 403 sin permiso · 404 · 409 conflicto de versión o estado · 422 nota no firmable o datos no seguros · 503 la IA no respondió.

## Personal y roles

- **`enfermera`:** registra pacientes, genera borradores, revisa y firma sus propias notas.
- **`jefe`:** consulta las métricas de validación (`GET /v1/metricas/borradores`). No firma notas ajenas.

Los usuarios los da de alta una persona administradora (no hay registro público):

```bash
NOTEMED_DATABASE_URL=sqlite:///./notemed.db ./.venv/bin/python -m scripts.crear_usuario \
  --usuario enfermera1 --tarjeta TP-10001 --rol enfermera
```

La clave se pide por consola (mínimo 10 caracteres).

## Puesta en marcha (desarrollo)

```bash
cd backend
python3.13 -m venv .venv && ./.venv/bin/pip install -r requirements.txt
cp .env.example .env              # ajuste valores; no suba .env
./.venv/bin/alembic upgrade head  # crea el esquema
./.venv/bin/uvicorn app.main:create_app --factory --reload
./.venv/bin/python -m scripts.crear_token --sub enfermera1 --rol enfermera
```

Con Docker: `docker compose up --build` (define `POSTGRES_PASSWORD` en `.env`).

## Calidad

```bash
./.venv/bin/pytest            # pruebas
./.venv/bin/ruff check .      # lint
./.venv/bin/mypy app          # tipos
```

La prueba `tests/test_siglas.py` compara las listas de siglas con
`lib/core/validacion/filtro_siglas.dart`: si cambia una, debe cambiar la otra.

## Pendiente antes de producción

- Integrar el proveedor de identidad del hospital (hoy el token lo emite `scripts/crear_token.py`, solo en desarrollo).
- Cifrado de campo para los textos clínicos (hoy solo se protege la base de datos a nivel de infraestructura).
- Limitación de tasa (rate limiting) y registro de accesos a nivel de proxy.
- Probar el adaptador `http` contra el proveedor real de IA con datos sintéticos; hoy solo está probado con respuestas simuladas.
- Revisión de la lista de siglas y de los prompts por el comité de historias clínicas.
