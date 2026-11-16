part of 'posts_bloc.dart';

/// Состояние первой страницы / экрана целиком.
enum PostsStatus {
  initial,
  loading,
  success,

  /// Показаны данные из кэша (ещё не обновились или сервер недоступен).
  cached,

  /// Сервер вернул пустой список.
  empty,
  error,
}

/// Отдельное состояние подгрузки следующих страниц.
enum PageLoadStatus { idle, loading, error }

class PostsState extends Equatable {
  const PostsState({
    this.status = PostsStatus.initial,
    this.pageStatus = PageLoadStatus.idle,
    this.isRefreshing = false,
    this.posts = const [],
    this.localPosts = const [],
    this.visiblePosts = const [],
    this.authors = const [],
    this.query = const PostsQuery(),
    this.search = '',
    this.page = 0,
    this.hasMore = true,
    this.failure,
    this.pageFailure,
  });

  final PostsStatus status;
  final PageLoadStatus pageStatus;

  /// Идёт обновление первой страницы поверх уже показанных данных.
  final bool isRefreshing;

  /// Посты с сервера (или из кэша) в порядке загрузки.
  final List<Post> posts;

  /// Посты, созданные в приложении.
  final List<Post> localPosts;

  /// Что реально видно в списке. Считает `FilterPostsUseCase` в блоке.
  final List<Post> visiblePosts;

  final List<Author> authors;
  final PostsQuery query;
  final String search;

  /// Номер последней загруженной страницы.
  final int page;
  final bool hasMore;

  /// Ошибка первой страницы (для status == error или cached).
  final Failure? failure;

  /// Ошибка подгрузки следующей страницы.
  final Failure? pageFailure;

  bool get hasActiveFilters => search.isNotEmpty || !query.isDefault;

  Author? authorById(int id) {
    for (final a in authors) {
      if (a.id == id) return a;
    }
    return null;
  }

  PostsState copyWith({
    PostsStatus? status,
    PageLoadStatus? pageStatus,
    bool? isRefreshing,
    List<Post>? posts,
    List<Post>? localPosts,
    List<Post>? visiblePosts,
    List<Author>? authors,
    PostsQuery? query,
    String? search,
    int? page,
    bool? hasMore,
    Failure? Function()? failure,
    Failure? Function()? pageFailure,
  }) =>
      PostsState(
        status: status ?? this.status,
        pageStatus: pageStatus ?? this.pageStatus,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        posts: posts ?? this.posts,
        localPosts: localPosts ?? this.localPosts,
        visiblePosts: visiblePosts ?? this.visiblePosts,
        authors: authors ?? this.authors,
        query: query ?? this.query,
        search: search ?? this.search,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        failure: failure != null ? failure() : this.failure,
        pageFailure: pageFailure != null ? pageFailure() : this.pageFailure,
      );

  @override
  List<Object?> get props => [
        status,
        pageStatus,
        isRefreshing,
        posts,
        localPosts,
        visiblePosts,
        authors,
        query,
        search,
        page,
        hasMore,
        failure,
        pageFailure,
      ];
}
