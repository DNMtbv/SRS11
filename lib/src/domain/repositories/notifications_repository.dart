abstract interface class NotificationsRepository {
  /// Токен устройства для push-уведомлений (null, если недоступен).
  String? get deviceToken;

  /// Сообщает пользователю об успешной регистрации.
  /// Сбой показа уведомления не считается ошибкой регистрации,
  /// поэтому метод ничего не возвращает и не бросает.
  Future<void> notifyRegistered(String name);
}
