/// Formatos de fecha que se usan en las notas.
library;

String _dos(int n) => n.toString().padLeft(2, '0');

/// `dd/mm/aaaa hh:mm`
String formatearFechaHora(DateTime f) =>
    '${_dos(f.day)}/${_dos(f.month)}/${f.year} ${_dos(f.hour)}:${_dos(f.minute)}';
