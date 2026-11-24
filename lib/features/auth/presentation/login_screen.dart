/// Inicio de sesión del personal de enfermería.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:notemed/features/auth/data/autenticacion_simulada.dart';
import 'package:notemed/features/auth/presentation/sesion.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  bool _entrando = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() {
      _entrando = true;
      _error = null;
    });
    final ok = await ref
        .read(sesionProvider.notifier)
        .iniciar(_usuario.text, _clave.text);
    if (!mounted) return;
    setState(() {
      _entrando = false;
      if (!ok) _error = 'Usuario o clave incorrectos';
    });
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final simulada = ref.watch(autenticacionProvider) is AutenticacionSimulada;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Icon(
                  Icons.local_hospital_outlined,
                  size: 56,
                  color: esquema.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'NoteMed',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  'Notas de enfermería · UCI',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: esquema.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const Key('login-usuario'),
                  controller: _usuario,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Usuario'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('login-clave'),
                  controller: _clave,
                  obscureText: true,
                  onSubmitted: (_) => _entrar(),
                  decoration: InputDecoration(
                    labelText: 'Clave',
                    errorText: _error,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('login-entrar'),
                  onPressed: _entrando ? null : _entrar,
                  child: Text(_entrando ? 'Entrando…' : 'Entrar'),
                ),
                if (simulada) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Modo de prueba: usuarios enfermera1, enfermera2 o jefe1, '
                    'clave ${AutenticacionSimulada.claveDemo}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: esquema.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
