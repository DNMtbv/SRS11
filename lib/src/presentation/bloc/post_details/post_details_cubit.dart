import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/either.dart';
import '../../../../core/error/failures.dart';
import '../../../domain/entities/post.dart';
import '../../../domain/entities/post_details.dart';
import '../../../domain/usecases/get_post_details_usecase.dart';

sealed class PostDetailsState extends Equatable {
  const PostDetailsState();

  @override
  List<Object?> get props => [];
}

class PostDetailsLoading extends PostDetailsState {
  const PostDetailsLoading();
}

class PostDetailsLoaded extends PostDetailsState {
  const PostDetailsLoaded(this.details, {this.refreshFailure});

  final PostDetails details;

  /// Обновление не удалось: контент остаётся, ошибка — в SnackBar.
  final Failure? refreshFailure;

  @override
  List<Object?> get props => [details, refreshFailure];
}

class PostDetailsError extends PostDetailsState {
  const PostDetailsError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

class PostDetailsCubit extends Cubit<PostDetailsState> {
  PostDetailsCubit(this._getPostDetails, this._post)
      : super(const PostDetailsLoading());

  final GetPostDetailsUseCase _getPostDetails;
  final Post _post;

  Future<void>? _inFlight;

  /// Повторный вызов во время загрузки не создаёт второй запрос,
  /// а ждёт текущий (например, двойной «Повторить»).
  Future<void> load() => _inFlight ??= _load().whenComplete(() => _inFlight = null);

  Future<void> _load() async {
    if (state is! PostDetailsLoaded) emit(const PostDetailsLoading());
    final result = await _getPostDetails(_post);
    if (isClosed) return;
    switch (result) {
      case Right(value: final details):
        emit(PostDetailsLoaded(details));
      case Left(value: final failure):
        // При обновлении уже открытого поста ошибка не прячет контент.
        final current = state;
        emit(current is PostDetailsLoaded
            ? PostDetailsLoaded(current.details, refreshFailure: failure)
            : PostDetailsError(failure));
    }
  }
}
