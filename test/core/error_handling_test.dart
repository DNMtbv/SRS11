import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practicevskodin/core/di/injection.dart';
import 'package:practicevskodin/core/either.dart';
import 'package:practicevskodin/core/error/error_handler.dart';
import 'package:practicevskodin/core/error/exceptions.dart';
import 'package:practicevskodin/core/error/failures.dart';
import 'package:practicevskodin/src/domain/repositories/posts_repository.dart';
import 'package:practicevskodin/src/presentation/utils/failure_message.dart';

import '../helpers/test_env.dart';

/// Таблица из задания: HTTP-ответ → Failure.
Future<Failure> failureFor(FakeHandler handler) async {
  await setUpTestDi(handler);
  final result = await getIt<PostsRepository>().getPost(1);
  return result.leftOrNull!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HTTP-ошибки → иерархия Failure', () {
    test('нет интернета → NetworkFailure', () async {
      final f = await failureFor(
        (o) async => throw DioException.connectionError(
          requestOptions: o,
          reason: 'SocketException: Failed host lookup',
        ),
      );
      expect(f, const NetworkFailure());
    });

    test('500 → ServerFailure', () async {
      final f = await failureFor((o) async => jsonResponse({}, status: 500));
      expect(f, const ServerFailure(500));
    });

    test('401 → UnauthorizedFailure', () async {
      final f = await failureFor((o) async => jsonResponse({}, status: 401));
      expect(f, const UnauthorizedFailure(401));
    });

    test('400 → ValidationFailure', () async {
      final f = await failureFor((o) async => jsonResponse({}, status: 400));
      expect(f, const ValidationFailure(statusCode: 400));
    });

    test('404 → NotFoundFailure', () async {
      final f = await failureFor((o) async => jsonResponse({}, status: 404));
      expect(f, const NotFoundFailure());
    });

    test('таймаут → TimeoutFailure', () async {
      final f = await failureFor(
        (o) async => throw DioException.receiveTimeout(
          requestOptions: o,
          timeout: const Duration(seconds: 15),
        ),
      );
      expect(f, const TimeoutFailure());
    });

    test('битый JSON → ParseFailure', () async {
      final f = await failureFor((o) async => rawResponse('{not json'));
      expect(f, const ParseFailure());
    });

    test('неизвестная ошибка → UnknownFailure', () async {
      final f = await failureFor((o) async => throw StateError('boom'));
      expect(f, const UnknownFailure());
    });
  });

  group('ErrorHandler', () {
    test('guard: успех → Right, исключение → Left', () async {
      expect(await ErrorHandler.guard(() async => 42), const Right<Failure, int>(42));
      expect(
        await ErrorHandler.guard<int>(() async => throw const CacheException()),
        const Left<Failure, int>(CacheFailure()),
      );
    });

    test('dart:async TimeoutException → TimeoutFailure', () {
      expect(
        ErrorHandler.toFailure(TimeoutException('slow')),
        const TimeoutFailure(),
      );
    });

    test('403 тоже считается ошибкой авторизации, 422 — валидации', () {
      expect(ErrorHandler.fromStatusCode(403), isA<UnauthorizedException>());
      expect(ErrorHandler.fromStatusCode(422), isA<BadRequestException>());
      expect(ErrorHandler.fromStatusCode(503), isA<ServerException>());
    });
  });

  test('пользователь никогда не видит технический текст исключения', () {
    const all = <Failure>[
      NetworkFailure(),
      TimeoutFailure(),
      ServerFailure(500),
      UnauthorizedFailure(),
      ValidationFailure(statusCode: 400),
      ValidationFailure(fields: {'title'}),
      NotFoundFailure(),
      ParseFailure(),
      CacheFailure(),
      BackendFailure(BackendIssue.notConfigured),
      BackendFailure(BackendIssue.permissionDenied),
      BackendFailure(BackendIssue.other),
      UnknownFailure(),
    ];
    for (final f in all) {
      expect(f.message, isNotEmpty);
      expect(
        f.message,
        isNot(matches(RegExp('Exception|Error:|Dio|Socket|StackTrace'))),
        reason: '$f',
      );
    }
  });
}
