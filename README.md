# СРС 11. Посты (JSONPlaceholder) на Clean Architecture

Это приложение из СРС 9 (`ROS1-main_backup_srs9`), переписанное по Clean Architecture.
Функции остались прежними: список постов с пагинацией, поиск, фильтр и
сортировка, кэш, экран поста с комментариями, создание поста, регистрация
в Firebase и push-уведомления. Новая функция — **избранное с хранением
на устройстве**.

## Запуск

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # *.g.dart (json_serializable, retrofit)
flutter run
flutter test
```

## Слои и зависимости

```
Presentation (pages, widgets, bloc)
      │  вызывает UseCase, получает Entity / Failure
      ▼
Domain (entities, repositories — абстракции, usecases)      ← ни Flutter, ни Dio, ни Firebase
      ▲
      │  implements
Data (datasources, mapper, repositories — реализации)
      │  DTO из lib/models, Dio из core/rest_client
      ▼
REST API / SharedPreferences / Firebase
```

Все зависимости направлены внутрь, к Domain. Это проверяет
`test/architecture_test.dart`: он падает, если Domain импортирует Flutter,
Dio, Firebase или Data, а Presentation импортирует Data, DTO или Dio.

## Структура

```
lib/
├── components/          общие виджеты состояний: LoadingView, MessageView, LocalBadge
├── constants/           ApiConstants (baseUrl, таймауты, pageSize), StorageKeys, AppTheme
├── models/              DTO в формате API и хранилища (json_serializable)
├── core/
│   ├── rest_client/     RestClient (единственный Dio) + interceptors: headers, retry, errors
│   ├── error/           failures.dart, exceptions.dart, error_handler.dart
│   ├── di/              injection.dart — GetIt, composition root
│   ├── usecase/         базовый интерфейс UseCase<T, Params>
│   ├── either.dart      Either<L, R> / Left / Right / Unit
│   ├── firebase/        инициализация Firebase
│   └── notifications/   FCM + локальные уведомления
├── src/
│   ├── data/
│   │   ├── datasources/ PostsApi (retrofit), Remote/Local data sources
│   │   ├── mapper/      DTO ⇄ Entity (extension-методы)
│   │   └── repositories/ *RepositoryImpl
│   ├── domain/
│   │   ├── entities/    Post, Author, Comment, PostDetails, PostsPage/Query, PostDraft, RegistrationData
│   │   ├── repositories/ абстрактные PostsRepository, FavoritesRepository, …
│   │   └── usecases/    одно бизнес-действие на класс
│   └── presentation/
│       ├── pages/       экраны
│       ├── widgets/     PostCard, FavoriteButton, FiltersPanel, CachedBanner
│       ├── bloc/        PostsBloc, PostDetailsCubit, CreatePostCubit, RegistrationCubit, FavoritesCubit
│       └── utils/       Failure → текст, валидаторы форм
└── main.dart
```

## Что изменилось по сравнению с СРС 9

| Было | Стало |
|---|---|
| `PostsRepository` — конкретный класс в data, BLoC зависит от него напрямую | Абстракция в `domain/repositories`, реализация `PostsRepositoryImpl` в data; BLoC вызывает только UseCase |
| Модели `Post`/`User` с `@JsonSerializable` доходили до виджетов | DTO (`lib/models`) остаются в Data, UI работает с Entity (`domain/entities`) через mapper |
| Зависимости собирались вручную в `main.dart`, экраны брали репозиторий через `context.read` | GetIt, `core/di/injection.dart`; регистрация по порядку: внешние сервисы → data sources → репозитории → use cases → BLoC |
| `AppException` с текстом для пользователя бросалось через все слои | `DataException` в Data → `Failure` в Domain (в `Left`) → текст в Presentation (`failure_message.dart`) |
| Логика экрана поста (локальный пост, комментарии, автор) жила в Cubit | `GetPostDetailsUseCase` |
| Поиск по заголовку — функция в presentation | `FilterPostsUseCase` |
| Правила длины title/body и нормализация регистрации — в UI и Cubit | `PostDraft` / `RegistrationData` в Domain; `CreatePostUseCase` и `RegisterUserUseCase` не пропускают неверные данные |

## Обработка ошибок

Ошибки обрабатываются в одном месте — `core/error/error_handler.dart`:

```
DioException / FormatException / TimeoutException / FirebaseException
   → ErrorHandler.toDataException()   NetworkException, ServerException(500), UnauthorizedException(401), …
   → ErrorHandler.toFailure()         NetworkFailure, ServerFailure, UnauthorizedFailure, …   (Left)
   → failure.message                  текст на экране
