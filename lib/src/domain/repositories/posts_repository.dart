import '../../../core/either.dart';
import '../../../core/error/failures.dart';
import '../entities/author.dart';
import '../entities/comment.dart';
import '../entities/post.dart';
import '../entities/post_draft.dart';
import '../entities/posts_page.dart';

/// Договор: ЧТО нужно приложению от источника постов.
/// КАК это получить (Retrofit, кэш) — решает Data Layer.
abstract interface class PostsRepository {
  /// Страница постов с сервера. Первая страница сохраняется в кэш.
  Future<Either<Failure, PostsPage>> getPosts({
    required int page,
    PostsQuery query = const PostsQuery(),
  });

  /// Первая страница из кэша (null, если её нет).
  Future<PostsPage?> getCachedFirstPage(PostsQuery query);

  Future<Either<Failure, Post>> getPost(int id);

  Future<Either<Failure, List<Comment>>> getComments(int postId);

  /// Все авторы. Повторные вызовы не ходят в сеть, пока не попросят
  /// [forceRefresh]; при ошибке сети отдаётся кэш.
  Future<Either<Failure, List<Author>>> getAuthors({bool forceRefresh = false});

  /// Авторы из кэша без обращения к сети.
  Future<List<Author>> getCachedAuthors();

  Future<Either<Failure, Author>> getAuthor(int id);

  /// Отправляет пост на сервер и сохраняет его локально.
  Future<Either<Failure, CreatedPost>> createPost(PostDraft draft);

  /// Посты, созданные на этом устройстве.
  Future<List<Post>> getLocalPosts();
}
