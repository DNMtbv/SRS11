import '../../../core/error/error_handler.dart';
import '../../../core/error/exceptions.dart';
import '../../../models/comment_model.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import 'posts_api.dart';

/// Сетевой источник постов. Возвращает DTO, бросает только [DataException].
abstract interface class PostsRemoteDataSource {
  Future<List<PostModel>> getPosts({
    required int page,
    required int limit,
    required String order,
    int? userId,
  });

  Future<PostModel> getPost(int id);

  Future<List<CommentModel>> getComments(int postId);

  Future<PostModel> createPost(CreatePostRequest request);

  Future<List<UserModel>> getUsers();

  Future<UserModel> getUser(int id);
}

class PostsRemoteDataSourceImpl implements PostsRemoteDataSource {
  const PostsRemoteDataSourceImpl(this._api);

  final PostsApi _api;

  @override
  Future<List<PostModel>> getPosts({
    required int page,
    required int limit,
    required String order,
    int? userId,
  }) =>
      _call(() => userId == null
          ? _api.getPosts(page: page, limit: limit, order: order)
          : _api.getPostsByUser(
              userId: userId,
              page: page,
              limit: limit,
              order: order,
            ));

  @override
  Future<PostModel> getPost(int id) => _call(() => _api.getPost(id));

  @override
  Future<List<CommentModel>> getComments(int postId) =>
      _call(() => _api.getComments(postId));

  @override
  Future<PostModel> createPost(CreatePostRequest request) =>
      _call(() => _api.createPost(request));

  @override
  Future<List<UserModel>> getUsers() => _call(_api.getUsers);

  @override
  Future<UserModel> getUser(int id) => _call(() => _api.getUser(id));

  /// DioException и ошибки разбора JSON → [DataException].
  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (e) {
      throw ErrorHandler.toDataException(e);
    }
  }
}
