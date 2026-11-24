/// TSK-28 · HU07: estado de la red del dispositivo.
library;

abstract interface class EstadoRed {
  Future<bool> conectado();

  /// Emite `true` cuando vuelve la red y `false` cuando se pierde.
  Stream<bool> get cambios;
}
