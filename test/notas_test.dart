// HU09 (borrador IA) y HU10 (firma): casos de uso de notas clínicas.
import 'package:flutter_test/flutter_test.dart';
import 'package:notemed/features/notas/domain/casos_de_uso.dart';
import 'package:notemed/features/notas/domain/llm_gateway.dart';
import 'package:notemed/features/notas/domain/nota_clinica.dart';

/// Doble de prueba: registra lo que recibe el modelo y devuelve una respuesta
/// fija.
class _EspiaLlm implements LlmGateway {
  _EspiaLlm(this.respuesta);

  final String respuesta;
  String? contextoRecibido;

  @override
  Future<String> generar({
    required String instruccion,
    required String contexto,
  }) async {
    contextoRecibido = contexto;
    return respuesta;
  }
}

NotaClinica _borrador(String texto) => NotaClinica(
      id: 'n1',
      pseudonimoPaciente: 'PAC-001',
      tipo: TipoNota.evolucion,
      texto: texto,
    );

void main() {
  group('NotaClinica (ciclo de vida)', () {
    test('no se firma un borrador sin revisar', () {
      expect(
        () => _borrador('x').firmar(firmante: 'ENF-01', ahora: DateTime(2026)),
        throwsStateError,
      );
    });

    test('una nota firmada no se modifica', () {
      final firmada = _borrador('TA 120/80')
          .revisar('TA 120/80 estable')
          .firmar(firmante: 'ENF-01', ahora: DateTime(2026, 11, 23));
      expect(firmada.esFirmada, isTrue);
      expect(firmada.firmadaPor, 'ENF-01');
      expect(() => firmada.revisar('otro'), throwsStateError);
    });
  });

  group('FirmarNota (reglas de firma)', () {
    const firmar = FirmarNota();

    test('rechaza una nota que no fue revisada', () {
      expect(
        () => firmar.ejecutar(_borrador('TA 120/80'),
            firmante: 'ENF-01', ahora: DateTime(2026)),
        throwsA(isA<NotaNoFirmableException>()),
      );
    });

    test('rechaza una sigla prohibida (Ley 911, art. 38)', () {
      final revisada = _borrador('Metformina 500 mg QD.').revisar(
        'Metformina 500 mg QD.',
      );
      expect(
        () => firmar.ejecutar(revisada,
            firmante: 'ENF-01', ahora: DateTime(2026)),
        throwsA(isA<NotaNoFirmableException>()),
      );
    });

    test('rechaza firmar sin firmante', () {
      final revisada = _borrador('TA 120/80').revisar('TA 120/80');
      expect(
        () => firmar.ejecutar(revisada, firmante: '  ', ahora: DateTime(2026)),
        throwsA(isA<NotaNoFirmableException>()),
      );
    });

    test('firma una nota revisada con siglas aprobadas', () {
      final revisada =
          _borrador('TA 120/80, FC 88.').revisar('TA 120/80, FC 88.');
      final firmada = firmar.ejecutar(revisada,
          firmante: ' ENF-01 ', ahora: DateTime(2026, 11, 23));
      expect(firmada.esFirmada, isTrue);
      expect(firmada.firmadaPor, 'ENF-01');
    });
  });

  group('GenerarBorrador (seudonimización y re-identificación)', () {
    const datos = 'Paciente Ana Torres, cama 12, TA 120/80, FC 88.';

    test('el modelo nunca recibe el nombre real', () async {
      final espia =
          _EspiaLlm('Paciente PAC-001 en CAMA-001 con TA estable.');
      final resultado = await GenerarBorrador(llm: espia).ejecutar(
        tipo: TipoNota.evolucion,
        datos: datos,
        nombresPacientes: const ['Ana Torres'],
      );

      expect(espia.contextoRecibido, isNotNull);
      expect(espia.contextoRecibido, isNot(contains('Ana')));
      expect(espia.contextoRecibido, isNot(contains('Torres')));
      expect(espia.contextoRecibido, contains('PAC-001'));
      // Al usuario local sí se le muestra el nombre.
      expect(resultado.texto, contains('Ana Torres'));
      expect(resultado.listoParaRevisar, isTrue);
    });

    test('marca las siglas prohibidas que devuelve el modelo', () async {
      final espia = _EspiaLlm('Paciente PAC-001 con dosis QD.');
      final resultado = await GenerarBorrador(llm: espia).ejecutar(
        tipo: TipoNota.recibo,
        datos: datos,
        nombresPacientes: const ['Ana Torres'],
      );

      expect(resultado.hallazgos, hasLength(1));
      expect(resultado.hallazgos.single.sigla, 'QD');
      expect(resultado.listoParaRevisar, isFalse);
    });
  });
}
