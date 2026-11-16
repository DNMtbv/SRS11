import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/error/failures.dart' show BackendIssue;
import '../../../models/registered_user_model.dart';

/// Удалённое хранилище пользователей. Бросает только [DataException].
abstract interface class RegistrationRemoteDataSource {
  /// Сохраняет пользователя и возвращает его ключ в базе.
  Future<String> saveUser(RegisteredUserModel user);
}

/// Firebase Realtime Database: каждый пользователь — узел /users/{pushKey}.
class FirebaseRegistrationDataSource implements RegistrationRemoteDataSource {
  const FirebaseRegistrationDataSource(this._database);

  final FirebaseDatabase _database;

  @override
  Future<String> saveUser(RegisteredUserModel user) async {
    try {
      final ref = _database.ref('users').push();
      // Без сети set() не завершается (запись ждёт в очереди SDK),
      // поэтому ограничиваем ожидание.
      await ref.set({
        ...user.toJson(),
        'createdAt': ServerValue.timestamp,
      }).timeout(const Duration(seconds: 15));
      return ref.key!;
    } on TimeoutException {
      throw const RequestTimeoutException();
    } on FirebaseException catch (e) {
      throw switch (e.code) {
        'permission-denied' =>
          const BackendException(BackendIssue.permissionDenied),
        'network-error' || 'disconnected' => const NetworkException(),
        _ => const BackendException(BackendIssue.other),
      };
    }
  }
}

/// Используется, если Firebase не удалось инициализировать
/// (нет google-services.json).
class UnavailableRegistrationDataSource
    implements RegistrationRemoteDataSource {
  const UnavailableRegistrationDataSource();

  @override
  Future<String> saveUser(RegisteredUserModel user) async =>
      throw const BackendException(BackendIssue.notConfigured);
}
