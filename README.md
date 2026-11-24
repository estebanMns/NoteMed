# NoteMed

Aplicación móvil (Flutter) que ayuda al personal de enfermería de la UCI del
Hospital Universitario Departamental de Nariño a redactar las notas de
enfermería. La enfermera registra datos estructurados (signos vitales,
infusiones, escalas de Braden y Downton, PROM, procedimientos) y la
inteligencia artificial redacta un **borrador**. La enfermera lo revisa, lo
corrige y lo **firma**: ninguna nota queda definitiva sin su firma
(Human-in-the-Loop).

Proyecto de grado de Ingeniería de Software, Universidad Cooperativa de
Colombia, campus Pasto (2026). Aplicación móvil: Evelin Dayanna Pulsara
Madroñero. Backend y componente de IA: Esteban Giovanny Meneses Paz.

> Durante el desarrollo se usan **solo datos sintéticos**. No registre datos
> de pacientes reales.

## Qué hace

| Función | Detalle |
|---|---|
| Inicio de sesión y roles | Enfermera(o) y enfermera(o) jefe. La tarjeta profesional llena la firma. |
| Pacientes | Registro, signos vitales con validación de rangos, infusiones, procedimientos invasivos. |
| Valoración | Escalas de Braden y Downton con recomendaciones; PROM (dolor, disnea, ansiedad, sed, malestar, descanso). |
| Notas con IA | Entrega de turno (SBAR), evolución, traslado y fallecimiento. |
| Privacidad | Nombre, cédula y cama se reemplazan por códigos antes de enviar a la IA y se restauran en el celular (Ley 1581 de 2012). |
| Verificación | El borrador se revisa contra los signos registrados y el diccionario de siglas aprobadas (Ley 911 de 2004). Las discrepancias bloquean la firma. |
| Firma | Firma con el dedo y tarjeta profesional. La nota firmada queda inmutable (hash SHA-256); las correcciones van en una nota aclaratoria. |
| Sin internet | Base de datos local cifrada (SQLCipher). Si la IA del servidor no responde, la solicitud queda en cola y se procesa al volver la red. |
| Métricas | Tasa de aceptación y de edición de los borradores y tiempo de revisión, exportables en CSV (solo jefe). |

## Cómo ejecutar

Requisitos: Flutter 3.50 o superior.

```bash
flutter pub get
flutter run
```

Usuarios de prueba sin servidor (sintéticos): `enfermera1`, `enfermera2` o `jefe1`,
clave `notemed123`. Con el servidor, los usuarios los da de alta la jefa o el jefe.

### Qué IA usa la app

Se elige al compilar; el menú principal muestra cuál está activa.

| Modo | Cómo | Para qué |
|---|---|---|
| IA simulada (por defecto) | `flutter run` | Desarrollo y pruebas sin backend ni internet. Arma la nota copiando los datos registrados; nunca inventa valores. |
| Servidor del hospital | `flutter run --dart-define=NOTEMED_API_URL=https://servidor/api` | Uso real. La clave del modelo de lenguaje vive en el backend. Contrato en [docs/contrato_api.md](docs/contrato_api.md). |
| Claude directo | `flutter run --dart-define=ANTHROPIC_API_KEY=...` | **Solo demostraciones.** La clave queda dentro de la app y se puede extraer. |

## Backend y componente de IA

El servidor está en [`backend/`](backend/README.md) (FastAPI, PostgreSQL,
Alembic). Implementa la sección 1 de [docs/contrato_api.md](docs/contrato_api.md)
(`POST /v1/ia/borradores`) y la base de notas, firma y auditoría.

```bash
cd backend
python3.13 -m venv .venv && ./.venv/bin/pip install -r requirements.txt
NOTEMED_DATABASE_URL=sqlite:///./notemed.db ./.venv/bin/alembic upgrade head
NOTEMED_DATABASE_URL=sqlite:///./notemed.db NOTEMED_ENTORNO=desarrollo \
  ./.venv/bin/uvicorn app.main:create_app --factory --port 8000
```

Las secciones 2 (inicio de sesión) y 3 (envío FHIR) del contrato están
pendientes de acuerdo entre ambos equipos.

## Pruebas

```bash
flutter analyze
flutter test                                    # unitarias y de widgets
flutter test integration_test -d <dispositivo>  # en celular o emulador
```

`test/arquitectura_test.dart` falla si una capa importa algo que no le
corresponde (por ejemplo, si el dominio importa Flutter o la base de datos).

La prueba de integración abre la base cifrada en el dispositivo, comprueba que
el archivo no sea legible como SQLite normal y recorre el flujo completo:
login → paciente → signos → borrador → firma.

## Arquitectura

Arquitectura Limpia por funcionalidad (`domain` → `application` → `data` /
`presentation`), Riverpod para inyección de dependencias y estado, go_router
para la navegación. Detalle en [docs/arquitectura.md](docs/arquitectura.md).

