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

Usuarios de prueba (sintéticos): `enfermera1`, `enfermera2` o `jefe1`, clave
`notemed123`.

### Qué IA usa la app

Se elige al compilar; el menú principal muestra cuál está activa.

| Modo | Cómo | Para qué |
|---|---|---|
| IA simulada (por defecto) | `flutter run` | Desarrollo y pruebas sin backend ni internet. Arma la nota copiando los datos registrados; nunca inventa valores. |
| Servidor del hospital | `flutter run --dart-define=NOTEMED_API_URL=https://servidor/api` | Uso real. La clave del modelo de lenguaje vive en el backend. Contrato en [docs/contrato_api.md](docs/contrato_api.md). |
| Claude directo | `flutter run --dart-define=ANTHROPIC_API_KEY=...` | **Solo demostraciones.** La clave queda dentro de la app y se puede extraer. |

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

## Pendiente

- Backend del proyecto: generación con el modelo de lenguaje, autenticación
  real y almacenamiento definitivo de las notas firmadas (HL7 FHIR).
- En la app: enviar las notas firmadas al backend cuando exista ese servicio
  (el contrato propuesto está en la documentación).
- Validar con la UCI los ítems del PROM y el diccionario de siglas (Fase 1).
