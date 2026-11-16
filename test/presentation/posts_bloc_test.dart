import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practicevskodin/core/di/injection.dart';
import 'package:practicevskodin/core/error/failures.dart';
import 'package:practicevskodin/src/domain/entities/post.dart';
import 'package:practicevskodin/src/presentation/bloc/posts/posts_bloc.dart';

import '../helpers/test_env.dart';

/// Отвечает на /posts страницами из 10 постов, на /users — пустым списком.
FakeHandler pagedHandler({int totalPages = 10}) => (o) async {
      if (o.path == '/users') return jsonResponse(<Object>[]);
      final page = queryInt(o, '_page');
      if (page > totalPages) return jsonResponse(<Object>[]);
      return jsonResponse(pageJson(page));
    };

Future<PostsState> waitFor(
  PostsBloc bloc,
  bool Function(PostsState) predicate,
) async {
  if (predicate(bloc.state)) return bloc.state;
  return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
}

/// BLoC берётся из DI — так же, как в приложении.
Future<PostsBloc> startedBloc() async {
  final bloc = getIt<PostsBloc>()..add(const PostsStarted());
  await waitFor(bloc, (s) => s.status == PostsStatus.success);
  return bloc;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('смена автора сбрасывает пагинацию и грузит /posts?userId=', () async {
    final env = await setUpTestDi((o) async {
      if (o.path == '/users') return jsonResponse(<Object>[]);
      final page = queryInt(o, '_page');
      if (o.queryParameters['userId'] != null) {
        return jsonResponse(pageJson(page, count: 4, userId: 3));
      }
      return jsonResponse(pageJson(page));
    });
    final bloc = await startedBloc();

    bloc.add(const PostsNextPageRequested());
    await waitFor(bloc, (s) => s.page == 2);
    expect(bloc.state.posts, hasLength(20));

    bloc.add(const PostsAuthorFilterChanged(3));
    final state = await waitFor(
      bloc,
      (s) => s.status == PostsStatus.success && s.query.userId == 3,
    );

    expect(state.page, 1);
    expect(state.posts, hasLength(4));
    expect(state.posts.every((p) => p.userId == 3), isTrue);
    expect(state.hasMore, isFalse);
    final last = env.adapter.requestsTo('/posts').last;
    expect(last.queryParameters['userId'], 3);
    expect(last.queryParameters['_page'], 1);
    await bloc.close();
  });

  test('поиск фильтрует загруженные посты без запросов к серверу', () async {
    final env = await setUpTestDi(pagedHandler());
    final bloc = await startedBloc();

    bloc.add(const PostsSearchChanged('title 1'));
    final state = await waitFor(bloc, (s) => s.search == 'title 1');

    // Загружены 1..10: подходят «Post title 1» и «Post title 10».
    expect(state.visiblePosts.map((p) => p.id), [1, 10]);
    expect(env.adapter.requestsTo('/posts'), hasLength(1));
    await bloc.close();
  });

  test('одна страница не грузится дважды', () async {
    final page2 = Completer<ResponseBody>();
    final env = await setUpTestDi((o) async {
      if (o.path == '/users') return jsonResponse(<Object>[]);
      final page = queryInt(o, '_page');
      if (page == 2) return page2.future;
      return jsonResponse(pageJson(page));
    });
    final bloc = await startedBloc();

    bloc
      ..add(const PostsNextPageRequested())
      ..add(const PostsNextPageRequested())
      ..add(const PostsNextPageRequested());
    await waitFor(bloc, (s) => s.pageStatus == PageLoadStatus.loading);
    bloc.add(const PostsNextPageRequested());

    page2.complete(jsonResponse(pageJson(2)));
    final state = await waitFor(
      bloc,
      (s) => s.page == 2 && s.pageStatus == PageLoadStatus.idle,
    );

    final page2Requests = env.adapter
        .requestsTo('/posts')
        .where((r) => queryInt(r, '_page') == 2);
    expect(page2Requests, hasLength(1));
    expect(state.posts.map((p) => p.id).toSet(), hasLength(20));
    await bloc.close();
  });

  test('повторный refresh во время обновления не шлёт второй запрос',
      () async {
    final env = await setUpTestDi(pagedHandler());
    final bloc = await startedBloc();

    final slow = Completer<ResponseBody>();
    env.adapter.handler = (o) => slow.future;
    bloc
      ..add(const PostsRefreshRequested())
      ..add(const PostsRefreshRequested())
      ..add(const PostsRetryRequested());
    await waitFor(bloc, (s) => s.isRefreshing);
    slow.complete(jsonResponse(pageJson(1)));
    await waitFor(bloc, (s) => !s.isRefreshing);

    final firstPage = env.adapter
        .requestsTo('/posts')
        .where((r) => queryInt(r, '_page') == 1);
    expect(firstPage, hasLength(2), reason: 'старт + один refresh');
    await bloc.close();
  });

  test('ошибка подгрузки страницы → «Повторить» грузит её снова', () async {
    var failPage2 = true;
    await setUpTestDi((o) async {
      if (o.path == '/users') return jsonResponse(<Object>[]);
      final page = queryInt(o, '_page');
      if (page == 2 && failPage2) return jsonResponse({}, status: 503);
      return jsonResponse(pageJson(page));
    });
    final bloc = await startedBloc();

    bloc.add(const PostsNextPageRequested());
    await waitFor(bloc, (s) => s.pageStatus == PageLoadStatus.error);
    expect(bloc.state.pageFailure, const ServerFailure(503));
    expect(bloc.state.posts, hasLength(10));

    failPage2 = false;
    bloc.add(const PostsNextPageRequested());
    final state = await waitFor(bloc, (s) => s.page == 2);
    expect(state.posts, hasLength(20));
    await bloc.close();
  });

  test('сначала кэш, затем сервер; ошибка сети кэш не стирает', () async {
    await setUpTestDi(
      (o) async => throw DioException.connectionError(
        requestOptions: o,
        reason: 'offline',
      ),
      prefs: {'cache.posts.user=all;order=asc': jsonEncode(pageJson(1))},
    );

    final bloc = getIt<PostsBloc>();
    final states = <PostsState>[];
    final sub = bloc.stream.listen(states.add);
    bloc.add(const PostsStarted());

    final state = await waitFor(
      bloc,
      (s) => s.status == PostsStatus.cached && !s.isRefreshing,
    );

    expect(
      states.any((s) => s.status == PostsStatus.cached && s.isRefreshing),
      isTrue,
      reason: 'кэш показан до ответа сервера',
    );
    expect(state.posts, hasLength(10));
    expect(state.failure, const NetworkFailure());
    await sub.cancel();
    await bloc.close();
  });

  test('нет сети и кэша → состояние error с NetworkFailure', () async {
    await setUpTestDi(
      (o) async => throw DioException.connectionError(
        requestOptions: o,
        reason: 'offline',
      ),
    );
    final bloc = getIt<PostsBloc>()..add(const PostsStarted());

    final state = await waitFor(bloc, (s) => s.status == PostsStatus.error);

    expect(state.failure, const NetworkFailure());
    await bloc.close();
  });

  test('пустой ответ → состояние empty', () async {
    await setUpTestDi((o) async => jsonResponse(<Object>[]));
    final bloc = getIt<PostsBloc>()..add(const PostsStarted());

    await waitFor(bloc, (s) => s.status == PostsStatus.empty);
    await bloc.close();
  });

  test('созданный пост появляется сверху и убирает empty', () async {
    await setUpTestDi((o) async => jsonResponse(<Object>[]));
    final bloc = getIt<PostsBloc>()..add(const PostsStarted());
    await waitFor(bloc, (s) => s.status == PostsStatus.empty);

    const post = Post(id: 101, userId: 1, title: 'Мой', body: 'b', isLocal: true);
    bloc.add(const PostsLocalPostAdded(post));
    final state = await waitFor(bloc, (s) => s.localPosts.isNotEmpty);

    expect(state.status, PostsStatus.success);
    expect(state.visiblePosts, [post]);
    await bloc.close();
  });
}