```
lib/
  app/              providers (inyección), rutas, tema
  core/             base de datos cifrada, red, utilidades
  features/
    auth/           sesión y roles
    inicio/         menú principal
    pacientes/      paciente, signos vitales, infusiones, procedimientos
    valoracion/     Braden, Downton, PROM
    notas/          notas, prompts, IA, borrador, firma, aclaraciones
    privacidad/     anonimización (Ley 1581)
    validacion/     diccionario de siglas y verificación de signos (Ley 911)
    sincronizacion/ cola de solicitudes sin red
    metricas/       métricas de validación
```

## Trabajo en equipo

- `main`: versión estable. Se integra por Pull Request.
- `dev-evelin`: aplicación móvil. `dev-esteban`: backend y componente de IA.
- La app y el backend se comunican según [docs/contrato_api.md](docs/contrato_api.md).

## Pendientes para la app móvil (Evelin)

El backend ya tiene inicio de sesión con JWT, cierre de sesión por inactividad
y administración del personal por parte de la jefa o el jefe. Para que la app
los use, falta lo siguiente. Los contratos exactos están en
[docs/contrato_api.md](docs/contrato_api.md) y en `backend/README.md`.

### 1. Inicio de sesión real

- Implementar un `ServicioAutenticacion` remoto que llame a
  `POST /v1/auth/sesiones` con `{"usuario", "clave"}` y guarde `token`, `expira`
  y `usuario` (incluido `rol`: `enfermera` o `jefe`).
- Cambiar `autenticacionProvider` para usar ese servicio. Los usuarios
  `enfermera1`, `enfermera2` y `jefe1` quedan solo para desarrollo sin servidor.
- Guardar el token en almacenamiento seguro (por ejemplo `flutter_secure_storage`),
  no en memoria ni en la base local sin cifrar.

### 2. Enviar el token en cada petición

- `ServicioIARemoto` debe enviar `Authorization: Bearer <token>` en
  `POST /v1/ia/borradores`. Hoy no lo envía y el servidor responde `401`
  (el token es obligatorio por defecto).

### 3. Manejar el cierre de sesión por inactividad

El servidor cierra la sesión si pasan **2 minutos sin actividad**. Cualquier
`401` con estos códigos debe llevar a la pantalla de inicio de sesión y borrar
el token guardado:

| `codigo` | Qué pasó |
|---|---|
| `sesion_inactiva` | Se cerró por 2 minutos sin actividad |
| `sesion_cerrada` | La sesión se cerró manualmente o el usuario fue dado de baja |
| `sesion_vencida` | Se alcanzó el tope de horas de la sesión |
| `sesion_invalida` / `no_autenticado` | Token ausente, mal firmado o sin identidad |

- Además, la app debe tener su propio temporizador de 2 minutos: al cumplirse,
  bloquear la pantalla y pedir la clave sin esperar a la siguiente petición.
  Cualquier toque o desplazamiento reinicia el temporizador.
- Al cerrar sesión, llamar a `POST /v1/auth/cierre` (responde `204`) antes de
  borrar el token.
- Al iniciar sesión con clave incorrecta, el servidor responde `401` con
  `codigo: "credenciales_invalidas"`. Mostrar el mensaje sin indicar si falló
  el usuario o la clave.

### 4. Pantalla de administración del personal (solo jefe)

| Acción | Llamada | Respuesta esperada |
|---|---|---|
| Listar | `GET /v1/usuarios` (`?incluir_inactivos=true` para ver bajas) | `200` lista de `{usuario, tarjetaProfesional, rol, activo}` |
| Agregar | `POST /v1/usuarios` con `{usuario, clave, tarjetaProfesional}` | `201`; `409 usuario_existente` si ya existe |
| Editar | `PUT /v1/usuarios/{usuario}` con `tarjetaProfesional` y/o `clave` | `200`; cambiar la clave cierra sus sesiones |
| Dar de baja | `DELETE /v1/usuarios/{usuario}` | `204`; la cuenta queda inactiva |

- Usuario: 3 a 64 caracteres, solo minúsculas, números, `.`, `_` o `-`.
- Clave: mínimo 10 caracteres.
- Validación fallida: `422` con `codigo: "datos_invalidos"` y `detalle` por campo.
- Una enfermera que llame a estas rutas recibe `403`. La pantalla solo debe
  mostrarse al rol `jefe`, y el servidor igual lo verifica.
- El jefe no puede darse de baja a sí mismo (`403`).

### 5. Sin cambios de contrato pendientes en la app

- La IA y los errores siguen el formato `{"error": "mensaje", "codigo": "..."}`.
- La sección 3 del contrato (envío FHIR) sigue pendiente de acordar.

## Pendiente

- Backend del proyecto: generación con el modelo de lenguaje, autenticación
  real y almacenamiento definitivo de las notas firmadas (HL7 FHIR).
- En la app: enviar las notas firmadas al backend cuando exista ese servicio
  (el contrato propuesto está en la documentación).
- Validar con la UCI los ítems del PROM y el diccionario de siglas (Fase 1).
