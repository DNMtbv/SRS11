import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/either.dart';
import '../../../../core/error/failures.dart';
import '../../../domain/entities/author.dart';
import '../../../domain/entities/post.dart';
import '../../../domain/entities/posts_page.dart';
import '../../../domain/usecases/get_authors_usecase.dart';
import '../../../domain/usecases/get_posts_page_usecase.dart';
import '../../../domain/usecases/local_posts_usecases.dart';

part 'posts_event.dart';
part 'posts_state.dart';

/// Список постов. Работает только через UseCase: не знает ни про Dio,
/// ни про SharedPreferences, ни про формат JSON.
class PostsBloc extends Bloc<PostsEvent, PostsState> {
  PostsBloc({
    required this._getPostsPage,
    required this._getCachedFirstPage,
    required this._getLocalPosts,
    required this._getAuthors,
    required this._getCachedAuthors,
    required this._filterPosts,
  }) : super(const PostsState()) {
    on<PostsStarted>(_onStarted);
    on<PostsNextPageRequested>(_onNextPage);
    on<PostsRefreshRequested>((_, emit) => _loadFirstPage(emit, refresh: true));
    on<PostsRetryRequested>((_, emit) => _loadFirstPage(emit));
    on<PostsAuthorFilterChanged>(_onAuthorChanged);
    on<PostsSortChanged>(_onSortChanged);
    on<PostsSearchChanged>(
      (e, emit) => _emit(emit, state.copyWith(search: e.text)),
    );
    on<PostsFiltersReset>(_onFiltersReset);
    on<PostsLocalPostAdded>(_onLocalPostAdded);
  }

  final GetPostsPageUseCase _getPostsPage;
  final GetCachedFirstPageUseCase _getCachedFirstPage;
  final GetLocalPostsUseCase _getLocalPosts;
  final GetAuthorsUseCase _getAuthors;
  final GetCachedAuthorsUseCase _getCachedAuthors;
  final FilterPostsUseCase _filterPosts;

  /// Растёт при каждой перезагрузке первой страницы. Ответы со старым
  /// номером (например, после смены фильтра) отбрасываются.
  int _generation = 0;

  /// Первая страница для текущего запроса уже грузится: повторный
  /// refresh/retry не отправляет второй такой же запрос.
  bool _firstPageInFlight = false;

  /// Страница, которая грузится прямо сейчас: защита от двойной загрузки.
  int? _loadingPage;

  /// Каждое новое состояние проходит через правило фильтрации из Domain.
  void _emit(Emitter<PostsState> emit, PostsState next) {
    emit(next.copyWith(
      visiblePosts: _filterPosts(
        remote: next.posts,
        local: next.localPosts,
        query: next.query,
        search: next.search,
      ),
    ));
  }

  Future<void> _onStarted(PostsStarted event, Emitter<PostsState> emit) async {
    _emit(emit, state.copyWith(
      localPosts: await _getLocalPosts(),
      authors: await _getCachedAuthors(),
    ));
    await Future.wait([
      _loadFirstPage(emit),
      _loadAuthors(emit),
    ]);
  }

  Future<void> _loadAuthors(Emitter<PostsState> emit) async {
    final result = await _getAuthors();
    // Без списка авторов список постов всё равно работает.
    final authors = result.rightOrNull;
    if (authors != null) _emit(emit, state.copyWith(authors: authors));
  }

  /// Загружает первую страницу. Новый [query] применяется в том же emit,
  /// что и сброс страниц, чтобы не было промежуточного состояния.
  Future<void> _loadFirstPage(
    Emitter<PostsState> emit, {
    bool refresh = false,
    PostsQuery? query,
    String? search,
  }) async {
    final isNewQuery = query != null && query != state.query;
    if (_firstPageInFlight && !isNewQuery) return;

    final generation = ++_generation;
    _firstPageInFlight = true;
    _loadingPage = null;
    query ??= state.query;

    try {
      await _showPlaceholder(emit, query: query, search: search, refresh: refresh);

      final result = await _getPostsPage(
        GetPostsPageParams(page: 1, query: query),
      );
      if (generation != _generation) return;

      switch (result) {
        case Right(value: final page):
          _emit(emit, state.copyWith(
            status: page.items.isEmpty && state.localPosts.isEmpty
                ? PostsStatus.empty
                : PostsStatus.success,
            posts: page.items,
            page: 1,
            hasMore: page.hasMore,
            pageStatus: PageLoadStatus.idle,
            isRefreshing: false,
            failure: () => null,
            pageFailure: () => null,
          ));
        case Left(value: final failure):
          // Ошибка сети не стирает уже показанные данные.
          _emit(emit, state.copyWith(
            status: state.posts.isNotEmpty
                ? PostsStatus.cached
                : PostsStatus.error,
            isRefreshing: false,
            failure: () => failure,
          ));
      }
    } finally {
      if (generation == _generation) _firstPageInFlight = false;
    }
  }

