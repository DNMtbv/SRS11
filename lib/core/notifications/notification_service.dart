import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../logger.dart';

/// Платформенный сервис уведомлений: FCM-токен и показ уведомления.
/// Domain о нём не знает — с ним работает `NotificationsRepositoryImpl`.
abstract interface class PushNotificationService {
  /// FCM-токен устройства (null, если Firebase недоступен).
  String? get token;

  Future<void> show({required String title, required String body});
}

/// Пуши в фоне/закрытом приложении. Notification-сообщения система
/// показывает сама, здесь только лог. Должна быть top-level функцией.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  AppLogger.info(
    'FCM в фоне: ${message.messageId} ${message.notification?.title}',
  );
}

/// FCM (получение пушей) + flutter_local_notifications (показ уведомлений,
/// когда приложение открыто).
class NotificationService implements PushNotificationService {
  NotificationService({
    this._messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _local = localNotifications ?? FlutterLocalNotificationsPlugin();

  /// null, если Firebase не инициализирован: тогда работают только
  /// локальные уведомления.
  final FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _local;

  /// Этот же id указан в AndroidManifest как канал по умолчанию для FCM.
  static const channel = AndroidNotificationChannel(
    'main_channel',
    'Основные уведомления',
    description: 'Регистрация и push-уведомления',
    importance: Importance.high,
  );

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'main_channel',
      'Основные уведомления',
      channelDescription: 'Регистрация и push-уведомления',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  String? _token;

  @override
  String? get token => _token;

  Future<void> init() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(channel);

    final messaging = _messaging;
    if (messaging == null) {
      // Без FCM разрешение (Android 13+) запрашиваем сами.
      await android?.requestNotificationsPermission();
      return;
    }

    final settings = await messaging.requestPermission();
    AppLogger.info(
      'Разрешение на уведомления: ${settings.authorizationStatus}',
    );

    // Классический FCM-токен: именно его принимает «Send test message»
    // в Firebase Console.
    try {
      // ignore: deprecated_member_use
      _token = await messaging.getToken();
      AppLogger.info('FCM token: $_token');
    } catch (e, s) {
      AppLogger.error('Не удалось получить FCM-токен', error: e, stackTrace: s);
    }
    // ignore: deprecated_member_use
    messaging.onTokenRefresh.listen((t) => _token = t);

    // Когда приложение открыто, система пуш не показывает — показываем сами.
    FirebaseMessaging.onMessage.listen((message) {
      AppLogger.info('FCM на переднем плане: ${message.messageId}');
      final n = message.notification;
      if (n == null) return;
      show(title: n.title ?? '', body: n.body ?? '');
    });
    FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => AppLogger.info('Открыто из пуша: ${m.messageId}'),
    );
  }

  @override
  Future<void> show({required String title, required String body}) =>
      _local.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title: title,
        body: body,
        notificationDetails: _details,
      );
}
