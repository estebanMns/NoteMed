/// TSK-01 · HU01: datos básicos del paciente (nombre, cédula, edad y
/// cama/camilla).
library;

class Paciente {
  const Paciente({
    this.id,
    required this.nombre,
    required this.cedula,
    required this.edad,
    required this.cama,
  });

  /// Identificador en la base de datos local. Es `null` antes de guardar.
  final int? id;
  final String nombre;
  final String cedula;
  final int edad;

  /// Número de cama o camilla, por ejemplo `12`, `12B` o `B-3`.
  final String cama;

  static const int edadMaxima = 120;

  static String? validarNombre(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'El nombre es obligatorio';
    if (!RegExp(r"^[\p{L}][\p{L} .'-]*$", unicode: true).hasMatch(t)) {
      return 'El nombre solo puede tener letras';
    }
    if (t.split(RegExp(r'\s+')).length < 2) {
      return 'Escriba nombre y apellido';
    }
    return null;
  }

  static String? validarCedula(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'La cédula es obligatoria';
    if (!RegExp(r'^\d{1,3}(\.\d{3}){1,3}$|^\d+$').hasMatch(t)) {
      return 'La cédula solo puede tener números';
    }
    final digitos = t.replaceAll('.', '');
    if (digitos.length < 6 || digitos.length > 10) {
      return 'La cédula debe tener entre 6 y 10 dígitos';
    }
    return null;
  }

  static String? validarEdad(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'La edad es obligatoria';
    final n = int.tryParse(t);
    if (n == null) return 'La edad debe ser un número entero';
    if (n < 0 || n > edadMaxima) {
      return 'La edad debe estar entre 0 y $edadMaxima';
    }
    return null;
  }

  static String? validarCama(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'La cama o camilla es obligatoria';
    if (!RegExp(r'^[A-Za-z]?-?\d{1,4}[A-Za-z]?$').hasMatch(t)) {
      return 'Use un número de cama, por ejemplo 12, 12B o B-3';
    }
    return null;
  }

  /// Errores de todos los campos. Vacía si el paciente es válido.
  List<String> validar() => [
    validarNombre(nombre),
    validarCedula(cedula),
    validarEdad('$edad'),
    validarCama(cama),
  ].whereType<String>().toList();

  bool get esValido => validar().isEmpty;

  Paciente conId(int id) =>
      Paciente(id: id, nombre: nombre, cedula: cedula, edad: edad, cama: cama);

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'nombre': nombre,
    'cedula': cedula,
    'edad': edad,
    'cama': cama,
  };

  factory Paciente.fromMap(Map<String, Object?> m) => Paciente(
    id: m['id'] as int?,
    nombre: m['nombre']! as String,
    cedula: m['cedula']! as String,
    edad: m['edad']! as int,
    cama: m['cama']! as String,
  );

  /// Línea de identificación para las solicitudes a la IA. Se anonimiza
  /// antes de enviar (TSK-29).
  String toTexto() =>
      'Paciente: $nombre, cédula $cedula, $edad años, cama $cama';
}
