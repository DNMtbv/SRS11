import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/either.dart';
import '../../../../core/error/failures.dart';
import '../../../domain/entities/author.dart';
import '../../../domain/entities/post_draft.dart';
import '../../../domain/usecases/create_post_usecase.dart';
import '../../../domain/usecases/get_authors_usecase.dart';

enum AuthorsStatus { loading, success, empty, error }

enum SubmitStatus { idle, submitting, success, failure }

class CreatePostState extends Equatable {
  const CreatePostState({
    this.authorsStatus = AuthorsStatus.loading,
    this.authors = const [],
    this.submitStatus = SubmitStatus.idle,
    this.created,
    this.failure,
  });

  final AuthorsStatus authorsStatus;
  final List<Author> authors;
  final SubmitStatus submitStatus;

  /// Результат POST /posts.
  final CreatedPost? created;
  final Failure? failure;

  bool get isSubmitting => submitStatus == SubmitStatus.submitting;

  CreatePostState copyWith({
    AuthorsStatus? authorsStatus,
    List<Author>? authors,
    SubmitStatus? submitStatus,
    CreatedPost? created,
    Failure? failure,
  }) =>
      CreatePostState(
        authorsStatus: authorsStatus ?? this.authorsStatus,
        authors: authors ?? this.authors,
        submitStatus: submitStatus ?? this.submitStatus,
        created: created ?? this.created,
        failure: failure,
      );

  @override
  List<Object?> get props =>
      [authorsStatus, authors, submitStatus, created, failure];
}

class CreatePostCubit extends Cubit<CreatePostState> {
  CreatePostCubit({
    required this._getAuthors,
    required this._getCachedAuthors,
    required this._createPost,
  }) : super(const CreatePostState());

  final GetAuthorsUseCase _getAuthors;
  final GetCachedAuthorsUseCase _getCachedAuthors;
  final CreatePostUseCase _createPost;

  Future<void> loadAuthors() async {
    final cached = await _getCachedAuthors();
    if (cached.isNotEmpty) {
      emit(state.copyWith(authorsStatus: AuthorsStatus.success, authors: cached));
    } else {
      emit(state.copyWith(authorsStatus: AuthorsStatus.loading));
    }

    final result = await _getAuthors();
    if (isClosed) return;
    switch (result) {
      case Right(value: final authors):
        emit(state.copyWith(
          authorsStatus:
              authors.isEmpty ? AuthorsStatus.empty : AuthorsStatus.success,
          authors: authors,
        ));
      case Left(value: final failure):
        if (state.authors.isEmpty) {
          emit(state.copyWith(
            authorsStatus: AuthorsStatus.error,
            failure: failure,
          ));
        }
    }
  }

  Future<void> submit({
    required int? userId,
    required String title,
    required String body,
  }) async {
    // Двойное нажатие не отправит пост дважды.
    if (state.isSubmitting || state.submitStatus == SubmitStatus.success) {
      return;
    }
    emit(state.copyWith(submitStatus: SubmitStatus.submitting));

    final result = await _createPost(
      PostDraft(userId: userId, title: title, body: body),
    );
    if (isClosed) return;
    switch (result) {
      case Right(value: final created):
        emit(state.copyWith(submitStatus: SubmitStatus.success, created: created));
      case Left(value: final failure):
        emit(state.copyWith(submitStatus: SubmitStatus.failure, failure: failure));
    }
  }
}
