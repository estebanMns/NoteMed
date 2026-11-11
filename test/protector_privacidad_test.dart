// TSK-29 / TSK-31 · HU08: ocultar datos personales antes de enviar a la IA
// y restaurarlos en la respuesta.
import 'package:flutter_test/flutter_test.dart';
import 'package:notemed/core/privacidad/anonimizador.dart';
import 'package:notemed/core/privacidad/protector_privacidad.dart';

void main() {
  ProtectorPrivacidad nuevo() => ProtectorPrivacidad(
    nombre: 'María Fernanda Gómez',
    cedula: '1.085.123.456',
    cama: '12B',
  );

  const solicitud =
      'Paciente: María Fernanda Gómez, cédula 1.085.123.456, 67 años, cama 12B\n'
      'La señora Gómez refiere dolor. Su hija, la Sra. Rosa Pérez, la acompaña.\n'
      'Signos vitales: TA 120/80 mmHg, FC 80 lpm';

  group('ocultar (TSK-29)', () {
    test('no deja nombre, cédula ni cama en el texto enviado', () {
      final enviado = nuevo().ocultar(solicitud);
      for (final dato in [
        'María',
        'Fernanda',
        'Gómez',
        '1.085.123.456',
        '1085123456',
        '12B',
        'Rosa',
        'Pérez',
      ]) {
        expect(enviado, isNot(contains(dato)), reason: dato);
      }
      expect(enviado, contains('PAC-001'));
      expect(enviado, contains('ID-001'));
      expect(enviado, contains('CAMA-001'));
    });

    test('conserva los datos clínicos', () {
      final enviado = nuevo().ocultar(solicitud);
      expect(enviado, contains('67 años'));
      expect(enviado, contains('TA 120/80 mmHg, FC 80 lpm'));
    });

    test('el mismo nombre siempre recibe el mismo código', () {
      final enviado = nuevo().ocultar(solicitud);
      expect('PAC-001'.allMatches(enviado).length, 2);
    });

    test('también oculta otros documentos o teléfonos del texto', () {
      final p = ProtectorPrivacidad(
        nombre: 'Ana Ruiz',
        cedula: '123456',
        cama: '1',
      );
      final enviado = p.ocultar(
        'Ana Ruiz, cama 1. Teléfono del familiar 3001234567.',
      );
      expect(enviado, isNot(contains('3001234567')));
      expect(
        Anonimizador.contieneDatosPersonales(enviado, nombres: ['Ana Ruiz']),
        isFalse,
      );
      expect(
        p.restaurar(enviado),
        'Ana Ruiz, cama 1. Teléfono del familiar 3001234567.',
      );
    });

    test('DatosPersonalesExpuestos explica por qué no se envió', () {
      expect('${const DatosPersonalesExpuestos()}', contains('no se envió'));
    });
  });

  group('restaurar (TSK-31)', () {
    test('devuelve los datos reales tal como se registraron', () {
      final p = nuevo();
      p.ocultar(solicitud);
      final respuesta = p.restaurar(
        '[S] Situación: PAC-001 (ID-001), en CAMA-001, refiere dolor. '
        'La acompaña PAC-002.',
      );
      expect(
        respuesta,
        '[S] Situación: María Fernanda Gómez (1.085.123.456), en cama 12B, '
        'refiere dolor. La acompaña Rosa Pérez.',
      );
    });

    test('no repite la palabra cama', () {
      final p = nuevo()..ocultar(solicitud);
      expect(
        p.restaurar('Paciente de la cama CAMA-001.'),
        'Paciente de la cama 12B.',
      );
    });

    test('tolera puntuación y deja igual los códigos desconocidos', () {
      final p = nuevo()..ocultar(solicitud);
      expect(
        p.restaurar('(PAC-001), PAC-009; ID-001.'),
        '(María Fernanda Gómez), PAC-009; 1.085.123.456.',
      );
    });

    test('cada solicitud tiene su propia tabla', () {
      final a = nuevo()..ocultar(solicitud);
      final b = ProtectorPrivacidad(
        nombre: 'Luis Torres',
        cedula: '7654321',
        cama: '4',
      );
      b.ocultar('Paciente: Luis Torres, cédula 7654321, cama 4');
      expect(a.restaurar('PAC-001'), 'María Fernanda Gómez');
      expect(b.restaurar('PAC-001'), 'Luis Torres');
    });
  });
}
