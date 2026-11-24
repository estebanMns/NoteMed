# NoteMed

Aplicación Flutter para apoyar la redacción de notas de enfermería en la UCI del
Hospital Universitario Departamental de Nariño. La IA generativa produce un
**borrador**; la enfermera lo revisa, lo edita y lo firma (Human-in-the-Loop).

Proyecto de grado — Ingeniería de Software, Universidad Cooperativa de Colombia (Pasto).

## Estado actual

| Módulo | Estado |
|---|---|
| Escala de Braden (HU02) | Implementada (dominio + pantalla) |
| Plantilla SBAR y balance de líquidos (HU03) | Implementada (dominio + pantalla) |
| Anonimización Ley 1581 (HU08) | Implementada (dominio, sin conectar a pantallas) |
| Filtro de siglas Ley 911 (HU06) | Implementada (dominio, sin conectar a pantallas) |
| Escala de Downton | Dominio implementado, sin pantalla |
| Borrador con IA y firma (casos de uso) | Implementado en el backend (`backend/`); la app Flutter aún no lo consume |
| Persistencia offline cifrada (SQLite/SQLCipher) | Pendiente |
| API REST, FHIR y auditoría (backend) | Implementado en `backend/`; falta integrar identidad del hospital |
| Métricas (aceptación, edición, SUS) | Pendiente |

## Arquitectura

Arquitectura Limpia organizada por funcionalidad. La regla de dependencia va
hacia el dominio: `presentation → domain ← data`. El dominio es Dart puro.

```
lib/
├── main.dart
├── core/                          # transversal
│   ├── privacidad/anonimizador.dart   # seudonimización (Ley 1581)
│   └── validacion/filtro_siglas.dart  # siglas aprobadas/prohibidas (Ley 911)
└── features/
    ├── valoracion/
    │   ├── domain/     braden_escala, downton_escala, balance_liquidos
    │   └── presentation/ braden_screen
    └── notas/
        ├── domain/     nota_clinica, llm_gateway (puerto), casos_de_uso,
        │               sbar_plantilla
        ├── data/       llm_simulado (adaptador de prueba)
        └── presentation/ entrega_turno_screen, sbar_form
test/                  # espeja lib/ y prueba la lógica de dominio
```

Flujo de una nota con IA:

1. Los datos se anonimizan (`Anonimizador`): nombres → `PAC-###`, cédulas → `ID-###`, camas → `CAMA-###`.
2. Una barrera verifica que no quede ningún dato identificable antes de llamar al modelo.
3. El modelo (detrás de `LlmGateway`) devuelve el borrador.
4. Se re-identifica localmente y se pasa el filtro de siglas.
5. La enfermera revisa (`borrador → revisada`) y firma (`FirmarNota`), que rechaza siglas prohibidas o texto vacío.

## Backend

La API y el componente de IA están en [`backend/`](backend/README.md) (FastAPI, PostgreSQL, Alembic).

## Desarrollo

Requisitos: Flutter estable con Dart `^3.12.2`.

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Solo se usan datos sintéticos durante el desarrollo.
