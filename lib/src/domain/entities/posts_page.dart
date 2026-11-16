import 'package:equatable/equatable.dart';

import 'post.dart';

enum SortOrder { asc, desc }

/// Параметры серверного запроса списка. При их смене пагинация сбрасывается.
class PostsQuery extends Equatable {
  const PostsQuery({this.userId, this.order = SortOrder.asc});

  /// Фильтр по автору (null — все авторы).
  final int? userId;
  final SortOrder order;

  bool get isDefault => userId == null && order == SortOrder.asc;

  @override
  List<Object?> get props => [userId, order];
}

/// Одна страница списка постов.
class PostsPage extends Equatable {
  const PostsPage({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  final List<Post> items;

  /// Номер страницы, начиная с 1.
  final int page;

  /// Есть ли следующая страница.
  final bool hasMore;

  @override
  List<Object?> get props => [items, page, hasMore];
}
