import '../entities/post.dart';
import '../entities/posts_page.dart';
import '../repositories/posts_repository.dart';

/// Посты, созданные на этом устройстве.
class GetLocalPostsUseCase {
  const GetLocalPostsUseCase(this._repository);

  final PostsRepository _repository;

  Future<List<Post>> call() => _repository.getLocalPosts();
}

/// Правило «что видно в списке»: локальные посты сверху (с тем же
/// фильтром по автору, что и серверные), затем серверные; всё это
/// отфильтровано поиском по заголовку среди уже загруженного.
class FilterPostsUseCase {
  const FilterPostsUseCase();

  List<Post> call({
    required List<Post> remote,
    required List<Post> local,
    required PostsQuery query,
    required String search,
  }) {
    final userId = query.userId;
    final locals =
        userId == null ? local : local.where((p) => p.userId == userId);
    final all = [...locals, ...remote];

    final q = search.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((p) => p.title.toLowerCase().contains(q)).toList();
  }
}
