/// Tema visual. Botones y campos grandes: la app se usa de pie, con prisa y a
/// veces con guantes.
library;

import 'package:material_ui/material_ui.dart';

ThemeData temaNoteMed() {
  final esquema = ColorScheme.fromSeed(seedColor: Colors.teal);
  return ThemeData(
    colorScheme: esquema,
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
    ),
  );
}
