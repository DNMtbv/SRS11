import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../../../models/comment_model.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';

part 'posts_api.g.dart';

/// Описание REST API JSONPlaceholder. Реализацию генерирует retrofit_generator.
/// Используется только внутри [PostsRemoteDataSourceImpl].
@RestApi()
abstract class PostsApi {
  factory PostsApi(Dio dio, {String? baseUrl}) = _PostsApi;

  /// GET /posts?_page=1&_limit=10 — список постов с пагинацией.
  @GET('/posts')
  Future<List<PostModel>> getPosts({
    @Query('_page') required int page,
    @Query('_limit') required int limit,
    @Query('_sort') String sort = 'id',
    @Query('_order') String order = 'asc',
  });

  /// GET /posts?userId={id} — посты одного автора (тоже с пагинацией).
  @GET('/posts')
  Future<List<PostModel>> getPostsByUser({
    @Query('userId') required int userId,
    @Query('_page') required int page,
    @Query('_limit') required int limit,
    @Query('_sort') String sort = 'id',
    @Query('_order') String order = 'asc',
  });

  @GET('/posts/{id}')
  Future<PostModel> getPost(@Path('id') int id);

  @GET('/posts/{id}/comments')
  Future<List<CommentModel>> getComments(@Path('id') int postId);

  @POST('/posts')
  Future<PostModel> createPost(@Body() CreatePostRequest request);

  @GET('/users')
  Future<List<UserModel>> getUsers();

  @GET('/users/{id}')
  Future<UserModel> getUser(@Path('id') int id);
}
