import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practicevskodin/core/di/injection.dart';
import 'package:practicevskodin/core/error/failures.dart';
import 'package:practicevskodin/src/domain/entities/post_draft.dart';
import 'package:practicevskodin/src/domain/entities/posts_page.dart';
import 'package:practicevskodin/src/domain/repositories/posts_repository.dart';

import '../helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PostsRepository repo() => getIt<PostsRepository>();

  test('страница загружается, превращается в Entity и кэшируется', () async {
    final env = await setUpTestDi((o) async => jsonResponse(pageJson(1)));

    final page = (await repo().getPosts(page: 1)).rightOrNull!;

    expect(page.items, hasLength(10));
    expect(page.items.first.id, 1);
    expect(page.items.first.isLocal, isFalse);
    expect(page.hasMore, isTrue);

    final request = env.adapter.requests.single;
    expect(request.path, '/posts');
    expect(request.queryParameters['_page'], 1);
    expect(request.queryParameters['_limit'], 10);
    expect(request.headers['X-Client'], 'posts-app/2.0');

    final cached = await repo().getCachedFirstPage(const PostsQuery());
    expect(cached!.items, page.items);
  });

  test('фильтр по автору и сортировка уходят параметрами запроса', () async {
    final env = await setUpTestDi(
      (o) async => jsonResponse(pageJson(1, count: 3, userId: 4)),
    );

    final page = (await repo().getPosts(
      page: 1,
      query: const PostsQuery(userId: 4, order: SortOrder.desc),
    ))
        .rightOrNull!;

    expect(page.items.every((p) => p.userId == 4), isTrue);
    expect(page.hasMore, isFalse, reason: 'пришло меньше pageSize');
    final q = env.adapter.requests.single.queryParameters;
    expect(q['userId'], 4);
    expect(q['_order'], 'desc');
  });

  test('500 → ServerFailure после 2 повторов (retry policy)', () async {
    final env = await setUpTestDi((o) async => jsonResponse({}, status: 500));

    final result = await repo().getPosts(page: 1);

    expect(result.leftOrNull, const ServerFailure(500));
    expect(env.adapter.requests, hasLength(3));
  });

  test('4xx не повторяются', () async {
    final env = await setUpTestDi((o) async => jsonResponse({}, status: 401));

    expect((await repo().getPost(1)).leftOrNull, isA<UnauthorizedFailure>());
    expect(env.adapter.requests, hasLength(1));
  });

  test('битый JSON → ParseFailure, сохранённый кэш не стирается', () async {
    final env = await setUpTestDi((o) async => jsonResponse(pageJson(1)));
    await repo().getPosts(page: 1);

    env.adapter.handler = (o) async => jsonResponse([
          {'id': 'oops', 'title': null},
        ]);
    expect((await repo().getPosts(page: 1)).leftOrNull, const ParseFailure());

    final cached = await repo().getCachedFirstPage(const PostsQuery());
    expect(cached!.items, hasLength(10));
  });

  group('без лишних запросов', () {
    test('два экрана одновременно просят авторов → один GET /users', () async {
      final users = Completer<ResponseBody>();
      final env = await setUpTestDi((o) => users.future);

      final first = repo().getAuthors();
      final second = repo().getAuthors();
      users.complete(jsonResponse([userJson(1, 'Анна'), userJson(2, 'Борис')]));

      expect((await first).rightOrNull, hasLength(2));
      expect((await second).rightOrNull, hasLength(2));
      // И повторный вызов позже тоже берётся из памяти.
      expect((await repo().getAuthors()).rightOrNull, hasLength(2));
      expect(env.adapter.requestsTo('/users'), hasLength(1));
    });

    test('известный автор не запрашивается через /users/{id}', () async {
      final env = await setUpTestDi(
        (o) async => jsonResponse([userJson(1, 'Анна'), userJson(2, 'Борис')]),
      );
      await repo().getAuthors();

      final author = (await repo().getAuthor(2)).rightOrNull!;

      expect(author.name, 'Борис');
      expect(env.adapter.requestsTo('/users/2'), isEmpty);
    });

    test('без сети авторы берутся из кэша, но сеть пробуется снова', () async {
      final env = await setUpTestDi(
        (o) async => jsonResponse([userJson(1, 'Анна')]),
      );
      await repo().getAuthors(); // наполнили кэш на диске
      final offline = await setUpTestDi(
        (o) async => throw DioException.connectionError(
          requestOptions: o,
          reason: 'offline',
        ),
        prefs: {
          for (final k in env.prefs.getKeys()) k: env.prefs.get(k)!,
        },
      );

      expect((await repo().getAuthors()).rightOrNull!.single.name, 'Анна');
      expect((await repo().getAuthors()).rightOrNull!.single.name, 'Анна');
      // Данные из кэша не запоминаются в памяти: оба вызова идут в сеть
      // (каждый — запрос + 2 повтора).
      expect(offline.adapter.requestsTo('/users'), hasLength(6));
    });
  });

  test('POST /posts: тело запроса, локальная копия с уникальным id', () async {
    final env = await setUpTestDi((o) async => echoCreated(o));

    final first = (await repo().createPost(
      const PostDraft(userId: 2, title: 'Новый пост', body: 'Текст поста'),
    ))
        .rightOrNull!;
    final second = (await repo().createPost(
      const PostDraft(userId: 2, title: 'Второй пост', body: 'Ещё текст'),
    ))
        .rightOrNull!;

    final request = env.adapter.requests.first;
    expect(request.method, 'POST');
    expect(request.data, {
      'userId': 2,
      'title': 'Новый пост',
      'body': 'Текст поста',
    });

    // Сервер оба раза ответил id = 101, локально id разные.
    expect(first.serverId, 101);
    expect(second.serverId, 101);
    expect(first.post.id, 101);
    expect(second.post.id, 102);

    final local = await repo().getLocalPosts();
    expect(local.map((p) => p.title), ['Второй пост', 'Новый пост']);
    expect(local.every((p) => p.isLocal), isTrue);
    // POST не повторяется retry policy.
    expect(env.adapter.requests, hasLength(2));
  });
}
