import 'package:flutter_test/flutter_test.dart';
import 'package:practicevskodin/core/either.dart';
import 'package:practicevskodin/core/error/failures.dart';
import 'package:practicevskodin/src/domain/entities/author.dart';
import 'package:practicevskodin/src/domain/entities/comment.dart';
import 'package:practicevskodin/src/domain/entities/post.dart';
import 'package:practicevskodin/src/domain/entities/post_draft.dart';
import 'package:practicevskodin/src/domain/entities/posts_page.dart';
import 'package:practicevskodin/src/domain/entities/registration_data.dart';
import 'package:practicevskodin/src/domain/repositories/favorites_repository.dart';
import 'package:practicevskodin/src/domain/repositories/notifications_repository.dart';
import 'package:practicevskodin/src/domain/repositories/posts_repository.dart';
import 'package:practicevskodin/src/domain/repositories/registration_repository.dart';
import 'package:practicevskodin/src/domain/usecases/create_post_usecase.dart';
import 'package:practicevskodin/src/domain/usecases/favorites_usecases.dart';
import 'package:practicevskodin/src/domain/usecases/get_post_details_usecase.dart';
import 'package:practicevskodin/src/domain/usecases/get_posts_page_usecase.dart';
import 'package:practicevskodin/src/domain/usecases/local_posts_usecases.dart';
import 'package:practicevskodin/src/domain/usecases/registration_usecases.dart';

// Domain тестируется без сети, Dio, Flutter и SharedPreferences:
// репозитории подменяются простыми фейками (Dependency Inversion).

const _post = Post(id: 3, userId: 2, title: 'Dart', body: 'Body');
const _author =
    Author(id: 2, name: 'Борис', username: 'boris', email: 'b@mail.kz');

class FakePostsRepository implements PostsRepository {
  Either<Failure, Post> post = const Right(_post);
  Either<Failure, List<Comment>> comments = const Right([]);
  Either<Failure, Author> author = const Right(_author);
  final calls = <String>[];

  @override
  Future<Either<Failure, Post>> getPost(int id) async {
    calls.add('getPost');
    return post;
  }

  @override
  Future<Either<Failure, List<Comment>>> getComments(int postId) async {
    calls.add('getComments');
    return comments;
  }

  @override
  Future<Either<Failure, Author>> getAuthor(int id) async {
    calls.add('getAuthor');
    return author;
  }

  @override
  Future<Either<Failure, CreatedPost>> createPost(PostDraft draft) async {
    calls.add('createPost:${draft.title}');
    return Right(CreatedPost(
      post: Post(id: 101, userId: draft.userId!, title: draft.title, body: draft.body, isLocal: true),
      serverId: 101,
    ));
  }

  @override
  Future<Either<Failure, PostsPage>> getPosts({
    required int page,
    PostsQuery query = const PostsQuery(),
  }) async {
    calls.add('getPosts:$page');
    return const Right(PostsPage(items: [], page: 1, hasMore: false));
  }

  @override
  Future<PostsPage?> getCachedFirstPage(PostsQuery query) async => null;

  @override
  Future<Either<Failure, List<Author>>> getAuthors({
    bool forceRefresh = false,
  }) async =>
      const Right([_author]);

  @override
  Future<List<Author>> getCachedAuthors() async => const [];

  @override
  Future<List<Post>> getLocalPosts() async => const [];
}

class FakeFavoritesRepository implements FavoritesRepository {
  final items = <Post>[];

  @override
  Future<Either<Failure, List<Post>>> getFavorites() async =>
      Right(List.of(items.reversed));

  @override
  Future<Either<Failure, Unit>> add(Post post) async {
    items.add(post);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> remove(int postId) async {
    items.removeWhere((p) => p.id == postId);
    return const Right(unit);
  }
}

class FakeRegistrationRepository implements RegistrationRepository {
  Either<Failure, String> result = const Right('-Nkey');
  RegistrationData? saved;
  String? savedToken;

  @override
  Future<bool> isRegistered() async => saved != null;

  @override
  Future<Either<Failure, String>> register(
    RegistrationData data, {
    String? deviceToken,
  }) async {
    saved = data;
    savedToken = deviceToken;
    return result;
  }
}

class FakeNotificationsRepository implements NotificationsRepository {
  final notified = <String>[];

  @override
  String? get deviceToken => 'token';

