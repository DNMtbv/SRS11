import '../../../core/either.dart';
import '../../../core/error/failures.dart';
import '../../../core/usecase/usecase.dart';
import '../entities/post.dart';
import '../entities/post_details.dart';
import '../repositories/posts_repository.dart';

/// Открыть пост: сам пост, комментарии и автор.
///
/// Правила сценария:
/// * локального поста на сервере нет — показываем то, что есть, без запросов
///   за постом и комментариями;
/// * пост и комментарии грузятся параллельно, ошибка любого — ошибка экрана;
/// * автор необязателен: если не загрузился, пост всё равно показываем.
class GetPostDetailsUseCase implements UseCase<PostDetails, Post> {
  const GetPostDetailsUseCase(this._repository);

  final PostsRepository _repository;

  @override
  Future<Either<Failure, PostDetails>> call(Post post) async {
    if (post.isLocal) {
      final author = await _repository.getAuthor(post.userId);
      return Right(PostDetails(
        post: post,
        author: author.rightOrNull,
        comments: const [],
      ));
    }

    final postFuture = _repository.getPost(post.id);
    final commentsFuture = _repository.getComments(post.id);
    final postResult = await postFuture;
    final commentsResult = await commentsFuture;

    final fresh = postResult.rightOrNull;
    final comments = commentsResult.rightOrNull;
    if (fresh == null) return Left(postResult.leftOrNull!);
    if (comments == null) return Left(commentsResult.leftOrNull!);

    final author = await _repository.getAuthor(fresh.userId);
    return Right(PostDetails(
      post: fresh,
      author: author.rightOrNull,
      comments: comments,
    ));
  }
}
