// TSK-17 / TSK-19 · HU05: borrador editable y firma de la enfermera.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notemed/features/nota/borrador_screen.dart';
import 'package:notemed/features/nota/firma_enfermera.dart';
import 'package:notemed/features/nota/firma_modal.dart';
import 'package:notemed/features/nota/nota_clinica.dart';
import 'package:notemed/features/nota/servicio_notas.dart';
import 'package:notemed/features/paciente/signos_vitales.dart';

void main() {
  final ahora = DateTime(2026, 11, 11, 7, 0);

  group('FirmaEnfermera (TSK-19)', () {
    test('valida la tarjeta profesional', () {
      expect(FirmaEnfermera.validarTarjeta(''), isNotNull);
      expect(FirmaEnfermera.validarTarjeta('12'), isNotNull);
      expect(FirmaEnfermera.validarTarjeta('TP 123'), isNotNull);
      expect(FirmaEnfermera.validarTarjeta('TP-52341'), isNull);
    });

    test('una firma necesita al menos un trazo', () {
      expect(FirmaEnfermera.trazosValidos(const []), isFalse);
      expect(
        FirmaEnfermera.trazosValidos(const [
          [Offset.zero],
        ]),
        isFalse,
      );
      expect(
        FirmaEnfermera.trazosValidos(const [
          [Offset.zero, Offset(5, 5)],
        ]),
        isTrue,
      );
    });

    test('toMap y fromMap conservan los trazos', () {
      final f = FirmaEnfermera(
        trazos: const [
          [Offset(1, 2), Offset(3, 4)],
        ],
        tarjetaProfesional: 'TP-1234',
        fecha: ahora,
      );
      final copia = FirmaEnfermera.fromMap(f.toMap());
      expect(copia.trazos, f.trazos);
      expect(copia.tarjetaProfesional, 'TP-1234');
      expect(copia.fecha, ahora);
      expect(copia.esValida, isTrue);
    });
  });

  group('Modal de firma (TSK-19)', () {
    Future<FirmaEnfermera? Function()> montar(WidgetTester tester) async {
      FirmaEnfermera? resultado;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => resultado = await mostrarFirmaModal(
                context,
                ahora: () => ahora,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      return () => resultado;
    }

    testWidgets('no acepta sin firma ni tarjeta', (tester) async {
      final resultado = await montar(tester);
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('firma-aceptar')));
      await tester.pump();
      expect(find.text('Dibuje su firma'), findsOneWidget);
      expect(
        find.text('La tarjeta profesional es obligatoria'),
        findsOneWidget,
      );
      expect(find.byType(FirmaModal), findsOneWidget);
      expect(resultado(), isNull);
    });

    testWidgets('devuelve la firma dibujada y la tarjeta', (tester) async {
      final resultado = await montar(tester);
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('firma-lienzo')),
        const Offset(120, 30),
      );
      await tester.enterText(
        find.byKey(const Key('firma-tarjeta')),
        'tp-52341',
      );
      await tester.tap(find.byKey(const Key('firma-aceptar')));
      await tester.pumpAndSettle();

      final firma = resultado();
      expect(find.byType(FirmaModal), findsNothing);
      expect(firma, isNotNull);
      expect(firma!.tarjetaProfesional, 'TP-52341');
      expect(firma.trazos, isNotEmpty);
      expect(firma.trazos.first.length, greaterThan(1));
      expect(firma.fecha, ahora);
    });

    testWidgets('Limpiar borra la firma', (tester) async {
      await montar(tester);
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('firma-lienzo')),
        const Offset(80, 10),
      );
      await tester.pump();
      expect(find.text('Firme aquí con el dedo'), findsNothing);
      await tester.tap(find.byKey(const Key('firma-limpiar')));
      await tester.pump();
      expect(find.text('Firme aquí con el dedo'), findsOneWidget);
    });
  });

  group('Borrador editable (TSK-17)', () {
    final nota = NotaClinica(
      id: 1,
      pacienteId: 1,
      tipo: TipoNota.turno,
      texto: '[S] Situación: TA 130/80 mmHg.',
      creada: ahora,
      referencia: {
        'signos': const SignosVitales(
          taSistolica: 120,
          taDiastolica: 80,
        ).toMap(),
      },
    );

    Future<List<(String, FirmaEnfermera)>> montar(WidgetTester tester) async {
      final firmadas = <(String, FirmaEnfermera)>[];
      await tester.pumpWidget(
        MaterialApp(
          home: BorradorScreen(
            titulo: 'Nota de turno',
            textoInicial: nota.texto,
            revisar: ServicioNotas.revisor(nota),
            ahora: () => ahora,
            onFirmar: (t, f) async => firmadas.add((t, f)),
          ),
        ),
      );
      return firmadas;
    }

    FilledButton botonFirmar(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byKey(const Key('borrador-firmar')));

    testWidgets('muestra el texto generado en una caja editable', (
      tester,
    ) async {
      await montar(tester);
      final campo = tester.widget<TextField>(
        find.byKey(const Key('borrador-texto')),
      );
      expect(campo.controller!.text, nota.texto);
      expect(campo.readOnly, isFalse);
    });

    testWidgets('bloquea la firma si los signos no concuerdan y se corrige '
        'al editar', (tester) async {
      await montar(tester);
      expect(find.byKey(const Key('borrador-advertencias')), findsOneWidget);
      expect(find.textContaining('se registró 120/80'), findsOneWidget);
      expect(botonFirmar(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('borrador-texto')),
        '[S] Situación: TA 120/80 mmHg.',
      );
      await tester.pump();
      expect(find.byKey(const Key('borrador-advertencias')), findsNothing);
      expect(botonFirmar(tester).onPressed, isNotNull);
    });

    testWidgets('advierte siglas no aprobadas sin bloquear', (tester) async {
      await montar(tester);
      await tester.enterText(
        find.byKey(const Key('borrador-texto')),
        '[S] Situación: TA 120/80 mmHg. Insulina SC.',
      );
      await tester.pump();
      expect(find.textContaining('"SC" no está permitida'), findsOneWidget);
      expect(botonFirmar(tester).onPressed, isNotNull);
    });

    testWidgets('firma con el texto editado', (tester) async {
      final firmadas = await montar(tester);
      await tester.enterText(
        find.byKey(const Key('borrador-texto')),
        '[S] Situación: TA 120/80 mmHg. Paciente tranquilo.',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('borrador-firmar')));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('firma-lienzo')),
        const Offset(100, 20),
      );
      await tester.enterText(find.byKey(const Key('firma-tarjeta')), 'TP-1234');
      await tester.tap(find.byKey(const Key('firma-aceptar')));
      await tester.pumpAndSettle();

      expect(firmadas, hasLength(1));
      expect(
        firmadas.single.$1,
        '[S] Situación: TA 120/80 mmHg. Paciente tranquilo.',
      );
      expect(firmadas.single.$2.tarjetaProfesional, 'TP-1234');
    });
  });
}
