import 'package:json_annotation/json_annotation.dart';

part 'favorite_post_model.g.dart';

/// Пост в избранном: хранится целиком, чтобы экран «Избранное»
/// открывался без сети.
@JsonSerializable(checked: true)
class FavoritePostModel {
  const FavoritePostModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.isLocal,
    required this.savedAt,
  });

  factory FavoritePostModel.fromJson(Map<String, dynamic> json) =>
      _$FavoritePostModelFromJson(json);

  final int id;
  final int userId;
  final String title;
  final String body;
  final bool isLocal;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => _$FavoritePostModelToJson(this);
}
