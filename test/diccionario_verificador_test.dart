// TSK-21 / TSK-23 · HU06: diccionario de siglas aprobadas y verificación de
// los signos vitales en el texto generado.
import 'package:flutter_test/flutter_test.dart';
import 'package:notemed/core/validacion/diccionario_medico.dart';
import 'package:notemed/core/validacion/filtro_siglas.dart';
import 'package:notemed/core/validacion/verificador_signos_vitales.dart';
import 'package:notemed/features/paciente/signos_vitales.dart';

void main() {
  const dic = DiccionarioMedico.aprobado;

  group('DiccionarioMedico (TSK-21)', () {
    test('incluye todas las siglas permitidas del filtro', () {
      for (final e in siglasPermitidas.entries) {
        expect(dic.buscar(e.key)?.significado, e.value, reason: e.key);
      }
    });

    test('no aprueba ninguna sigla prohibida', () {
      for (final s in siglasProhibidas.keys) {
        expect(dic.contiene(s), isFalse, reason: s);
      }
    });

    test('las siglas no se repiten', () {
      final siglas = dic.terminos.map((t) => t.sigla).toList();
      expect(siglas.toSet(), hasLength(siglas.length));
    });

    test('busca por sigla exacta, con mayúsculas', () {
      expect(dic.buscar('SNG')?.significado, 'sonda nasogástrica');
      expect(dic.buscar('sng'), isNull);
    });

    test('filtra por sigla o significado sin importar tildes', () {
      expect(
        dic.filtrar('cateter').map((t) => t.sigla),
        containsAll(['CVC', 'CVP']),
      );
      expect(
        dic.filtrar('SATURACION').map((t) => t.sigla),
        containsAll(['SpO2', 'SatO2']),
      );
      expect(dic.filtrar(''), hasLength(dic.terminos.length));
    });

    test('agrupa por categoría', () {
      expect(
        dic.porCategoria(CategoriaTermino.signosVitales).map((t) => t.sigla),
        containsAll(['TA', 'FC', 'FR', 'SpO2']),
      );
    });

    test('su filtro acepta las siglas nuevas y rechaza las prohibidas', () {
      final filtro = dic.filtro;
      expect(filtro.esValido('Porta CVC y SV, en UCI.'), isTrue);
      expect(
        siglasPermitidas.containsKey('CVC'),
        isFalse,
        reason: 'la lista original no la tenía',
      );
      final h = filtro.analizar('Insulina 10 UI SC');
      expect(h.map((x) => x.tipo), everyElement(TipoHallazgo.prohibida));
    });
  });

  group('VerificadorSignosVitales (TSK-23)', () {
    const v = VerificadorSignosVitales();
    const signos = SignosVitales(
      taSistolica: 120,
      taDiastolica: 80,
      fc: 88,
      fr: 18,
      spo2: 94,
      temperatura: 37.5,
    );

    test('extrae valores con siglas y con nombres completos', () {
      final e = v.extraer(
        'Tensión arterial de 120/80, frecuencia cardiaca 88, '
        'FR: 18, saturación de oxígeno 94 %, temperatura 37,5 °C',
      );
      expect(e[SignoVital.ta], ['120/80']);
      expect(e[SignoVital.fc], ['88']);
      expect(e[SignoVital.fr], ['18']);
      expect(e[SignoVital.spo2], ['94']);
      expect(e[SignoVital.temperatura], ['37.5']);
    });

    test('un texto que copia los signos exactos concuerda', () {
      final texto =
          '[S] Situación: TA 120/80 mmHg, FC 88 lpm, FR 18 rpm, '
          'SpO2 94 %, T 37.5 °C.';
      expect(v.verificar(texto, signos), isEmpty);
      expect(v.concuerda(texto, signos), isTrue);
    });

    test('detecta un valor diferente', () {
      final d = v.verificar(
        'TA 130/80 mmHg, FC 88, FR 18, SpO2 94 %, T 37.5',
        signos,
      );
      expect(d, hasLength(1));
      expect(d.single.signo, SignoVital.ta);
      expect(d.single.tipo, TipoDiscrepancia.diferente);
      expect(d.single.mensaje, contains('130/80'));
      expect(d.single.mensaje, contains('120/80'));
    });

    test('detecta un valor inventado (no registrado)', () {
      const sinFc = SignosVitales(taSistolica: 120, taDiastolica: 80);
      final d = v.verificar('TA 120/80, FC 72', sinFc);
      expect(d.single.signo, SignoVital.fc);
      expect(d.single.tipo, TipoDiscrepancia.noRegistrado);
      expect(v.concuerda('TA 120/80, FC 72', sinFc), isFalse);
    });

    test('las omisiones son advertencias, no errores', () {
      final d = v.verificar('TA 120/80 mmHg', signos);
      expect(d.map((x) => x.tipo), everyElement(TipoDiscrepancia.omitido));
      expect(
        d.map((x) => x.signo),
        containsAll([SignoVital.fc, SignoVital.fr, SignoVital.spo2]),
      );
      expect(v.concuerda('TA 120/80 mmHg', signos), isTrue);
    });

    test('no confunde el calibre "Fr 16" de una sonda con la FR', () {
      final e = v.extraer('Sonda vesical Fr 16, FR 18');
      expect(e[SignoVital.fr], ['18']);
    });

    test('no confunde TA ni TAM con la temperatura', () {
      final e = v.extraer('TA 120/80, TAM 93, T 36');
      expect(e[SignoVital.temperatura], ['36']);
      expect(e[SignoVital.ta], ['120/80']);
    });

    test('37 y 37.0 son la misma temperatura', () {
      expect(
        v.verificar('T 37.0 °C', const SignosVitales(temperatura: 37)),
        isEmpty,
      );
    });
  });
}
