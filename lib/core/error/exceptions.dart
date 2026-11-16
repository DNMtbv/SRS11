import 'failures.dart' show BackendIssue;

/// Исключения Data Layer. Data sources бросают только их;
/// репозиторий превращает их в [Failure] через `ErrorHandler`.
sealed class DataException implements Exception {
  const DataException();

  @override
  String toString() => runtimeType.toString();
}

final class NetworkException extends DataException {
  const NetworkException();
}

final class RequestTimeoutException extends DataException {
  const RequestTimeoutException();
}

/// 5xx.
final class ServerException extends DataException {
  const ServerException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'ServerException($statusCode)';
}

/// 401 / 403.
final class UnauthorizedException extends DataException {
  const UnauthorizedException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'UnauthorizedException($statusCode)';
}

/// 400, 422 и прочие 4xx, кроме 401/403/404.
final class BadRequestException extends DataException {
  const BadRequestException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'BadRequestException($statusCode)';
}

/// 404.
final class NotFoundException extends DataException {
  const NotFoundException();
}

/// Битый JSON / неожиданный формат ответа.
final class ParseException extends DataException {
  const ParseException();
}

/// Ошибка локального хранилища.
final class CacheException extends DataException {
  const CacheException();
}

/// Ошибка Firebase.
final class BackendException extends DataException {
  const BackendException(this.issue);

  final BackendIssue issue;

  @override
  String toString() => 'BackendException(${issue.name})';
}

final class UnknownDataException extends DataException {
  const UnknownDataException();
}
