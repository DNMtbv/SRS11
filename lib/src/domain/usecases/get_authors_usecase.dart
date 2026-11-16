import '../../../core/either.dart';
import '../../../core/error/failures.dart';
import '../../../core/usecase/usecase.dart';
import '../entities/author.dart';
import '../repositories/posts_repository.dart';

/// Список авторов для фильтра и формы создания поста.
class GetAuthorsUseCase implements UseCase<List<Author>, NoParams> {
  const GetAuthorsUseCase(this._repository);

  final PostsRepository _repository;

  @override
  Future<Either<Failure, List<Author>>> call([
    NoParams params = const NoParams(),
  ]) =>
      _repository.getAuthors();
}

/// Авторы из кэша — чтобы сразу показать имена, не дожидаясь сети.
class GetCachedAuthorsUseCase {
  const GetCachedAuthorsUseCase(this._repository);

  final PostsRepository _repository;

  Future<List<Author>> call() => _repository.getCachedAuthors();
}
