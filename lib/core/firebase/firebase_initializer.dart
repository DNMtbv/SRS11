import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../logger.dart';
import '../notifications/notification_service.dart';
import 'firebase_config.dart';

/// Запуск Firebase. Если google-services.json нет, приложение работает,
/// а регистрация сообщит об ошибке.
abstract final class FirebaseInitializer {
  static Future<bool> initialize() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      return true;
    } catch (e, s) {
      AppLogger.error('Firebase не инициализирован', error: e, stackTrace: s);
      return false;
    }
  }

  static FirebaseDatabase database() => realtimeDatabaseUrl == null
      ? FirebaseDatabase.instance
      : FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: realtimeDatabaseUrl,
        );

  static Future<NotificationService> notifications({
    required bool firebaseReady,
  }) async {
    final service = NotificationService(
      messaging: firebaseReady ? FirebaseMessaging.instance : null,
    );
    try {
      await service.init();
    } catch (e, s) {
      AppLogger.error('Уведомления не инициализированы', error: e, stackTrace: s);
    }
    return service;
  }
}
