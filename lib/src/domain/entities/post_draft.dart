import 'package:equatable/equatable.dart';

import 'post.dart';

/// Поле черновика поста, которое может быть заполнено неверно.
enum PostField { author, title, body }

/// Данные нового поста до отправки + правила их проверки.
///
/// Правила живут здесь, в Domain: их использует и `CreatePostUseCase`
/// (не пропустит неверный пост), и форма (покажет ошибку под полем).
class PostDraft extends Equatable {
  const PostDraft({
    required this.userId,
    required this.title,
    required this.body,
  });

  static const titleMin = 5;
  static const titleMax = 100;
  static const bodyMin = 10;
  static const bodyMax = 1000;

  final int? userId;
  final String title;
  final String body;

  /// Копия без лишних пробелов по краям.
  PostDraft normalized() =>
      PostDraft(userId: userId, title: title.trim(), body: body.trim());

  /// Неверно заполненные поля (пустое множество — всё в порядке).
  Set<PostField> validate() {
    final t = title.trim().length;
    final b = body.trim().length;
    return {
      if (userId == null) PostField.author,
      if (t < titleMin || t > titleMax) PostField.title,
      if (b < bodyMin || b > bodyMax) PostField.body,
    };
  }

  @override
  List<Object?> get props => [userId, title, body];
}

/// Результат создания поста.
class CreatedPost extends Equatable {
  const CreatedPost({required this.post, required this.serverId});

  /// Пост, сохранённый на устройстве (с уникальным локальным id).
  final Post post;

  /// id, который вернул сервер (JSONPlaceholder всегда отдаёт 101).
  final int serverId;

  @override
  List<Object?> get props => [post, serverId];
}
