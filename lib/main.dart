import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:notemed/app/app.dart';
import 'package:notemed/app/providers.dart';
import 'package:notemed/core/datos/base_datos_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await BaseDatosLocal.abrirCifrada();
  runApp(
    ProviderScope(
      overrides: [baseDatosProvider.overrideWithValue(db)],
      child: const NoteMedApp(),
    ),
  );
}
