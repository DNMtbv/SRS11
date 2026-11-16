import 'package:json_annotation/json_annotation.dart';

part 'post_model.g.dart';

/// DTO поста в формате API JSONPlaceholder. В Presentation не попадает:
/// репозиторий превращает его в Entity `Post` через mapper.
@JsonSerializable(checked: true)
class PostModel {
  const PostModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) =>
      _$PostModelFromJson(json);

  final int id;
  final int userId;
  final String title;
  final String body;

  Map<String, dynamic> toJson() => _$PostModelToJson(this);
}

/// Тело запроса POST /posts.
@JsonSerializable(createFactory: false)
class CreatePostRequest {
  const CreatePostRequest({
    required this.userId,
    required this.title,
    required this.body,
  });

  final int userId;
  final String title;
  final String body;

  Map<String, dynamic> toJson() => _$CreatePostRequestToJson(this);
}
