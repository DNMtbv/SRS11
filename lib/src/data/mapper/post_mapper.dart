import '../../../models/favorite_post_model.dart';
import '../../../models/post_model.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/post_draft.dart';
import '../../domain/entities/posts_page.dart';

/// DTO → Entity.
extension PostModelMapper on PostModel {
  Post toEntity({bool isLocal = false}) => Post(
        id: id,
        userId: userId,
        title: title,
        body: body,
        isLocal: isLocal,
      );
}

/// Entity → DTO (для локального хранения).
extension PostEntityMapper on Post {
  PostModel toModel() =>
      PostModel(id: id, userId: userId, title: title, body: body);

  FavoritePostModel toFavoriteModel(DateTime savedAt) => FavoritePostModel(
        id: id,
        userId: userId,
        title: title,
        body: body,
        isLocal: isLocal,
        savedAt: savedAt,
      );
}

extension FavoritePostModelMapper on FavoritePostModel {
  Post toEntity() => Post(
        id: id,
        userId: userId,
        title: title,
        body: body,
        isLocal: isLocal,
      );
}

extension PostDraftMapper on PostDraft {
  CreatePostRequest toRequest() =>
      CreatePostRequest(userId: userId!, title: title, body: body);
}

/// Параметры запроса в формате API и ключ кэша.
extension PostsQueryMapper on PostsQuery {
  String get apiOrder => switch (order) {
        SortOrder.asc => 'asc',
        SortOrder.desc => 'desc',
      };

  /// У каждого набора фильтров своя первая страница в кэше.
  String get cacheKey => 'user=${userId ?? 'all'};order=$apiOrder';
}
