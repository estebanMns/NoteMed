/// Valor que avisa cuando cambia. Es Dart puro para que las capas de dominio
/// y aplicación no dependan de Flutter (reemplaza a `ValueNotifier`).
library;

import 'dart:async';

class ValorObservable<T> {
  ValorObservable(this._valor);

  T _valor;
  final _cambios = StreamController<T>.broadcast();

  T get value => _valor;

  set value(T nuevo) {
    if (nuevo == _valor) return;
    _valor = nuevo;
    _cambios.add(nuevo);
  }

  /// Emite cada valor nuevo (no repite el actual al suscribirse).
  Stream<T> get cambios => _cambios.stream;

  Future<void> cerrar() => _cambios.close();
}
