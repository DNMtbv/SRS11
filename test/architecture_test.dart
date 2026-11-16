import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Проверка правила зависимостей Clean Architecture по import'ам.
/// Если кто-то протащит Flutter/Dio в Domain или Data в Presentation,
/// этот тест упадёт.

List<(String, String)> _imports(String dir) => [
      for (final f in Directory(dir).listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
          for (final line in f.readAsLinesSync())
            if (line.startsWith('import '))
              (f.path.replaceAll(r'\', '/'), line),
    ];

Matcher _noneMatch(RegExp forbidden) => predicate<List<(String, String)>>(
      (imports) {
        final bad = imports.where((i) => forbidden.hasMatch(i.$2)).toList();
        for (final (file, line) in bad) {
          // ignore: avoid_print
          print('Нарушение: $file → $line');
        }
        return bad.isEmpty;
      },
      'нет import, подходящих под $forbidden',
    );

void main() {
  test('Domain не зависит от Flutter, Dio, Firebase, хранилищ, Data и UI', () {
    expect(
      _imports('lib/src/domain'),
      _noneMatch(RegExp(
        r'package:flutter|dio|retrofit|firebase|shared_preferences|'
        r'json_annotation|get_it|/data/|/presentation/|models/|rest_client',
      )),
    );
  });

  test('Presentation не знает про Data, DTO, Dio и Firebase', () {
    expect(
      _imports('lib/src/presentation'),
      _noneMatch(RegExp(
        r'/data/|/models/|package:dio|retrofit|firebase|shared_preferences|'
        r'rest_client',
      )),
    );
  });

  test('Data не зависит от Presentation', () {
    expect(
      _imports('lib/src/data'),
      _noneMatch(RegExp(r'/presentation/|package:flutter/')),
    );
  });

  test('Экраны и BLoC не создают репозитории и data sources напрямую', () {
    final sources = [
      for (final f in Directory('lib/src/presentation').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart')) f.readAsStringSync(),
    ].join('\n');
    expect(sources, isNot(contains('RepositoryImpl(')));
    expect(sources, isNot(contains('DataSourceImpl(')));
    expect(sources, isNot(contains('RestClient(')));
  });
}
