# Contrato entre la app móvil y el backend de NoteMed

Este documento fija lo que la app móvil envía y espera del backend (API REST,
JSON, UTF-8, HTTPS). La sección 1 ya está implementada en la app
(`ServicioIARemoto`). Las secciones 2 y 3 son la propuesta para lo que falta;
se ajustan entre los dos antes de implementarlas.

URL base: se pasa al compilar la app con
`--dart-define=NOTEMED_API_URL=https://<servidor>/api`.

## 1. Generar borrador con IA (implementado en la app)

`POST /v1/ia/borradores`

La app **ya anonimizó** la solicitud: nombre → `PAC-###`, cédula → `ID-###`,
cama → `CAMA-###`. El backend nunca recibe datos personales en este endpoint
y no debe intentar reidentificarlos. La app restaura los datos reales al
recibir la respuesta.

Encabezados:

```
Content-Type: application/json
Authorization: Bearer <token>   (cuando exista la autenticación, sección 2)
```

Cuerpo:

```json
{
  "versionPrompts": "1.1.0",
  "sistema": "Eres un asistente de redacción para el personal de enfermería ... (instrucciones completas)",
  "solicitud": "Paciente: PAC-001, cédula ID-001, 67 años, CAMA-001\nSignos vitales: TA 120/80 mmHg, FC 84 lpm\nInfusiones: \n- Noradrenalina 0.1 mcg/kg/min a 8 mL/h\n..."
}
```

| Campo | Descripción |
|---|---|
| `versionPrompts` | Versión de las instrucciones de la app (`lib/features/notas/domain/prompts/`). Sirve para auditoría y MLOps. |
| `sistema` | Instrucciones (prompt de sistema) según el tipo de nota. El backend puede usarlas tal cual o reemplazarlas por su propia versión del prompt; en ese caso debe devolver el mismo formato de respuesta. |
| `solicitud` | Datos de la nota, anonimizados, una línea `Etiqueta: valor` por dato. |

Respuesta `200 OK`:

```json
{ "texto": "[S] Situación: PAC-001 en CAMA-001 ... \n[B] Antecedentes: ...\n[A] Evaluación: ...\n[R] Recomendación: ..." }
```

El texto debe conservar los códigos `PAC-###`, `ID-###` y `CAMA-###` tal
cual, y el formato que piden las instrucciones (por ejemplo, las cuatro
líneas SBAR de la nota de turno). La app verifica después los signos vitales
y las siglas.

Errores:

| Código | Cuerpo | Qué hace la app |
|---|---|---|
| `400`, `401`, `403`, `422` | `{"error": "mensaje"}` | Muestra el mensaje. No reintenta. |
| `429`, `5xx` | `{"error": "mensaje"}` | Guarda la solicitud en la cola y reintenta cuando haya red. |
| Sin respuesta en 90 s | — | Igual que `5xx`. |
| `200` con `texto` vacío | — | Muestra "El servidor devolvió una nota vacía." |

Formatos de respuesta esperados por tipo de nota (vienen en `sistema`):

| Nota | Formato |
|---|---|
| Entrega de turno | 4 líneas: `[S] Situación:`, `[B] Antecedentes:`, `[A] Evaluación:`, `[R] Recomendación:` |
| Evolución | 4 párrafos narrativos sin títulos |
| Traslado | Líneas `Traslado:`, `Motivo:`, `Condición al traslado:`, `Medio y acompañamiento:`, `Observaciones:` |
| Fallecimiento | Líneas `Fecha y hora del fallecimiento:`, `Certificado por:`, `Hallazgos:`, `Maniobras de reanimación:`, `Dispositivos invasivos presentes:`, `Cuidados post mortem:`, `Información y entrega:`, `Observaciones:`. Sin causa de muerte ni horas que no estén en la solicitud. |

## 2. Inicio de sesión (propuesta)

`POST /v1/auth/sesiones`

```json
{ "usuario": "enfermera1", "clave": "..." }
```

`200 OK`:

```json
{
  "token": "<JWT>",
  "expira": "2026-11-24T07:00:00-05:00",
  "usuario": {
    "usuario": "enfermera1",
    "tarjetaProfesional": "TP-10001",
    "rol": "enfermera"
  }
}
```

`rol`: `enfermera` o `jefe`. `401` si las credenciales no son válidas.

En la app basta con implementar `ServicioAutenticacion`
(`lib/features/auth/domain/usuario.dart`) y cambiar `autenticacionProvider`.

## 3. Enviar notas firmadas (propuesta, HL7 FHIR R4)

Cuando la nota está firmada, la app la envía para su almacenamiento definitivo
(Resolución 1995 de 1999; Ley 2015 de 2020). Este canal sí lleva datos
identificables del paciente porque es la historia clínica: solo por HTTPS y
con token.

`POST /v1/fhir/Bundle` (transacción) con:

- `Patient`: identificador (cédula), nombre, edad.
- `Observation`: signos vitales con códigos LOINC (TA sistólica 8480-6,
  diastólica 8462-4, FC 8867-4, FR 9279-1, SpO2 59408-5, temperatura 8310-5).
  Los códigos de las escalas (Braden, Downton, PROM) se definen con el equipo.
- `DocumentReference`: la nota firmada.

Ejemplo de `DocumentReference`:

```json
{
  "resourceType": "DocumentReference",
  "identifier": [{ "system": "urn:notemed:nota", "value": "<id local>" }],
  "status": "current",
  "docStatus": "final",
  "type": { "coding": [{ "system": "http://loinc.org", "code": "34746-8", "display": "Nurse Note" }] },
  "subject": { "reference": "Patient/<id>" },
  "date": "2026-11-20T07:05:00-05:00",
  "author": [{ "identifier": { "system": "urn:notemed:tarjeta-profesional", "value": "TP-10001" } }],
  "relatesTo": [{ "code": "appends", "target": { "reference": "DocumentReference/<nota aclarada>" } }],
  "content": [{
    "attachment": { "contentType": "text/plain; charset=utf-8", "data": "<texto en base64>" }
  }],
  "extension": [
    { "url": "urn:notemed:tipo-nota", "valueCode": "turno" },
    { "url": "urn:notemed:hash-sha256", "valueString": "<hash de la nota>" },
    { "url": "urn:notemed:version-prompts", "valueString": "1.1.0" }
  ]
}
```

`relatesTo` solo va en las notas aclaratorias. El backend debe rechazar
cambios a un `DocumentReference` con `docStatus = final` (la nota firmada es
inmutable) y puede comprobar el hash con el mismo cálculo de
`NotaClinica.calcularHash()`.

Respuesta: `200 OK` con el `Bundle` de respuesta FHIR. La app marcará la nota
como sincronizada; si falla por red, queda en la cola como las solicitudes de
IA.
