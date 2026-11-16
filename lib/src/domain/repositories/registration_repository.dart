import '../../../core/either.dart';
import '../../../core/error/failures.dart';
import '../entities/registration_data.dart';

abstract interface class RegistrationRepository {
  Future<bool> isRegistered();

  /// Сохраняет пользователя и возвращает ключ его записи в базе.
  Future<Either<Failure, String>> register(
    RegistrationData data, {
    String? deviceToken,
  });
}