  @override
  Future<void> notifyRegistered(String name) async => notified.add(name);
}

void main() {
  group('GetPostDetailsUseCase', () {
    late FakePostsRepository repo;
    late GetPostDetailsUseCase useCase;

    setUp(() {
      repo = FakePostsRepository();
      useCase = GetPostDetailsUseCase(repo);
    });

    test('серверный пост: пост, комментарии и автор', () async {
      repo.comments = const Right([
        Comment(id: 1, postId: 3, name: 'n', email: 'e', body: 'b'),
      ]);

      final details = (await useCase(_post)).rightOrNull!;

      expect(details.post, _post);
      expect(details.author, _author);
      expect(details.comments, hasLength(1));
    });

    test('локальный пост не запрашивается с сервера', () async {
      final local = _post.copyWith(isLocal: true);

      final details = (await useCase(local)).rightOrNull!;

      expect(details.post, local);
      expect(details.comments, isEmpty);
      expect(repo.calls, ['getAuthor']);
    });

    test('автор не загрузился — пост всё равно показываем', () async {
      repo.author = const Left(NetworkFailure());

      final details = (await useCase(_post)).rightOrNull!;

      expect(details.author, isNull);
    });

    test('ошибка комментариев — ошибка всего экрана', () async {
      repo.comments = const Left(ServerFailure(500));

      expect((await useCase(_post)).leftOrNull, const ServerFailure(500));
    });
  });

  group('CreatePostUseCase', () {
    test('неверный черновик → ValidationFailure, на сервер не уходит', () async {
      final repo = FakePostsRepository();

      final result = await CreatePostUseCase(repo)(
        const PostDraft(userId: null, title: 'abc', body: 'short'),
      );

      expect(
        result.leftOrNull,
        const ValidationFailure(fields: {'author', 'title', 'body'}),
      );
      expect(repo.calls, isEmpty);
    });

    test('верный черновик отправляется без пробелов по краям', () async {
      final repo = FakePostsRepository();

      final result = await CreatePostUseCase(repo)(
        const PostDraft(userId: 1, title: '  Заголовок  ', body: 'Текст поста'),
      );

      expect(result.isRight, isTrue);
      expect(repo.calls, ['createPost:Заголовок']);
    });
  });

  test('GetPostsPageUseCase не запрашивает страницу 0', () async {
    final repo = FakePostsRepository();

    final result =
        await GetPostsPageUseCase(repo)(const GetPostsPageParams(page: 0));

    expect(result.leftOrNull, isA<ValidationFailure>());
    expect(repo.calls, isEmpty);
  });

  group('FilterPostsUseCase', () {
    const remote = [
      Post(id: 1, userId: 1, title: 'Flutter и Dart', body: 'b'),
      Post(id: 2, userId: 1, title: 'Retrofit', body: 'b'),
      Post(id: 3, userId: 2, title: 'Всё про DART', body: 'b'),
    ];
    const local = [
      Post(id: 101, userId: 2, title: 'Мой dart', body: 'b', isLocal: true),
      Post(id: 102, userId: 5, title: 'Чужой', body: 'b', isLocal: true),
    ];
    const filter = FilterPostsUseCase();

    test('локальные сверху, поиск без учёта регистра', () {
      final result = filter(
        remote: remote,
        local: local,
        query: const PostsQuery(),
        search: '  dart ',
      );
      expect(result.map((p) => p.id), [101, 1, 3]);
    });

    test('фильтр по автору применяется и к локальным постам', () {
      final result = filter(
        remote: const [],
        local: local,
        query: const PostsQuery(userId: 2),
        search: '',
      );
      expect(result.map((p) => p.id), [101]);
    });
  });

  test('ToggleFavoriteUseCase добавляет, повторный вызов убирает', () async {
    final toggle = ToggleFavoriteUseCase(FakeFavoritesRepository());

    expect((await toggle(_post)).rightOrNull, [_post]);
    expect((await toggle(_post)).rightOrNull, isEmpty);
  });

  group('RegisterUserUseCase', () {
    late FakeRegistrationRepository registration;
    late FakeNotificationsRepository notifications;
    late RegisterUserUseCase register;

    setUp(() {
      registration = FakeRegistrationRepository();
      notifications = FakeNotificationsRepository();
      register = RegisterUserUseCase(registration, notifications);
    });

    test('нормализует данные, сохраняет с токеном и уведомляет', () async {
      final result = await register(const RegistrationData(
        name: '  Динмухаммед ',
        email: 'Test@Mail.KZ',
        phone: '+7 700 123 45 67',
        city: ' ',
      ));

      expect(result.rightOrNull, '-Nkey');
      expect(
        registration.saved,
        const RegistrationData(
          name: 'Динмухаммед',
          email: 'test@mail.kz',
          phone: '+7 700 123 45 67',
        ),
      );
      expect(registration.savedToken, 'token');
      expect(notifications.notified, ['Динмухаммед']);
    });

    test('неверные данные → ValidationFailure, ничего не сохраняется', () async {
      final result = await register(
        const RegistrationData(name: 'A', email: 'bad', phone: '123'),
      );

      expect(
        result.leftOrNull,
        const ValidationFailure(fields: {'name', 'email', 'phone'}),
      );
      expect(registration.saved, isNull);
    });

    test('ошибка сохранения → уведомления нет', () async {
      registration.result =
          const Left(BackendFailure(BackendIssue.permissionDenied));

      final result = await register(const RegistrationData(
        name: 'Анна',
        email: 'a@mail.kz',
        phone: '87001234567',
      ));

      expect(result.isLeft, isTrue);
      expect(notifications.notified, isEmpty);
    });
  });
}
