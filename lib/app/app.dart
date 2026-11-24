/// Widget raíz. Necesita un `ProviderScope` arriba (ver `main.dart`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:notemed/app/router.dart';
import 'package:notemed/app/tema.dart';

class NoteMedApp extends ConsumerWidget {
  const NoteMedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'NoteMed',
    theme: temaNoteMed(),
    routerConfig: ref.watch(routerProvider),
    debugShowCheckedModeBanner: false,
  );
}