  /// Что показать, пока идёт запрос: при pull-to-refresh — текущий список,
  /// иначе — сохранённую первую страницу или индикатор загрузки.
  Future<void> _showPlaceholder(
    Emitter<PostsState> emit, {
    required PostsQuery query,
    required String? search,
    required bool refresh,
  }) async {
    if (refresh && state.posts.isNotEmpty) {
      emit(state.copyWith(isRefreshing: true));
      return;
    }
    final cached = await _getCachedFirstPage(query);
    if (cached != null && cached.items.isNotEmpty) {
      _emit(emit, state.copyWith(
        query: query,
        search: search,
        status: PostsStatus.cached,
        posts: cached.items,
        page: 1,
        hasMore: cached.hasMore,
        pageStatus: PageLoadStatus.idle,
        isRefreshing: true,
        failure: () => null,
        pageFailure: () => null,
      ));
    } else {
      _emit(emit, state.copyWith(
        query: query,
        search: search,
        status: PostsStatus.loading,
        posts: const [],
        page: 0,
        hasMore: true,
        pageStatus: PageLoadStatus.idle,
        isRefreshing: false,
        failure: () => null,
        pageFailure: () => null,
      ));
    }
  }

  Future<void> _onNextPage(
    PostsNextPageRequested event,
    Emitter<PostsState> emit,
  ) async {
    final canLoad = (state.status == PostsStatus.success ||
            state.status == PostsStatus.cached) &&
        state.hasMore &&
        !state.isRefreshing &&
        state.pageStatus != PageLoadStatus.loading &&
        _loadingPage == null;
    if (!canLoad) return;

    final generation = _generation;
    final nextPage = state.page + 1;
    _loadingPage = nextPage;
    emit(state.copyWith(
      pageStatus: PageLoadStatus.loading,
      pageFailure: () => null,
    ));

    try {
      final result = await _getPostsPage(
        GetPostsPageParams(page: nextPage, query: state.query),
      );
      if (generation != _generation) return;

      switch (result) {
        case Right(value: final page):
          final knownIds = state.posts.map((p) => p.id).toSet();
          _emit(emit, state.copyWith(
            posts: [
              ...state.posts,
              ...page.items.where((p) => !knownIds.contains(p.id)),
            ],
            page: nextPage,
            hasMore: page.hasMore,
            pageStatus: PageLoadStatus.idle,
          ));
        case Left(value: final failure):
          emit(state.copyWith(
            pageStatus: PageLoadStatus.error,
            pageFailure: () => failure,
          ));
      }
    } finally {
      if (generation == _generation) _loadingPage = null;
    }
  }

  Future<void> _onAuthorChanged(
    PostsAuthorFilterChanged event,
    Emitter<PostsState> emit,
  ) async {
    if (event.userId == state.query.userId) return;
    await _loadFirstPage(
      emit,
      query: PostsQuery(userId: event.userId, order: state.query.order),
    );
  }

  Future<void> _onSortChanged(
    PostsSortChanged event,
    Emitter<PostsState> emit,
  ) async {
    if (event.order == state.query.order) return;
    await _loadFirstPage(
      emit,
      query: PostsQuery(userId: state.query.userId, order: event.order),
    );
  }

  Future<void> _onFiltersReset(
    PostsFiltersReset event,
    Emitter<PostsState> emit,
  ) async {
    if (state.query.isDefault) {
      _emit(emit, state.copyWith(search: ''));
    } else {
      await _loadFirstPage(emit, query: const PostsQuery(), search: '');
    }
  }

  void _onLocalPostAdded(PostsLocalPostAdded event, Emitter<PostsState> emit) {
    _emit(emit, state.copyWith(
      localPosts: [event.post, ...state.localPosts],
      status: state.status == PostsStatus.empty ? PostsStatus.success : null,
    ));
  }
}
