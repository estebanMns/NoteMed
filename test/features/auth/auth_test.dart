import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:notemed/features/auth/data/autenticacion_simulada.dart';
import 'package:notemed/features/auth/domain/usuario.dart';
import 'package:notemed/features/notas/data/ia/servicio_ia_simulado.dart';
import 'package:notemed/features/pacientes/presentation/paciente_screen.dart';

import '../../apoyo/dobles.dart';

const _jefe = Usuario(
  usuario: 'jefe1',
  tarjetaProfesional: 'TP-20001',
  rol: Rol.jefe,
);

void main() {
  group('AutenticacionSimulada', () {
    const auth = AutenticacionSimulada();

    test('acepta usuarios de prueba con la clave correcta', () async {
      final u = await auth.iniciarSesion(' Enfermera1 ', 'notemed123');
      expect(u?.tarjetaProfesional, 'TP-10001');
      expect(u?.rol, Rol.enfermera);
      expect((await auth.iniciarSesion('jefe1', 'notemed123'))?.rol, Rol.jefe);
    });

    test('rechaza clave o usuario incorrectos', () async {
      expect(await auth.iniciarSesion('enfermera1', 'otra'), isNull);
      expect(await auth.iniciarSesion('nadie', 'notemed123'), isNull);
    });

    test('solo el jefe ve las métricas', () {
      expect(Rol.jefe.veMetricas, isTrue);
      expect(Rol.enfermera.veMetricas, isFalse);
    });
  });

  testWidgets('sin sesión muestra el login y entra con la clave correcta', (
    tester,
  ) async {
    await tester.pumpWidget(
      conDependencias(repo: RepositorioMemoria(), sesion: null),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-entrar')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login-usuario')),
      'enfermera1',
    );
    await tester.enterText(find.byKey(const Key('login-clave')), 'mala');
    await tester.tap(find.byKey(const Key('login-entrar')));
    await tester.pumpAndSettle();
    expect(find.text('Usuario o clave incorrectos'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('login-clave')), 'notemed123');
    await tester.tap(find.byKey(const Key('login-entrar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu-pacientes')), findsOneWidget);
    expect(find.text('Enfermera(o) · TP-10001'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cerrar-sesion')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-entrar')), findsOneWidget);
  });

  testWidgets('la enfermera no ve las métricas', (tester) async {
    await tester.pumpWidget(conDependencias(repo: RepositorioMemoria()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu-metricas')), findsNothing);
  });

  testWidgets('el jefe abre las métricas', (tester) async {
    await tester.pumpWidget(
      conDependencias(repo: RepositorioMemoria(), sesion: _jefe),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu-metricas')));
    await tester.pumpAndSettle();
    expect(find.text('Métricas de validación'), findsOneWidget);
    expect(
      find.textContaining('Todavía no hay notas firmadas'),
      findsOneWidget,
    );
  });

  testWidgets('la firma trae la tarjeta profesional de la sesión', (
    tester,
  ) async {
    final repo = RepositorioMemoria();
    final p = await repo.guardarPaciente(pacienteEjemplo);
    await tester.pumpWidget(
      conDependencias(
        repo: repo,
        ia: const ServicioIASimulado(demora: Duration.zero),
        hijo: PacienteScreen(paciente: p),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn-generar-nota')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('borrador-firmar')));
    await tester.pumpAndSettle();

    final tarjeta = tester.widget<TextField>(
      find.byKey(const Key('firma-tarjeta')),
    );
    expect(tarjeta.controller!.text, 'TP-10001');
  });
}
