import 'package:json_annotation/json_annotation.dart';

part 'comment_model.g.dart';

/// DTO комментария из /posts/{id}/comments.
@JsonSerializable(checked: true)
class CommentModel {
  const CommentModel({
    required this.id,
    required this.postId,
    required this.name,
    required this.email,
    required this.body,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) =>
      _$CommentModelFromJson(json);

  final int id;
  final int postId;
  final String name;
  final String email;
  final String body;

  Map<String, dynamic> toJson() => _$CommentModelToJson(this);
}
