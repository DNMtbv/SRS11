import '../../../core/either.dart';
import '../../../core/error/failures.dart';
import '../../../core/usecase/usecase.dart';
import '../entities/post.dart';
import '../repositories/favorites_repository.dart';

/// Список избранного (новые сверху).
class GetFavoritesUseCase implements UseCase<List<Post>, NoParams> {
  const GetFavoritesUseCase(this._repository);

  final FavoritesRepository _repository;

  @override
  Future<Either<Failure, List<Post>>> call([
    NoParams params = const NoParams(),
  ]) =>
      _repository.getFavorites();
}

/// Добавить пост в избранное или убрать, если он уже там.
/// Возвращает обновлённый список.
class ToggleFavoriteUseCase implements UseCase<List<Post>, Post> {
  const ToggleFavoriteUseCase(this._repository);

  final FavoritesRepository _repository;

  @override
  Future<Either<Failure, List<Post>>> call(Post post) async {
    final current = await _repository.getFavorites();
    final favorites = current.rightOrNull;
    if (favorites == null) return Left(current.leftOrNull!);

    final isFavorite = favorites.any((p) => p.id == post.id);
    final changed = isFavorite
        ? await _repository.remove(post.id)
        : await _repository.add(post);
    final failure = changed.leftOrNull;
    if (failure != null) return Left(failure);

    return _repository.getFavorites();
  }
}
