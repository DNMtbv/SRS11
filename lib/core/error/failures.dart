import 'package:equatable/equatable.dart';

/// Ошибки уровня Domain. Их возвращают репозитории и UseCase в `Left`.
///
/// Здесь нет текстов для пользователя и нет технических деталей:
/// понятное сообщение подбирает Presentation (`failure_message.dart`),
/// а исходное исключение пишется в лог в `ErrorHandler`.
sealed class Failure extends Equatable {
  const Failure();

  @override
  List<Object?> get props => [];
}

/// Нет интернета / сервер недоступен.
final class NetworkFailure extends Failure {
  const NetworkFailure();
}

/// Сервер не ответил вовремя.
final class TimeoutFailure extends Failure {
  const TimeoutFailure();
}

/// Ответ 5xx.
final class ServerFailure extends Failure {
  const ServerFailure([this.statusCode]);

  final int? statusCode;

  @override
  List<Object?> get props => [statusCode];
}

/// Ответ 401 / 403.
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([this.statusCode = 401]);

  final int statusCode;

  @override
  List<Object?> get props => [statusCode];
}

/// Неверный запрос: ответ 400/422 от сервера или данные не прошли
/// проверку правил Domain. [fields] — какие поля неверны (если известно).
final class ValidationFailure extends Failure {
  const ValidationFailure({this.statusCode, this.fields = const {}});

  final int? statusCode;
  final Set<String> fields;

  @override
  List<Object?> get props => [statusCode, fields];
}

/// Ответ 404.
final class NotFoundFailure extends Failure {
  const NotFoundFailure();
}

/// Сервер прислал данные, которые не удалось разобрать.
final class ParseFailure extends Failure {
  const ParseFailure();
}

/// Не удалось прочитать или записать локальные данные.
final class CacheFailure extends Failure {
  const CacheFailure();
}

/// Причина ошибки внешнего бэкенда (Firebase).
enum BackendIssue { notConfigured, permissionDenied, other }

/// Ошибка Firebase.
final class BackendFailure extends Failure {
  const BackendFailure(this.issue);

  final BackendIssue issue;

  @override
  List<Object?> get props => [issue];
}

/// Всё, что не удалось классифицировать.
final class UnknownFailure extends Failure {
  const UnknownFailure();
}
