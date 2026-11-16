import '../../../core/either.dart';
import '../../../core/error/failures.dart';
import '../../../core/usecase/usecase.dart';
import '../entities/posts_page.dart';
import '../repositories/posts_repository.dart';

class GetPostsPageParams {
  const GetPostsPageParams({
    required this.page,
    this.query = const PostsQuery(),
  });

  final int page;
  final PostsQuery query;
}

/// Загрузить одну страницу списка постов.
class GetPostsPageUseCase implements UseCase<PostsPage, GetPostsPageParams> {
  const GetPostsPageUseCase(this._repository);

  final PostsRepository _repository;

  @override
  Future<Either<Failure, PostsPage>> call(GetPostsPageParams params) async {
    // Страницы нумеруются с 1: неверный номер даже не отправляем на сервер.
    if (params.page < 1) return const Left(ValidationFailure());
    return _repository.getPosts(page: params.page, query: params.query);
  }
}

/// Сохранённая первая страница — чтобы показать её мгновенно,
/// пока идёт запрос к серверу (или если сети нет).
class GetCachedFirstPageUseCase {
  const GetCachedFirstPageUseCase(this._repository);

  final PostsRepository _repository;

  Future<PostsPage?> call(PostsQuery query) =>
      _repository.getCachedFirstPage(query);
}
