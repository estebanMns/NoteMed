"""Emite un token JWT de desarrollo o de pruebas. Se niega a operar en producción:
en producción los tokens los emite el proveedor de identidad del hospital.

Uso:
    python -m scripts.crear_token --sub ENF-01 --rol enfermero
"""

from __future__ import annotations

import argparse
import sys

from app.config import get_settings
from app.seguridad import crear_token


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Emite un token JWT de desarrollo.")
    parser.add_argument("--sub", required=True, help="Código de usuario, p. ej. ENF-01")
    parser.add_argument("--rol", required=True, choices=["enfermero", "supervisor"])
    args = parser.parse_args(argv)

    settings = get_settings()
    if settings.entorno == "produccion":
        print("No se emiten tokens de desarrollo en producción.", file=sys.stderr)
        return 1
    print(crear_token(args.sub, args.rol, settings))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
