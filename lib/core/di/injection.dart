import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/api_constants.dart';
import '../../src/data/datasources/favorites_local_data_source.dart';
import '../../src/data/datasources/posts_api.dart';
import '../../src/data/datasources/posts_local_data_source.dart';
import '../../src/data/datasources/posts_remote_data_source.dart';
import '../../src/data/datasources/registration_local_data_source.dart';
import '../../src/data/datasources/registration_remote_data_source.dart';
import '../../src/data/repositories/favorites_repository_impl.dart';
import '../../src/data/repositories/notifications_repository_impl.dart';
import '../../src/data/repositories/posts_repository_impl.dart';
import '../../src/data/repositories/registration_repository_impl.dart';
import '../../src/domain/entities/post.dart';
import '../../src/domain/repositories/favorites_repository.dart';
import '../../src/domain/repositories/notifications_repository.dart';
import '../../src/domain/repositories/posts_repository.dart';
import '../../src/domain/repositories/registration_repository.dart';
import '../../src/domain/usecases/create_post_usecase.dart';
import '../../src/domain/usecases/favorites_usecases.dart';
import '../../src/domain/usecases/get_authors_usecase.dart';
import '../../src/domain/usecases/get_post_details_usecase.dart';
import '../../src/domain/usecases/get_posts_page_usecase.dart';
import '../../src/domain/usecases/local_posts_usecases.dart';
import '../../src/domain/usecases/registration_usecases.dart';
import '../../src/presentation/bloc/create_post/create_post_cubit.dart';
import '../../src/presentation/bloc/favorites/favorites_cubit.dart';
import '../../src/presentation/bloc/post_details/post_details_cubit.dart';
import '../../src/presentation/bloc/posts/posts_bloc.dart';
import '../../src/presentation/bloc/registration/registration_cubit.dart';
import '../firebase/firebase_initializer.dart';
import '../notifications/notification_service.dart';
import '../rest_client/rest_client.dart';

final getIt = GetIt.instance;

/// Единственное место, где создаются зависимости (composition root).
///
/// Порядок регистрации — снаружи внутрь, как в Clean Architecture:
/// внешние сервисы → data sources → репозитории → use cases → BLoC.
/// Ни экран, ни BLoC не создают репозитории и data sources сами.
///
/// Параметры нужны тестам: подменить сеть, хранилище и Firebase.
Future<void> configureDependencies({
  SharedPreferences? preferences,
  HttpClientAdapter? httpAdapter,
  Duration retryDelay = ApiConstants.retryBaseDelay,
  bool enableNetworkLogging = kDebugMode,
  RegistrationRemoteDataSource? registrationRemote,
  PushNotificationService? pushNotifications,
}) async {
  // ── 1. Внешние сервисы ────────────────────────────────────────────
  getIt.registerSingleton<SharedPreferences>(
    preferences ?? await SharedPreferences.getInstance(),
  );
  getIt.registerLazySingleton<RestClient>(
    () => RestClient(
      adapter: httpAdapter,
      retryDelay: retryDelay,
      enableLogging: enableNetworkLogging,
    ),
  );
  getIt.registerLazySingleton<PostsApi>(() => PostsApi(getIt<RestClient>().dio));

  if (registrationRemote == null || pushNotifications == null) {
    final firebaseReady = await FirebaseInitializer.initialize();
    registrationRemote ??= firebaseReady
        ? FirebaseRegistrationDataSource(FirebaseInitializer.database())
        : const UnavailableRegistrationDataSource();
    pushNotifications ??=
        await FirebaseInitializer.notifications(firebaseReady: firebaseReady);
  }
  getIt.registerSingleton<PushNotificationService>(pushNotifications);

  // ── 2. Data sources ───────────────────────────────────────────────
  getIt
    ..registerLazySingleton<PostsRemoteDataSource>(
      () => PostsRemoteDataSourceImpl(getIt()),
    )
    ..registerLazySingleton<PostsLocalDataSource>(
      () => PostsLocalDataSourceImpl(getIt()),
    )
    ..registerSingleton<RegistrationRemoteDataSource>(registrationRemote)
    ..registerLazySingleton<RegistrationLocalDataSource>(
      () => RegistrationLocalDataSourceImpl(getIt()),
    )
    ..registerLazySingleton<FavoritesLocalDataSource>(
      () => FavoritesLocalDataSourceImpl(getIt()),
    );

  // ── 3. Репозитории (Domain-контракт → Data-реализация) ───────────
  getIt
    ..registerLazySingleton<PostsRepository>(
      () => PostsRepositoryImpl(remote: getIt(), local: getIt()),
    )
    ..registerLazySingleton<RegistrationRepository>(
      () => RegistrationRepositoryImpl(remote: getIt(), local: getIt()),
    )
    ..registerLazySingleton<NotificationsRepository>(
      () => NotificationsRepositoryImpl(getIt()),
    )
    ..registerLazySingleton<FavoritesRepository>(
      () => FavoritesRepositoryImpl(getIt()),
    );

  // ── 4. Use cases ──────────────────────────────────────────────────
  getIt
    ..registerFactory(() => GetPostsPageUseCase(getIt()))
    ..registerFactory(() => GetCachedFirstPageUseCase(getIt()))
    ..registerFactory(() => GetLocalPostsUseCase(getIt()))
    ..registerFactory(() => const FilterPostsUseCase())
    ..registerFactory(() => GetAuthorsUseCase(getIt()))
    ..registerFactory(() => GetCachedAuthorsUseCase(getIt()))
    ..registerFactory(() => GetPostDetailsUseCase(getIt()))
    ..registerFactory(() => CreatePostUseCase(getIt()))
    ..registerFactory(() => RegisterUserUseCase(getIt(), getIt()))
    ..registerFactory(() => CheckRegistrationUseCase(getIt()))
    ..registerFactory(() => GetDeviceTokenUseCase(getIt()))
    ..registerFactory(() => GetFavoritesUseCase(getIt()))
    ..registerFactory(() => ToggleFavoriteUseCase(getIt()));

  // ── 5. State management ───────────────────────────────────────────
  getIt
    ..registerFactory(
      () => PostsBloc(
        getPostsPage: getIt(),
        getCachedFirstPage: getIt(),
        getLocalPosts: getIt(),
        getAuthors: getIt(),
        getCachedAuthors: getIt(),
        filterPosts: getIt(),
      ),
    )
    ..registerFactoryParam<PostDetailsCubit, Post, void>(
      (post, _) => PostDetailsCubit(getIt(), post),
    )
    ..registerFactory(
      () => CreatePostCubit(
        getAuthors: getIt(),
        getCachedAuthors: getIt(),
        createPost: getIt(),
      ),
    )
    ..registerFactory(() => RegistrationCubit(getIt(), getIt()))
    ..registerFactory(() => FavoritesCubit(getIt(), getIt()));
}
