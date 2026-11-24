// Verifica la regla de dependencia de la Arquitectura Limpia: cada capa solo
// puede importar hacia el dominio.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _import = RegExp(r"""^(?:import|export)\s+'([^']+)'""", multiLine: true);

List<(String archivo, String import)> _importsDe(String capa) => [
  for (final f in Directory('lib/features').listSync(recursive: true))
    if (f is File && f.path.endsWith('.dart') && f.path.contains('/$capa/'))
      for (final m in _import.allMatches(f.readAsStringSync())) (f.path, m[1]!),
];

void _prohibir(String capa, List<Pattern> prohibidos) {
  final violaciones = [
    for (final (archivo, imp) in _importsDe(capa))
      if (prohibidos.any((p) => imp.contains(p))) '$archivo -> $imp',
  ];
  expect(violaciones, isEmpty, reason: 'La capa $capa importa algo prohibido');
}

const _infraestructura = [
  'package:sqflite',
  'package:http',
  'package:connectivity_plus',
  'package:flutter_secure_storage',
];

void main() {
  test('el dominio es Dart puro y no conoce las otras capas', () {
    expect(_importsDe('domain'), isNotEmpty);
    _prohibir('domain', [
      'package:flutter',
      'package:material_ui',
      'dart:ui',
      '/application/',
      '/data/',
      '/presentation/',
      ..._infraestructura,
    ]);
  });

  test('la aplicación no conoce datos ni presentación', () {
    _prohibir('application', [
      'package:flutter',
      'package:material_ui',
      'dart:ui',
      '/data/',
      '/presentation/',
      ..._infraestructura,
    ]);
  });

  test('la capa de datos no conoce la presentación', () {
    _prohibir('data', [
      'package:flutter/',
      'package:material_ui',
      '/presentation/',
    ]);
  });
}
