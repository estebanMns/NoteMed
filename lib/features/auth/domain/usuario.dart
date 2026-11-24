/// Usuario con sesión iniciada y su rol.
library;

enum Rol {
  enfermera('Enfermera(o)'),
  jefe('Enfermera(o) jefe');

  const Rol(this.etiqueta);
  final String etiqueta;

  /// Solo el jefe de enfermería ve las métricas de validación.
  bool get veMetricas => this == jefe;
}

class Usuario {
  const Usuario({
    required this.usuario,
    required this.tarjetaProfesional,
    required this.rol,
  });

  final String usuario;

  /// Tarjeta profesional: llena el modal de firma (HU05).
  final String tarjetaProfesional;
  final Rol rol;
}

/// Inicio de sesión. La implementación real la provee el backend del
/// hospital; durante el desarrollo se usa `AutenticacionSimulada`.
abstract interface class ServicioAutenticacion {
  /// Devuelve el usuario o `null` si las credenciales no son válidas.
  Future<Usuario?> iniciarSesion(String usuario, String clave);
}
