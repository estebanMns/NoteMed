// TSK-01 / TSK-03 · HU01: datos básicos del paciente e infusiones.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notemed/features/paciente/infusion.dart';
import 'package:notemed/features/paciente/infusiones_form.dart';
import 'package:notemed/features/paciente/paciente.dart';
import 'package:notemed/features/paciente/paciente_form_screen.dart';
import 'package:notemed/features/paciente/signos_vitales.dart';

void main() {
  group('Paciente (TSK-01)', () {
    test('un paciente completo es válido', () {
      const p = Paciente(
        nombre: 'Ana Ruiz',
        cedula: '1085123456',
        edad: 40,
        cama: '12B',
      );
      expect(p.validar(), isEmpty);
    });

    test('valida nombre, cédula, edad y cama', () {
      expect(Paciente.validarNombre(''), isNotNull);
      expect(Paciente.validarNombre('Ana'), 'Escriba nombre y apellido');
      expect(Paciente.validarNombre('Ana 123'), isNotNull);
      expect(Paciente.validarNombre('José Muñoz-Peña'), isNull);

      expect(Paciente.validarCedula('12345'), contains('entre 6 y 10'));
      expect(Paciente.validarCedula('12345678901'), contains('entre 6 y 10'));
      expect(Paciente.validarCedula('12a456'), isNotNull);
      expect(Paciente.validarCedula('1.085.123.456'), isNull);
      expect(Paciente.validarCedula('123456'), isNull);

      expect(Paciente.validarEdad('-1'), isNotNull);
      expect(Paciente.validarEdad('121'), isNotNull);
      expect(Paciente.validarEdad('4.5'), isNotNull);
      expect(Paciente.validarEdad('0'), isNull);

      expect(Paciente.validarCama(''), isNotNull);
      expect(Paciente.validarCama('cama doce'), isNotNull);
      for (final c in ['12', '12B', 'B-3', '204']) {
        expect(Paciente.validarCama(c), isNull, reason: c);
      }
    });

    test('toMap y fromMap conservan los datos', () {
      const p = Paciente(
        id: 7,
        nombre: 'Ana Ruiz',
        cedula: '123456',
        edad: 40,
        cama: '3',
      );
      final copia = Paciente.fromMap(p.toMap());
      expect(copia.toMap(), p.toMap());
    });
  });

  group('SignosVitales', () {
    test('valida rangos y la TA completa', () {
      expect(
        const SignosVitales(taSistolica: 120).validar(),
        contains('Registre la TA sistólica y diastólica'),
      );
      expect(
        const SignosVitales(taSistolica: 80, taDiastolica: 90).validar(),
        contains('La TA diastólica debe ser menor que la sistólica'),
      );
      expect(const SignosVitales(spo2: 101).esValido, isFalse);
      expect(
        const SignosVitales(
          taSistolica: 120,
          taDiastolica: 80,
          fc: 80,
          fr: 18,
          spo2: 95,
          temperatura: 36.8,
        ).esValido,
        isTrue,
      );
    });

    test('toTexto usa las siglas aprobadas', () {
      expect(
        const SignosVitales(
          taSistolica: 120,
          taDiastolica: 80,
          fc: 80,
          fr: 18,
          spo2: 95,
          temperatura: 37,
        ).toTexto(),
        'TA 120/80 mmHg, FC 80 lpm, FR 18 rpm, SpO2 95 %, T 37 °C',
      );
      expect(const SignosVitales().toTexto(), 'No registrados');
    });
  });

  group('Infusion (TSK-03)', () {
    test('valida dosis y ritmo mayores que 0', () {
      expect(Infusion.validarDosis('0'), isNotNull);
      expect(Infusion.validarDosis('abc'), isNotNull);
      expect(Infusion.validarDosis('0,5'), isNull, reason: 'acepta coma');
      expect(Infusion.validarRitmo('0'), isNotNull);
      expect(Infusion.validarRitmo('1000'), isNotNull);
      expect(Infusion.validarRitmo('8.5'), isNull);
      expect(Infusion.validarMedicamento('  '), isNotNull);
    });

    test('toTexto y serialización', () {
      const i = Infusion(
        medicamento: 'Noradrenalina',
        dosis: 0.1,
        unidad: UnidadDosis.mcgKgMin,
        ritmoMlH: 8,
        concentracion: '4 mg en 250 mL',
      );
      expect(
        i.toTexto(),
        'Noradrenalina 0.1 mcg/kg/min a 8 mL/h (4 mg en 250 mL)',
      );
      expect(Infusion.fromMap(i.toMap()).toTexto(), i.toTexto());
    });

    test('ninguna unidad usa la sigla prohibida UI', () {
      expect(UnidadDosis.values.map((u) => u.etiqueta), isNot(contains('UI')));
    });
  });

  group('Formularios', () {
    testWidgets('PacienteFormScreen valida y guarda (TSK-01)', (tester) async {
      Paciente? guardado;
      await tester.pumpWidget(
        MaterialApp(home: PacienteFormScreen(onGuardar: (p) => guardado = p)),
      );

      await tester.tap(find.byKey(const Key('pac-guardar')));
      await tester.pump();
      expect(find.text('El nombre es obligatorio'), findsOneWidget);
      expect(guardado, isNull);

      await tester.enterText(
        find.byKey(const Key('pac-nombre')),
        '  Ana   Ruiz ',
      );
      await tester.enterText(find.byKey(const Key('pac-cedula')), '1.085.123');
      await tester.enterText(find.byKey(const Key('pac-edad')), '40');
      await tester.enterText(find.byKey(const Key('pac-cama')), '12b');
      await tester.tap(find.byKey(const Key('pac-guardar')));
      await tester.pump();

      expect(guardado, isNotNull);
      expect(guardado!.nombre, 'Ana Ruiz');
      expect(guardado!.cedula, '1085123', reason: 'se guarda sin puntos');
      expect(guardado!.edad, 40);
      expect(guardado!.cama, '12B');
    });

    testWidgets('InfusionesForm agrega infusiones válidas (TSK-03)', (
      tester,
    ) async {
      final agregadas = <Infusion>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InfusionesForm(
                infusiones: const [],
                onAgregar: agregadas.add,
                onEliminar: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('inf-agregar')));
      await tester.pump();
      expect(find.text('El medicamento es obligatorio'), findsOneWidget);
      expect(agregadas, isEmpty);

      await tester.enterText(
        find.byKey(const Key('inf-medicamento')),
        'Midazolam',
      );
      await tester.enterText(find.byKey(const Key('inf-dosis')), '2,5');
      await tester.enterText(find.byKey(const Key('inf-ritmo')), '5');
      await tester.tap(find.byKey(const Key('inf-agregar')));
      await tester.pump();

      expect(agregadas, hasLength(1));
      expect(agregadas.single.dosis, 2.5);
      expect(agregadas.single.unidad, UnidadDosis.mg);
      expect(agregadas.single.ritmoMlH, 5);
    });
  });
}
