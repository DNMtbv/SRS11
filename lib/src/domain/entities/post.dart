import 'package:equatable/equatable.dart';

/// Пост — главная сущность приложения.
class Post extends Equatable {
  const Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.isLocal = false,
  });

  final int id;
  final int userId;
  final String title;
  final String body;

  /// Пост создан в приложении. JSONPlaceholder ничего не сохраняет,
  /// поэтому такой пост живёт только на устройстве.
  final bool isLocal;

  Post copyWith({int? id, bool? isLocal}) => Post(
        id: id ?? this.id,
        userId: userId,
        title: title,
        body: body,
        isLocal: isLocal ?? this.isLocal,
      );

  @override
  List<Object?> get props => [id, userId, title, body, isLocal];
}
