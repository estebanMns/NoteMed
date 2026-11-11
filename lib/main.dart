import 'package:flutter/material.dart';

import 'features/riesgos/braden/braden_screen.dart';
import 'features/turno/entrega_turno_screen.dart';

void main() {
  runApp(const NoteMedApp());
}

class NoteMedApp extends StatelessWidget {
  const NoteMedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoteMed',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void abrir(Widget pantalla) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => pantalla));

    return Scaffold(
      appBar: AppBar(title: const Text('NoteMed')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              key: const Key('menu-braden'),
              leading: const Icon(Icons.healing),
              title: const Text('Escala de Braden'),
              subtitle: const Text('Riesgo de lesiones por presión'),
              onTap: () => abrir(const BradenScreen()),
            ),
          ),
          Card(
            child: ListTile(
              key: const Key('menu-turno'),
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Entrega de turno'),
              subtitle: const Text('Nota SBAR y balance de líquidos'),
              onTap: () => abrir(const EntregaTurnoScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
