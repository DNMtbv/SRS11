import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practicevskodin/core/di/injection.dart';
import 'package:practicevskodin/core/error/failures.dart';
import 'package:practicevskodin/src/domain/entities/post.dart';
import 'package:practicevskodin/src/domain/repositories/favorites_repository.dart';
import 'package:practicevskodin/src/presentation/app.dart';
import 'package:practicevskodin/src/presentation/bloc/favorites/favorites_cubit.dart';
import 'package:practicevskodin/src/presentation/widgets/post_card.dart';

import '../helpers/test_env.dart';

const _a = Post(id: 1, userId: 1, title: 'Первый', body: 'b');
const _b = Post(id: 2, userId: 1, title: 'Второй', body: 'b');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FavoritesRepository (SharedPreferences)', () {
    test('сохраняется между запусками, новые сверху', () async {
      final env = await setUpTestDi((o) async => jsonResponse(<Object>[]));
      final repo = getIt<FavoritesRepository>();
      await repo.add(_a);
      await repo.add(_b);
      await repo.add(_a); // дубликат не добавляется

      // «Перезапуск»: новый DI-контейнер с теми же данными на диске.
      await setUpTestDi(
        (o) async => jsonResponse(<Object>[]),
        prefs: {for (final k in env.prefs.getKeys()) k: env.prefs.get(k)!},
      );
      final favorites =
          (await getIt<FavoritesRepository>().getFavorites()).rightOrNull!;

      expect(favorites.map((p) => p.id), [2, 1]);
    });

    test('повреждённые данные → CacheFailure, а не падение', () async {
      await setUpTestDi(
        (o) async => jsonResponse(<Object>[]),
        prefs: {'favorites.posts': '{oops'},
      );

      final result = await getIt<FavoritesRepository>().getFavorites();

      expect(result.leftOrNull, const CacheFailure());
    });
  });

  group('FavoritesCubit', () {
    test('loading → empty → success → empty', () async {
      await setUpTestDi((o) async => jsonResponse(<Object>[]));
      final cubit = getIt<FavoritesCubit>();

      await cubit.load();
      expect(cubit.state.status, FavoritesStatus.empty);

      await cubit.toggle(_a);
      expect(cubit.state.status, FavoritesStatus.success);
      expect(cubit.state.contains(1), isTrue);

      await cubit.toggle(_a);
      expect(cubit.state.status, FavoritesStatus.empty);
      await cubit.close();
    });

    test('двойное нажатие не меняет состояние дважды', () async {
      await setUpTestDi((o) async => jsonResponse(<Object>[]));
      final cubit = getIt<FavoritesCubit>();
      await cubit.load();

      await Future.wait([cubit.toggle(_a), cubit.toggle(_a)]);

      expect(cubit.state.favorites, [_a]);
      expect(cubit.state.pendingIds, isEmpty);
      await cubit.close();
    });

    test('ошибка загрузки → error с CacheFailure', () async {
      await setUpTestDi(
        (o) async => jsonResponse(<Object>[]),
        prefs: {'favorites.posts': 'not json'},
      );
      final cubit = getIt<FavoritesCubit>();

      await cubit.load();

      expect(cubit.state.status, FavoritesStatus.error);
      expect(cubit.state.failure, const CacheFailure());
      await cubit.close();
    });
  });

  testWidgets('♡ на карточке → пост на экране «Избранное» и счётчик',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    await setUpTestDi((o) async {
      if (o.path == '/users') return jsonResponse([userJson(1, 'Анна Ким')]);
      if (queryInt(o, '_page') > 1) return jsonResponse(<Object>[]);
      return jsonResponse([
        postJson(1, title: 'Flutter и Dart'),
        postJson(2, title: 'Всё про Retrofit'),
      ]);
    });
    await tester.pumpWidget(const PostsApp(isRegistered: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('favorite-2')));
    await tester.pumpAndSettle();

    // Бейдж со счётчиком в AppBar.
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('1')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Избранное'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Избранное'), findsOneWidget);
    expect(find.byType(PostCard), findsOneWidget);
    expect(find.text('Всё про Retrofit'), findsOneWidget);
    expect(find.text('Анна Ким'), findsOneWidget);

    // Убрать прямо с экрана избранного → пустое состояние.
    await tester.tap(find.byKey(const ValueKey('favorite-2')));
    await tester.pumpAndSettle();
    expect(find.text('В избранном пока пусто'), findsOneWidget);
  });
}
