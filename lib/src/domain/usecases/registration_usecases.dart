import '../../../core/either.dart';
import '../../../core/error/failures.dart';
import '../../../core/usecase/usecase.dart';
import '../entities/registration_data.dart';
import '../repositories/notifications_repository.dart';
import '../repositories/registration_repository.dart';

/// Регистрация: проверить данные → сохранить вместе с токеном устройства →
/// уведомить пользователя. Возвращает ключ записи в базе.
class RegisterUserUseCase implements UseCase<String, RegistrationData> {
  const RegisterUserUseCase(this._registration, this._notifications);

  final RegistrationRepository _registration;
  final NotificationsRepository _notifications;

  @override
  Future<Either<Failure, String>> call(RegistrationData data) async {
    final invalid = data.validate();
    if (invalid.isNotEmpty) {
      return Left(ValidationFailure(
        fields: invalid.map((f) => f.name).toSet(),
      ));
    }

    final user = data.normalized();
    final result = await _registration.register(
      user,
      deviceToken: _notifications.deviceToken,
    );
    if (result.isRight) await _notifications.notifyRegistered(user.name);
    return result;
  }
}

/// Зарегистрирован ли пользователь на этом устройстве.
class CheckRegistrationUseCase {
  const CheckRegistrationUseCase(this._registration);

  final RegistrationRepository _registration;

  Future<bool> call() => _registration.isRegistered();
}

/// Токен устройства для тестовых push-уведомлений.
class GetDeviceTokenUseCase {
  const GetDeviceTokenUseCase(this._notifications);

  final NotificationsRepository _notifications;

  String? call() => _notifications.deviceToken;
}
