// TSK-32 · HU08: pruebas automatizadas de que no salen datos personales
// (Ley 1581 de 2012).
import 'package:flutter_test/flutter_test.dart';
import 'package:notemed/core/privacidad/anonimizador.dart';

void main() {
  group('Anonimizador · reemplazos', () {
    test('reemplaza nombre, cédula con puntos y cama', () {
      final a = Anonimizador();
      final salida = a.anonimizar(
        'Paciente María Pérez, C.C. 1.023.456.789, en cama 12.',
        nombresConocidos: ['María Pérez'],
      );
      expect(salida, 'Paciente PAC-001, C.C. ID-001, en CAMA-001.');
    });

    test('cédula sin puntos y habitación con letra', () {
      final salida = Anonimizador()
          .anonimizar('Documento 52345678, habitación 304B, hab. 7');
      expect(salida, 'Documento ID-001, CAMA-001, CAMA-002');
    });

    test('cama con "No." y "N°"', () {
      final salida =
          Anonimizador().anonimizar('Cama No. 5 y cama N° 6');
      expect(salida, 'CAMA-001 y CAMA-002');
    });

    test('nombres sin importar tildes ni mayúsculas, y apellidos sueltos', () {
      final salida = Anonimizador().anonimizar(
        'jose pena refiere dolor. PEÑA tolera dieta. José deambula.',
        nombresConocidos: ['José Peña'],
      );
      expect(salida,
          'PAC-001 refiere dolor. PAC-001 tolera dieta. PAC-001 deambula.');
    });

    test('nombres detrás de un tratamiento de cortesía sin lista previa', () {
      final salida = Anonimizador()
          .anonimizar('La señora Gómez fue valorada; el Sr. Luis Rojas refiere mareo.');
      expect(salida,
          'La señora PAC-001 fue valorada; el Sr. PAC-002 refiere mareo.');
    });

    test('no reemplaza partículas como "del" del nombre compuesto', () {
      final salida = Anonimizador().anonimizar(
        'María del Carmen Ruiz, lado izquierdo del abdomen.',
        nombresConocidos: ['María del Carmen Ruiz'],
      );
      expect(salida, 'PAC-001, lado izquierdo del abdomen.');
    });

    test('mapeo determinista: el mismo dato da el mismo código', () {
      final a = Anonimizador();
      final s1 = a.anonimizar('Ana Díaz CC 1012345678',
          nombresConocidos: ['Ana Díaz']);
      final s2 = a.anonimizar('Control de Ana Díaz, CC 1012345678',
          nombresConocidos: ['Ana Díaz']);
      final s3 = a.anonimizar('Luis Vega CC 79123456',
          nombresConocidos: ['Luis Vega']);
      expect(s1, 'PAC-001 CC ID-001');
      expect(s2, 'Control de PAC-001, CC ID-001');
      expect(s3, 'PAC-002 CC ID-002');
    });

    test('no altera los datos clínicos numéricos', () {
      const nota = 'TA 120/80 mmHg, FC 88, diuresis 1500 mL, '
          'glucometría 110 mg/dL, fecha 11/11/2026, 14:30 h.';
      expect(Anonimizador().anonimizar(nota), nota);
    });

    test('la tabla de reidentificación no se puede modificar desde fuera', () {
      final a = Anonimizador()..anonimizar('CC 52345678');
      expect(a.tablaReidentificacion.values, contains('ID-001'));
      expect(() => a.tablaReidentificacion['x'] = 'y',
          throwsUnsupportedError);
    });
  });

  group('Anonimizador · no salen datos personales', () {
    // Notas de ejemplo con datos ficticios.
    final casos = <({String nota, List<String> nombres, List<String> sensibles})>[
      (
        nota: 'Recibo a Carlos Andrés Muñoz, CC 80.123.456, cama 21. '
            'Muñoz refiere dolor 6/10.',
        nombres: ['Carlos Andrés Muñoz'],
        sensibles: ['Carlos', 'Andrés', 'Muñoz', '80.123.456', '80123456', 'cama 21'],
      ),
      (
        nota: 'Sra. Lucía Herrera (TI 1098765432) en habitación 3A, '
            'acompañada por su hija.',
        nombres: ['Lucía Herrera'],
        sensibles: ['Lucía', 'Herrera', '1098765432', 'habitación 3A'],
      ),
      (
        nota: 'LUCIA HERRERA trasladada de cama 4 a cama 9. Contacto 3001234567.',
        nombres: ['Lucía Herrera'],
        sensibles: ['LUCIA', 'HERRERA', 'cama 4', 'cama 9', '3001234567'],
      ),
      (
        nota: 'Entrega: don Pedro Salas, cédula 1.234.567, Hab. 12, estable.',
        nombres: [],
        sensibles: ['Pedro', 'Salas', '1.234.567', 'Hab. 12'],
      ),
    ];

    for (final (i, c) in casos.indexed) {
      test('caso ${i + 1}: ningún dato sensible en la salida', () {
        final salida = Anonimizador().anonimizar(c.nota, nombresConocidos: c.nombres);
        for (final s in c.sensibles) {
          expect(salida.toLowerCase(), isNot(contains(s.toLowerCase())),
              reason: '"$s" aparece en: $salida');
        }
        expect(Anonimizador.contieneDatosPersonales(salida, nombres: c.nombres),
            isFalse, reason: salida);
      });
    }

    test('contieneDatosPersonales detecta el texto original', () {
      expect(
        Anonimizador.contieneDatosPersonales('Paciente en cama 3'),
        isTrue,
      );
      expect(Anonimizador.contieneDatosPersonales('CC 52345678'), isTrue);
      expect(
        Anonimizador.contieneDatosPersonales('Valorada Ana',
            nombres: ['Ana Díaz']),
        isTrue,
      );
      expect(Anonimizador.contieneDatosPersonales('TA 120/80'), isFalse);
    });
  });
}
