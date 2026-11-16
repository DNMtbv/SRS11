import 'dart:async';

import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';

import '../either.dart';
import '../logger.dart';
import 'exceptions.dart';
import 'failures.dart';

/// Централизованная обработка ошибок. Вся цепочка проходит через этот файл:
///
/// ```
/// DioException / FormatException / TimeoutException / …
///   → toDataException()  → DataException  (Data Layer, бросается)
///   → toFailure()        → Failure        (Domain, возвращается в Left)
///   → failure.message    → текст на экране (Presentation)
/// ```
abstract final class ErrorHandler {
  /// Выполняет [action] и упаковывает результат в Either.
  /// Используется всеми реализациями репозиториев.
  static Future<Either<Failure, T>> guard<T>(
    Future<T> Function() action,
  ) async {
    try {
      return Right(await action());
    } catch (error, stackTrace) {
      return Left(toFailure(error, stackTrace));
    }
  }

  /// Любая ошибка → [Failure]. Технические детали — только в лог.
  static Failure toFailure(Object error, [StackTrace? stackTrace]) {
    final exception = toDataException(error);
    AppLogger.error(
      'Ошибка: $exception',
      error: error,
      stackTrace: stackTrace,
    );
    return switch (exception) {
      NetworkException() => const NetworkFailure(),
      RequestTimeoutException() => const TimeoutFailure(),
      ServerException(:final statusCode) => ServerFailure(statusCode),
      UnauthorizedException(:final statusCode) =>
        UnauthorizedFailure(statusCode),
      BadRequestException(:final statusCode) =>
        ValidationFailure(statusCode: statusCode),
      NotFoundException() => const NotFoundFailure(),
      ParseException() => const ParseFailure(),
      CacheException() => const CacheFailure(),
      BackendException(:final issue) => BackendFailure(issue),
      UnknownDataException() => const UnknownFailure(),
    };
  }

  /// Любая ошибка → [DataException]. Используется в data sources
  /// и в `ErrorInterceptor`.
  static DataException toDataException(Object error) {
    if (error is DataException) return error;
    if (error is DioException) return _fromDio(error);
    if (error is TimeoutException) return const RequestTimeoutException();
    if (_isParseError(error)) return const ParseException();
    return const UnknownDataException();
  }

  static DataException _fromDio(DioException error) {
    final inner = error.error;
    // ErrorInterceptor уже положил сюда готовое исключение.
    if (inner is DataException) return inner;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const RequestTimeoutException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        return fromStatusCode(error.response?.statusCode ?? 0);
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
        return const UnknownDataException();
      case DioExceptionType.unknown:
        if (inner != null) {
          if (_isParseError(inner)) return const ParseException();
          // SocketException / HandshakeException без импорта dart:io.
          final text = inner.toString();
          if (text.contains('SocketException') ||
              text.contains('Failed host lookup') ||
              text.contains('Connection refused')) {
            return const NetworkException();
          }
        }
        return const UnknownDataException();
    }
  }

  /// HTTP-код → исключение. Таблица из задания:
  /// 400 → Validation, 401 → Unauthorized, 500 → Server.
  static DataException fromStatusCode(int code) {
    if (code == 401 || code == 403) return UnauthorizedException(code);
    if (code == 404) return const NotFoundException();
    if (code >= 500) return ServerException(code);
    if (code >= 400) return BadRequestException(code);
    return const UnknownDataException();
  }

  static bool _isParseError(Object error) =>
      error is FormatException ||
      error is CheckedFromJsonException ||
      error is TypeError;
}
