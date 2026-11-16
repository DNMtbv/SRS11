import '../../../core/either.dart';
import '../../../core/error/error_handler.dart';
import '../../../core/error/failures.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../datasources/favorites_local_data_source.dart';
import '../mapper/post_mapper.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl(this._local, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final FavoritesLocalDataSource _local;
  final DateTime Function() _clock;

  @override
  Future<Either<Failure, List<Post>>> getFavorites() =>
      ErrorHandler.guard(() async {
        final items = [..._local.readAll()]
          ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
        return items.map((f) => f.toEntity()).toList();
      });

  @override
  Future<Either<Failure, Unit>> add(Post post) => ErrorHandler.guard(() async {
        final items = _local.readAll();
        if (items.any((f) => f.id == post.id)) return unit;
        await _local.saveAll([...items, post.toFavoriteModel(_clock())]);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> remove(int postId) =>
      ErrorHandler.guard(() async {
        final items = _local.readAll();
        await _local.saveAll(items.where((f) => f.id != postId).toList());
        return unit;
      });
}
