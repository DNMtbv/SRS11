import '../../../core/either.dart';
import '../../../core/error/failures.dart';
import '../entities/post.dart';

/// Избранные посты, хранятся на устройстве.
abstract interface class FavoritesRepository {
  /// Новые сверху.
  Future<Either<Failure, List<Post>>> getFavorites();

  Future<Either<Failure, Unit>> add(Post post);

  Future<Either<Failure, Unit>> remove(int postId);
}
