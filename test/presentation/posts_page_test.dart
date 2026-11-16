import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practicevskodin/src/presentation/app.dart';
import 'package:practicevskodin/src/presentation/widgets/post_card.dart';

import '../helpers/test_env.dart';

/// Сервер с тремя постами двух авторов.
Future<ResponseBody> _handler(RequestOptions o) async {
  final path = o.path;
  if (path == '/users') {
    return jsonResponse([userJson(1, 'Анна Ким'), userJson(2, 'Борис Ли')]);
  }
  if (path == '/posts' && o.method == 'POST') return echoCreated(o);
  if (path == '/posts') {
    if (queryInt(o, '_page') > 1) return jsonResponse(<Object>[]);
    return jsonResponse([
      postJson(1, title: 'Flutter и Dart'),
      postJson(2, title: 'Всё про Retrofit'),
      postJson(3, userId: 2, title: 'Dart на практике'),
    ]);
  }
  if (path == '/posts/3') {
    return jsonResponse(postJson(3, userId: 2, title: 'Dart на практике'));
  }
  if (path == '/posts/3/comments') {
    return jsonResponse([commentJson(1, 3, 'Хороший пост')]);
  }
  return jsonResponse({'error': 'not found'}, status: 404);
}

Future<TestEnv> _pumpApp(WidgetTester tester, FakeHandler handler) async {
  // Высокий экран: иначе нижние элементы ListView не будут построены.
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);

  final env = await setUpTestDi(handler);
  await tester.pumpWidget(const PostsApp(isRegistered: true));
  await tester.pumpAndSettle();
  return env;
}

void main() {
  testWidgets('показывает заголовок, поиск, кнопку и карточки постов',
      (tester) async {
    await _pumpApp(tester, _handler);

    expect(find.widgetWithText(AppBar, 'Посты'), findsOneWidget);
    expect(find.text('Поиск по загруженным постам'), findsOneWidget);
    expect(find.text('Новый пост'), findsOneWidget);
    expect(find.byType(PostCard), findsNWidgets(3));
    // Имя автора берётся из /users, а не «Автор #2».
    expect(
      find.descendant(of: find.byType(PostCard), matching: find.text('Борис Ли')),
      findsOneWidget,
    );
  });

  testWidgets('поиск сужает список, а «Очистить» возвращает его', (tester) async {
    await _pumpApp(tester, _handler);

    await tester.enterText(find.byType(TextField).first, 'dart');
    await tester.pumpAndSettle();
    expect(find.byType(PostCard), findsNWidgets(2));
    expect(find.text('Всё про Retrofit'), findsNothing);

    await tester.tap(find.byTooltip('Очистить'));
    await tester.pumpAndSettle();
    expect(find.byType(PostCard), findsNWidgets(3));
  });

  testWidgets('карточка открывает пост; автор не запрашивается повторно',
      (tester) async {
    final env = await _pumpApp(tester, _handler);

    await tester.tap(find.text('Dart на практике'));
    await tester.pumpAndSettle();

    expect(find.text('Пост #3'), findsOneWidget);
    expect(find.text('Борис Ли'), findsOneWidget);
    expect(find.text('Комментарии (1)'), findsOneWidget);
    expect(find.text('Хороший пост'), findsOneWidget);
    // Автор уже был получен через GET /users — /users/2 не нужен.
    expect(env.adapter.requestsTo('/users/2'), isEmpty);
    expect(env.adapter.requestsTo('/users'), hasLength(1));

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(PostCard), findsNWidgets(3));
  });

  testWidgets('новый пост: форма → диалог → пост в списке с пометкой',
      (tester) async {
    await _pumpApp(tester, _handler);

    await tester.tap(find.text('Новый пост'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Анна Ким').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Заголовок'),
      'Мой первый пост',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Текст'),
      'Текст моего первого поста',
    );
    await tester.tap(find.text('Опубликовать'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('К списку'));
    await tester.pumpAndSettle();

    expect(find.byType(PostCard), findsNWidgets(4));
    expect(find.text('Мой первый пост'), findsOneWidget);
    expect(find.text('создан локально'), findsOneWidget);
  });

  testWidgets('401: понятный текст ошибки и «Повторить»', (tester) async {
    var fail = true;
    await _pumpApp(tester, (o) async {
      if (fail) return jsonResponse({'error': 'token expired'}, status: 401);
      return _handler(o);
    });

    expect(find.text('Не удалось загрузить посты'), findsOneWidget);
    expect(find.textContaining('Нужна авторизация (ошибка 401)'), findsOneWidget);
    expect(find.textContaining('token expired'), findsNothing);

    fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.byType(PostCard), findsNWidgets(3));
  });

  testWidgets('пустой ответ → Empty State', (tester) async {
    await _pumpApp(tester, (o) async => jsonResponse(<Object>[]));

    expect(find.text('Постов нет'), findsOneWidget);
    expect(find.byType(PostCard), findsNothing);
  });
}
