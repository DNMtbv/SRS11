import 'package:equatable/equatable.dart';

import 'author.dart';
import 'comment.dart';
import 'post.dart';

/// Всё, что показывает экран поста.
class PostDetails extends Equatable {
  const PostDetails({
    required this.post,
    required this.comments,
    this.author,
  });

  final Post post;

  /// null, если автора загрузить не удалось: пост всё равно показываем.
  final Author? author;
  final List<Comment> comments;

  @override
  List<Object?> get props => [post, author, comments];
}
