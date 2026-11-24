"""Da de alta a una persona del personal. La clave se pide por consola (no
queda en el historial de comandos).

Uso:
    NOTEMED_DATABASE_URL=... python -m scripts.crear_usuario \
        --usuario enfermera1 --tarjeta TP-10001 --rol enfermera
"""

from __future__ import annotations

import argparse
import getpass
import sys

from app.config import get_settings
from app.db.sesion import crear_motor, fabrica_sesiones
from app.domain.errores import UsuarioExistente
from app.servicios.autenticacion import ROLES_VALIDOS, ServicioAutenticacion


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Crea un usuario del personal.")
    parser.add_argument("--usuario", required=True)
    parser.add_argument("--tarjeta", required=True, help="Tarjeta profesional, p. ej. TP-10001")
    parser.add_argument("--rol", required=True, choices=ROLES_VALIDOS)
    args = parser.parse_args(argv)

    clave = getpass.getpass("Clave (mínimo 10 caracteres): ")
    if len(clave) < 10:
        print("La clave debe tener al menos 10 caracteres.", file=sys.stderr)
        return 1
    if clave != getpass.getpass("Repita la clave: "):
        print("Las claves no coinciden.", file=sys.stderr)
        return 1

    settings = get_settings()
    sesion = fabrica_sesiones(crear_motor(settings.database_url))()
    try:
        ServicioAutenticacion(sesion, settings).crear_usuario(args.usuario, clave, args.tarjeta, args.rol)
    except UsuarioExistente as error:
        print(str(error), file=sys.stderr)
        return 1
    finally:
        sesion.close()
    print(f"Usuario {args.usuario} ({args.rol}) creado.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
