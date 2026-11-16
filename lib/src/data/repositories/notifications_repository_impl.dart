import '../../../core/logger.dart';
import '../../../core/notifications/notification_service.dart';
import '../../domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  const NotificationsRepositoryImpl(this._service);

  final PushNotificationService _service;

  @override
  String? get deviceToken => _service.token;

  @override
  Future<void> notifyRegistered(String name) async {
    try {
      await _service.show(
        title: 'Регистрация завершена',
        body: 'Добро пожаловать, $name! Данные сохранены в Firebase.',
      );
    } catch (e, s) {
      // Данные уже сохранены — сбой уведомления регистрацию не отменяет.
      AppLogger.error('Не удалось показать уведомление', error: e, stackTrace: s);
    }
  }
}
