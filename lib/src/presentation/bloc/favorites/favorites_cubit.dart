import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/either.dart';
import '../../../../core/error/failures.dart';
import '../../../domain/entities/post.dart';
import '../../../domain/usecases/favorites_usecases.dart';

enum FavoritesStatus { initial, loading, success, empty, error }

class FavoritesState extends Equatable {
  const FavoritesState({
    this.status = FavoritesStatus.initial,
    this.favorites = const [],
    this.failure,
    this.actionFailure,
    this.pendingIds = const {},
  });

  final FavoritesStatus status;
  final List<Post> favorites;

  /// Не удалось загрузить список (полноэкранная ошибка).
  final Failure? failure;

  /// Не удалось добавить/убрать пост (показывается в SnackBar,
  /// список при этом остаётся).
  final Failure? actionFailure;

  /// Посты, для которых запись прямо сейчас идёт в хранилище.
  final Set<int> pendingIds;

  bool contains(int postId) => favorites.any((p) => p.id == postId);

  int get count => favorites.length;

  FavoritesState copyWith({
    FavoritesStatus? status,
    List<Post>? favorites,
    Failure? Function()? failure,
    Failure? Function()? actionFailure,
    Set<int>? pendingIds,
  }) =>
      FavoritesState(
        status: status ?? this.status,
        favorites: favorites ?? this.favorites,
        failure: failure != null ? failure() : this.failure,
        actionFailure:
            actionFailure != null ? actionFailure() : this.actionFailure,
        pendingIds: pendingIds ?? this.pendingIds,
      );

  @override
  List<Object?> get props =>
      [status, favorites, failure, actionFailure, pendingIds];
}

/// Избранное — общее для всего приложения (сердечко на карточке,
/// на экране поста и отдельный экран «Избранное»).
class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit(this._getFavorites, this._toggleFavorite)
      : super(const FavoritesState());

  final GetFavoritesUseCase _getFavorites;
  final ToggleFavoriteUseCase _toggleFavorite;

  Future<void> load() async {
    if (state.status == FavoritesStatus.loading) return;
    emit(state.copyWith(status: FavoritesStatus.loading));
    final result = await _getFavorites();
    if (isClosed) return;
    switch (result) {
      case Right(value: final favorites):
        emit(state.copyWith(
          status: _statusFor(favorites),
          favorites: favorites,
          failure: () => null,
        ));
      case Left(value: final failure):
        emit(state.copyWith(
          status: FavoritesStatus.error,
          failure: () => failure,
        ));
    }
  }

  Future<void> toggle(Post post) async {
    // Повторное нажатие, пока идёт запись, игнорируется.
    if (state.pendingIds.contains(post.id)) return;
    emit(state.copyWith(
      pendingIds: {...state.pendingIds, post.id},
      actionFailure: () => null,
    ));

    final result = await _toggleFavorite(post);
    if (isClosed) return;
    final pending = {...state.pendingIds}..remove(post.id);
    switch (result) {
      case Right(value: final favorites):
        emit(state.copyWith(
          status: _statusFor(favorites),
          favorites: favorites,
          pendingIds: pending,
          failure: () => null,
        ));
      case Left(value: final failure):
        emit(state.copyWith(
          pendingIds: pending,
          actionFailure: () => failure,
        ));
    }
  }

  static FavoritesStatus _statusFor(List<Post> favorites) =>
      favorites.isEmpty ? FavoritesStatus.empty : FavoritesStatus.success;
}
