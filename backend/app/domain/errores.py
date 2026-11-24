"""Errores de dominio. La API los traduce a códigos HTTP; el dominio no sabe
nada de HTTP."""


class ErrorDominio(Exception):
    """Base de los errores de reglas de negocio."""


class NotaNoEncontrada(ErrorDominio):
    pass


class PacienteNoEncontrado(ErrorDominio):
    pass


class ConflictoVersion(ErrorDominio):
    """La nota cambió desde que el cliente la leyó (control optimista)."""


class TransicionInvalida(ErrorDominio):
    """Operación no permitida en el estado actual de la nota."""


class NoAutorizado(ErrorDominio):
    """El actor no es el autor de la nota o no tiene el rol requerido."""


class NotaNoFirmable(ErrorDominio):
    def __init__(self, motivos: list[str]):
        super().__init__("; ".join(motivos))
        self.motivos = motivos


class LlmNoDisponible(ErrorDominio):
    """El proveedor de IA falló. La enfermera puede seguir redactando a mano."""


class DatosNoSeguros(ErrorDominio):
    """Quedan datos identificables en la entrada; no se llama al modelo (Ley 1581)."""


class PacienteExistente(ErrorDominio):
    pass


class NoAutenticado(ErrorDominio):
    """Token ausente, inválido o vencido."""
