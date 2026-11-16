import 'dart:math' as math;

import '../../../constants/api_constants.dart';
import '../../../core/either.dart';
import '../../../core/error/error_handler.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/error/failures.dart';
import '../../../core/logger.dart';
import '../../../models/post_model.dart';
import '../../domain/entities/author.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/post_draft.dart';
import '../../domain/entities/posts_page.dart';
import '../../domain/repositories/posts_repository.dart';
import '../datasources/posts_local_data_source.dart';
import '../datasources/posts_remote_data_source.dart';
import '../mapper/author_mapper.dart';
import '../mapper/comment_mapper.dart';
import '../mapper/post_mapper.dart';

/// Реализация [PostsRepository]: сеть + кэш на устройстве.
/// Наружу выходят только Entity и [Failure] — DTO и исключения остаются здесь.
class PostsRepositoryImpl implements PostsRepository {
  PostsRepositoryImpl({
    required this._remote,
    required this._local,
    this.pageSize = ApiConstants.pageSize,
  });

  final PostsRemoteDataSource _remote;
  final PostsLocalDataSource _local;
  final int pageSize;

  /// Авторы, полученные с сервера в этой сессии: повторно в сеть не ходим.
  List<Author>? _authors;

  /// Запрос авторов, который выполняется прямо сейчас. Если список
  /// одновременно нужен двум экранам, запрос уйдёт один.
  Future<Either<Failure, List<Author>>>? _authorsRequest;

  @override
  Future<Either<Failure, PostsPage>> getPosts({
    required int page,
    PostsQuery query = const PostsQuery(),
  }) =>
      ErrorHandler.guard(() async {
        final models = await _remote.getPosts(
          page: page,
          limit: pageSize,
          order: query.apiOrder,
          userId: query.userId,
        );
        if (page == 1) await _cacheFirstPage(query, models);
        return _toPage(models, page);
      });

  @override
  Future<PostsPage?> getCachedFirstPage(PostsQuery query) async {
    final models = _local.readFirstPage(query.cacheKey);
    return models == null ? null : _toPage(models, 1);
  }

  @override
  Future<Either<Failure, Post>> getPost(int id) => ErrorHandler.guard(
        () async => (await _remote.getPost(id)).toEntity(),
      );

  @override
  Future<Either<Failure, List<Comment>>> getComments(int postId) =>
      ErrorHandler.guard(() async {
        final models = await _remote.getComments(postId);
        return models.map((c) => c.toEntity()).toList();
      });

  @override
  Future<Either<Failure, List<Author>>> getAuthors({
    bool forceRefresh = false,
  }) {
    final memo = _authors;
    if (!forceRefresh && memo != null) return Future.value(Right(memo));
    return _authorsRequest ??=
        _loadAuthors().whenComplete(() => _authorsRequest = null);
  }

  Future<Either<Failure, List<Author>>> _loadAuthors() =>
      ErrorHandler.guard(() async {
        try {
          final models = await _remote.getUsers();
          await _safeCacheWrite(() => _local.saveUsers(models));
          return _authors = models.map((u) => u.toEntity()).toList();
        } on DataException {
          // Без сети отдаём кэш, но в память не кладём: в следующий раз
          // снова попробуем сервер.
          final cached = _local.readUsers();
          if (cached != null && cached.isNotEmpty) {
            return cached.map((u) => u.toEntity()).toList();
          }
          rethrow;
        }
      });

  @override
  Future<List<Author>> getCachedAuthors() async =>
      _authors ??
      (_local.readUsers() ?? const []).map((u) => u.toEntity()).toList();

  @override
  Future<Either<Failure, Author>> getAuthor(int id) async {
    // Автор уже известен — запрос GET /users/{id} не нужен.
    for (final a in _authors ?? const <Author>[]) {
      if (a.id == id) return Right(a);
    }
    return ErrorHandler.guard(() async {
      try {
        return (await _remote.getUser(id)).toEntity();
      } on DataException {
        for (final u in _local.readUsers() ?? const []) {
          if (u.id == id) return u.toEntity();
        }
        rethrow;
      }
    });
  }

  @override
  Future<Either<Failure, CreatedPost>> createPost(PostDraft draft) =>
      ErrorHandler.guard(() async {
        final created = await _remote.createPost(draft.toRequest());

        // JSONPlaceholder на любой POST отвечает id = 101, поэтому
        // локальным постам выдаём следующий свободный id: иначе их нельзя
        // различить (например, в избранном).
        final locals = _local.readLocalPosts();
        final maxLocalId = locals.fold<int>(0, (m, p) => math.max(m, p.id));
        final post = created
            .toEntity(isLocal: true)
            .copyWith(id: math.max(created.id, maxLocalId + 1));

        await _local.saveLocalPosts([post.toModel(), ...locals]);
        return CreatedPost(post: post, serverId: created.id);
      });

  @override
  Future<List<Post>> getLocalPosts() async => _local
      .readLocalPosts()
      .map((p) => p.toEntity(isLocal: true))
      .toList();

  PostsPage _toPage(List<PostModel> models, int page) => PostsPage(
        items: models.map((p) => p.toEntity()).toList(),
        page: page,
        hasMore: models.length == pageSize,
      );

  Future<void> _cacheFirstPage(PostsQuery query, List<PostModel> models) =>
      _safeCacheWrite(() => _local.saveFirstPage(query.cacheKey, models));

  /// Данные с сервера уже получены: сбой записи кэша не должен
  /// превращать успешный ответ в ошибку.
  Future<void> _safeCacheWrite(Future<void> Function() write) async {
    try {
      await write();
    } catch (e, s) {
      AppLogger.error('Не удалось записать кэш', error: e, stackTrace: s);
    }
  }
}
