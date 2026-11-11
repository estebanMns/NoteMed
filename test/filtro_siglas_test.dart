// TSK-24 · HU06: pruebas de texto del filtro de siglas (Ley 911 de 2004).
import 'package:flutter_test/flutter_test.dart';
import 'package:notemed/core/privacidad/anonimizador.dart';
import 'package:notemed/core/validacion/filtro_siglas.dart';

void main() {
  const filtro = FiltroSiglas();

  group('siglas permitidas', () {
    test('un texto solo con siglas aprobadas es válido', () {
      const t = 'TA 120/80, FC 88 por minuto, FR 18, SpO2 94%. '
          'Líquidos IV y dieta por VO.';
      expect(filtro.analizar(t), isEmpty);
      expect(filtro.esValido(t), isTrue);
    });

    test('expandir reemplaza las siglas aprobadas por su significado', () {
      expect(filtro.expandir('TA estable, tolera VO.'),
          'tensión arterial estable, tolera vía oral.');
    });
  });

  group('siglas prohibidas', () {
    test('detecta UI, SC y QD con posición y sugerencia', () {
      const t = 'Administrar insulina 10 UI SC QD.';
      final h = filtro.analizar(t);
      expect(h.map((e) => e.sigla), ['UI', 'SC', 'QD']);
      expect(h.every((e) => e.tipo == TipoHallazgo.prohibida), isTrue);
      expect(h.first.inicio, t.indexOf('UI'));
      expect(h.first.fin, t.indexOf('UI') + 2);
      expect(h.last.sugerencia, 'diario');
      expect(h.first.mensaje, contains('unidades internacionales'));
      expect(filtro.esValido(t), isFalse);
    });

    test('siglas al inicio, al final y entre signos de puntuación', () {
      expect(filtro.analizar('IAM. Se deja (NPO), aplicar PRN')
          .map((e) => e.sigla), ['IAM', 'NPO', 'PRN']);
    });

    test('expandir corrige las prohibidas con la sugerencia', () {
      expect(filtro.expandir('Dosis BID'), 'Dosis cada 12 horas');
    });
  });

  group('siglas desconocidas', () {
    test('una sigla fuera de la lista se marca como desconocida', () {
      final h = filtro.analizar('Paciente con XYZ conocido');
      expect(h, hasLength(1));
      expect(h.single.sigla, 'XYZ');
      expect(h.single.tipo, TipoHallazgo.desconocida);
      expect(h.single.sugerencia, isNull);
    });

    test('expandir deja intactas las desconocidas', () {
      expect(filtro.expandir('Antecedente de XYZ'), 'Antecedente de XYZ');
    });
  });

  group('lo que no es una sigla', () {
    test('las unidades en minúscula no se marcan', () {
      expect(filtro.analizar('Dipirona 1 g cada 8 h, 500 mg, 20 mL, 2 L/min'),
          isEmpty);
    });

    test('las palabras que solo empiezan con mayúscula no se marcan', () {
      expect(filtro.analizar('Paciente Se Encuentra Alerta. Orientado.'),
          isEmpty);
    });

    test('las palabras largas en mayúscula (más de 6 letras) no se marcan', () {
      expect(filtro.analizar('PACIENTE ESTABLE'), isEmpty);
    });

    test('los códigos de anonimización no se marcan', () {
      expect(filtro.analizar('PAC-001 en CAMA-002, ID-003'), isEmpty);
    });

    test('las mayúsculas dentro de una palabra no generan hallazgos', () {
      expect(filtro.analizar('eCG mixtoTA'), isEmpty);
    });
  });

  test('una lista institucional propia reemplaza la lista por defecto', () {
    const propio = FiltroSiglas(permitidas: {'XYZ': 'algo'}, prohibidas: {});
    expect(propio.esValido('XYZ'), isTrue);
    expect(propio.analizar('TA')
        .single.tipo, TipoHallazgo.desconocida);
  });

  test('integración: una nota anonimizada pasa el filtro de siglas', () {
    final nota = Anonimizador().anonimizar(
      'Recibo a Ana Díaz en cama 4, TA 110/70, FC 76, SpO2 96%.',
      nombresConocidos: ['Ana Díaz'],
    );
    expect(nota, 'Recibo a PAC-001 en CAMA-001, TA 110/70, FC 76, SpO2 96%.');
    expect(filtro.esValido(nota), isTrue);
  });
}
