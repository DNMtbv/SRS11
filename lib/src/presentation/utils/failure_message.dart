import 'package:flutter/material.dart';

import '../../../core/error/failures.dart';

/// Единственное место, где [Failure] превращается в текст для пользователя.
/// Технический текст исключения сюда не попадает никогда.
extension FailureMessage on Failure {
  String get message => switch (this) {
        NetworkFailure() =>
          'Нет подключения к интернету. Проверьте сеть и попробуйте снова.',
        TimeoutFailure() =>
          'Сервер слишком долго не отвечает. Попробуйте позже.',
        ServerFailure(:final statusCode) => statusCode == null
            ? 'Ошибка на сервере. Попробуйте позже.'
            : 'Ошибка на сервере ($statusCode). Попробуйте позже.',
        UnauthorizedFailure(:final statusCode) =>
          'Нужна авторизация (ошибка $statusCode). Войдите в аккаунт снова.',
        ValidationFailure(:final statusCode) => statusCode == null
            ? 'Проверьте правильность заполнения полей.'
            : 'Некорректный запрос (ошибка $statusCode).',
        NotFoundFailure() => 'Данные не найдены (ошибка 404).',
        ParseFailure() => 'Сервер прислал некорректные данные.',
        CacheFailure() =>
          'Не удалось прочитать или сохранить данные на устройстве.',
        BackendFailure(:final issue) => switch (issue) {
            BackendIssue.notConfigured =>
              'Firebase не настроен: добавьте android/app/google-services.json '
                  'и перезапустите приложение.',
            BackendIssue.permissionDenied =>
              'Нет доступа к базе данных. Проверьте правила Realtime Database '
                  '(режим Test).',
            BackendIssue.other => 'Не удалось сохранить данные в Firebase.',
          },
        UnknownFailure() => 'Что-то пошло не так. Попробуйте ещё раз.',
      };

  IconData get icon => switch (this) {
        NetworkFailure() || TimeoutFailure() => Icons.wifi_off_rounded,
        ServerFailure() => Icons.dns_outlined,
        UnauthorizedFailure() => Icons.lock_outline,
        NotFoundFailure() => Icons.search_off_rounded,
        _ => Icons.error_outline,
      };
}
