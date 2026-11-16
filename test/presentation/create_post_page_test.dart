import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practicevskodin/src/presentation/pages/create_post_page.dart';

import '../helpers/test_env.dart';

/// Отвечает списком авторов; POST /posts возвращает тело запроса с id = 101.
Future<ResponseBody> _handler(RequestOptions o) async {
  if (o.path == '/users') {
    return jsonResponse([userJson(1, 'Анна Ким'), userJson(2, 'Борис Ли')]);
  }
  return echoCreated(o);
}

Future<TestEnv> _pumpPage(WidgetTester tester, FakeHandler handler) async {
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);

  final env = await setUpTestDi(handler);
  await tester.pumpWidget(const MaterialApp(home: CreatePostPage()));
  await tester.pumpAndSettle();
  return env;
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _selectAuthor(WidgetTester tester, String name) async {
  await tester.tap(find.byType(DropdownButtonFormField<int>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

ButtonStyleButton _button(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );

void main() {
  testWidgets('пустая форма: показаны все ошибки, POST не отправляется',
      (tester) async {
    final env = await _pumpPage(tester, _handler);

    await tester.tap(find.text('Опубликовать'));
    await tester.pumpAndSettle();

    expect(find.text('Выберите автора'), findsOneWidget);
    expect(find.text('Заголовок обязателен'), findsOneWidget);
    expect(find.text('Текст обязателен'), findsOneWidget);
    expect(env.adapter.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('ошибка исчезает, когда значение поля исправлено', (tester) async {
    await _pumpPage(tester, _handler);

    await tester.enterText(_field('Заголовок'), 'abc');
    await tester.pumpAndSettle();
    expect(
      find.text('Заголовок: минимум 5 символов (сейчас 3)'),
      findsOneWidget,
    );

    await tester.enterText(_field('Заголовок'), 'Новый заголовок');
    await tester.pumpAndSettle();
    expect(find.textContaining('минимум 5 символов'), findsNothing);
  });

  testWidgets('отправка: кнопка заблокирована, затем диалог с ответом сервера',
      (tester) async {
    final response = Completer<void>();
    final env = await _pumpPage(tester, (o) async {
      if (o.method == 'POST') await response.future;
      return _handler(o);
    });

    await _selectAuthor(tester, 'Анна Ким');
    await tester.enterText(_field('Заголовок'), '  Мой заголовок  ');
    await tester.enterText(_field('Текст'), 'Текст моего поста');
    await tester.tap(find.text('Опубликовать'));
    await tester.pump();

    expect(find.text('Отправка…'), findsOneWidget);
    expect(_button(tester, 'Отправка…').onPressed, isNull);

    response.complete();
    await tester.pumpAndSettle();

    expect(find.text('Пост отправлен'), findsOneWidget);
    expect(find.textContaining('"id": 101'), findsOneWidget);
    expect(env.adapter.requests.last.data, {
      'userId': 1,
      'title': 'Мой заголовок',
      'body': 'Текст моего поста',
    });
  });

  testWidgets('ошибка сервера при отправке → SnackBar с понятным текстом',
      (tester) async {
    await _pumpPage(tester, (o) async {
      if (o.method == 'POST') return jsonResponse({}, status: 500);
      return _handler(o);
    });

    await _selectAuthor(tester, 'Борис Ли');
    await tester.enterText(_field('Заголовок'), 'Заголовок поста');
    await tester.enterText(_field('Текст'), 'Текст моего поста');
    await tester.tap(find.text('Опубликовать'));
    await tester.pumpAndSettle();

    expect(find.text('Ошибка на сервере (500). Попробуйте позже.'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('авторы не загрузились: «Повторить» открывает форму',
      (tester) async {
    var fail = true;
    await _pumpPage(tester, (o) async {
      if (fail) return jsonResponse({'error': 'not found'}, status: 404);
      return _handler(o);
    });

    expect(find.text('Не удалось загрузить список авторов'), findsOneWidget);
    expect(find.text('Данные не найдены (ошибка 404).'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('Опубликовать'), findsOneWidget);
  });
}