```

| Ситуация | Исключение Data | Failure | Что видит пользователь |
|---|---|---|---|
| Нет интернета | `NetworkException` | `NetworkFailure` | «Нет подключения к интернету…» |
| Ошибка сервера 5xx | `ServerException` | `ServerFailure` | «Ошибка на сервере (500)…» |
| 401 / 403 | `UnauthorizedException` | `UnauthorizedFailure` | «Нужна авторизация (ошибка 401)…» |
| 400 / 422 / прочие 4xx | `BadRequestException` | `ValidationFailure` | «Некорректный запрос (ошибка 400)» |
| Неверные данные формы | — | `ValidationFailure(fields)` | ошибки под полями |
| 404 | `NotFoundException` | `NotFoundFailure` | «Данные не найдены» |
| Таймаут | `RequestTimeoutException` | `TimeoutFailure` | «Сервер слишком долго не отвечает…» |
| Битый JSON | `ParseException` | `ParseFailure` | «Сервер прислал некорректные данные» |
| Ошибка SharedPreferences | `CacheException` | `CacheFailure` | «Не удалось прочитать или сохранить данные…» |
| Firebase | `BackendException` | `BackendFailure` | по причине: не настроен / нет доступа / другое |
| Пустой результат | — | — | **Empty State** («Постов нет», «В избранном пока пусто», «Авторов нет») |
| Всё остальное | `UnknownDataException` | `UnknownFailure` | «Что-то пошло не так…» |

Технические детали попадают только в лог (`AppLogger`). Тест
`error_handling_test.dart` проверяет, что ни в одном сообщении нет слов
`Exception`, `Dio`, `Socket`.

## State Management

Используется BLoC/Cubit. На каждом экране есть состояния Loading,
Success, Error и Empty, а также кнопка «Повторить» или pull-to-refresh.

Повторные запросы, которые не нужны, не отправляются:
- одна и та же страница списка не грузится дважды (`_loadingPage`);
- refresh или retry, пока первая страница уже грузится, игнорируется (`_firstPageInFlight`);
- ответы на устаревший фильтр отбрасываются (счётчик `_generation`);
- `GET /users` выполняется один раз за сессию, даже если авторы одновременно
  нужны списку и форме: запрос в полёте общий, результат хранится в памяти;
- если автор уже известен, экран поста не запрашивает `GET /users/{id}`;
- повторное нажатие «Опубликовать», «Зарегистрироваться» или ♡ во время
  запроса игнорируется.

## Новая функция: избранное

Функция сделана по тем же правилам, что и остальное приложение:

| Слой | Файлы |
|---|---|
| Domain | `FavoritesRepository` (абстракция), `GetFavoritesUseCase`, `ToggleFavoriteUseCase` |
| Data | `FavoritesLocalDataSource` (SharedPreferences), `FavoritePostModel`, `FavoritesRepositoryImpl`, mapper |
| Presentation | `FavoritesCubit` (общий на всё приложение), `FavoriteButton` (♡ на карточке и на экране поста), `FavoritesPage`, счётчик в AppBar |

Пост сохраняется целиком, поэтому экран «Избранное» открывается без сети.
Повреждённые данные дают `CacheFailure` и экран ошибки, приложение при этом не падает.

JSONPlaceholder на любой `POST /posts` отвечает `id = 101`, поэтому локально
созданным постам выдаётся следующий свободный id (101, 102, …). Иначе их нельзя
было бы различить в избранном.

## Тесты (`flutter test`)

| Файл | Что проверяет |
|---|---|
| `architecture_test.dart` | правило зависимостей по import'ам; экраны не создают репозитории |
| `core/error_handling_test.dart` | таблица ошибок: нет сети / 400 / 401 / 404 / 500 / таймаут / JSON / unknown; тексты без технических деталей |
| `data/posts_repository_test.dart` | Entity вместо DTO, кэш, retry, один `GET /users` на два вызова, уникальные id локальных постов |
| `data/models_mapper_test.dart` | DTO ⇄ JSON ⇄ Entity |
| `domain/usecases_test.dart` | UseCase с фейковыми репозиториями: без Dio, Flutter и SharedPreferences |
| `presentation/posts_bloc_test.dart` | пагинация, фильтры, кэш → сервер, без двойных запросов, Empty/Error |
| `presentation/favorites_test.dart` | хранение между запусками, повреждённые данные, cubit, widget-тест ♡ → «Избранное» |
| `presentation/registration_cubit_test.dart` | регистрация + push, ошибки Firebase, защита от двойной отправки |
| `presentation/posts_page_test.dart`, `create_post_page_test.dart` | widget-тесты экранов, тексты ошибок 401/404/500 |
| `presentation/validators_test.dart` | валидаторы форм |

В тестах поднимается тот же DI-контейнер, что и в приложении (`configureDependencies`).
Подменяется только внешний мир: сеть (`FakeAdapter`), SharedPreferences (mock)
и Firebase (фейковые data source и сервис уведомлений).

## Firebase: регистрация и push-уведомления

1. [Firebase Console](https://console.firebase.google.com) → **Add project** →
   **Add app → Android**, package name `com.example.practicevskodin`.
   Положите `google-services.json` в `android/app/`.
2. **Build → Realtime Database → Create database**, режим **Test**. Если база
   создана после скачивания `google-services.json`, впишите её URL в
   `lib/core/firebase/firebase_config.dart`.
3. `flutter run`. Зарегистрируйтесь: в Realtime Database появится
   `/users/-N…`, а на устройстве — уведомление.

Тестовый пуш: скопируйте FCM-токен внизу экрана регистрации, затем откройте
Firebase Console → **Messaging → Send test message**.

Без Firebase приложение тоже работает: регистрация покажет понятную ошибку
`BackendFailure(notConfigured)`.
