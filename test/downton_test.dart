// Escala de Downton (riesgo de caídas).
import 'package:flutter_test/flutter_test.dart';
import 'package:notemed/features/valoracion/domain/downton_escala.dart';

void main() {
  group('EvaluacionDownton', () {
    test('sin factores: riesgo bajo y total 0', () {
      const e = EvaluacionDownton();
      expect(e.total, 0);
      expect(e.nivel, NivelRiesgoCaidas.bajo);
    });

    test('dos factores siguen siendo riesgo bajo', () {
      const e = EvaluacionDownton(caidasPrevias: true, marchaAlterada: true);
      expect(e.total, 2);
      expect(e.nivel, NivelRiesgoCaidas.bajo);
    });

    test('tres factores o más: riesgo alto', () {
      const e = EvaluacionDownton(
        caidasPrevias: true,
        medicacionRiesgo: true,
        estadoMentalAlterado: true,
      );
      expect(e.total, 3);
      expect(e.nivel, NivelRiesgoCaidas.alto);
    });

    test('los cinco factores suman 5', () {
      const e = EvaluacionDownton(
        caidasPrevias: true,
        medicacionRiesgo: true,
        deficitSensorial: true,
        estadoMentalAlterado: true,
        marchaAlterada: true,
      );
      expect(e.total, 5);
    });
  });
}
