import '../../../core/either.dart';
import '../../../core/error/failures.dart';
import '../../../core/usecase/usecase.dart';
import '../entities/post_draft.dart';
import '../repositories/posts_repository.dart';

/// Создать пост. Неверный черновик на сервер не уходит.
class CreatePostUseCase implements UseCase<CreatedPost, PostDraft> {
  const CreatePostUseCase(this._repository);

  final PostsRepository _repository;

  @override
  Future<Either<Failure, CreatedPost>> call(PostDraft draft) async {
    final invalid = draft.validate();
    if (invalid.isNotEmpty) {
      return Left(ValidationFailure(
        fields: invalid.map((f) => f.name).toSet(),
      ));
    }
    return _repository.createPost(draft.normalized());
  }
}
