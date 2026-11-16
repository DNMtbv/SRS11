import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:practicevskodin/core/di/injection.dart';
import 'package:practicevskodin/core/notifications/notification_service.dart';
import 'package:practicevskodin/models/registered_user_model.dart';
import 'package:practicevskodin/src/data/datasources/registration_remote_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef FakeHandler = Future<ResponseBody> Function(RequestOptions options);

/// Mock-адаптер Dio: подменяет сеть и запоминает все запросы.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  FakeHandler handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  List<RequestOptions> requestsTo(String path) =>
      requests.where((r) => r.path == path).toList();
}

/// Вместо Firebase Realtime Database: запоминает сохранённых пользователей.
class FakeRegistrationRemote implements RegistrationRemoteDataSource {
  Object? error;
  Completer<String>? completer;
  final saved = <Map<String, dynamic>>[];

  @override
  Future<String> saveUser(RegisteredUserModel user) async {
    final e = error;
    if (e != null) throw e;
    saved.add(user.toJson());
    return completer?.future ?? Future.value('-Nkey${saved.length}');
  }
}

/// Вместо FCM + flutter_local_notifications.
class FakePushService implements PushNotificationService {
  final shown = <String>[];

  @override
  String? get token => 'fcm-token-123';

  @override
  Future<void> show({required String title, required String body}) async =>
      shown.add(body);
}

class TestEnv {
  TestEnv(this.adapter, this.prefs, this.registrationRemote, this.push);

  final FakeAdapter adapter;
  final SharedPreferences prefs;
  final FakeRegistrationRemote registrationRemote;
  final FakePushService push;
}

/// Поднимает настоящий DI-контейнер приложения, подменив только внешний
/// мир: сеть, SharedPreferences и Firebase.
Future<TestEnv> setUpTestDi(
  FakeHandler handler, {
  Map<String, Object> prefs = const {},
}) async {
  await getIt.reset();
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final adapter = FakeAdapter(handler);
  final remote = FakeRegistrationRemote();
  final push = FakePushService();
  await configureDependencies(
    preferences: sp,
    httpAdapter: adapter,
    retryDelay: Duration.zero,
    enableNetworkLogging: false,
    registrationRemote: remote,
    pushNotifications: push,
  );
  return TestEnv(adapter, sp, remote, push);
}

ResponseBody jsonResponse(Object? data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody rawResponse(String body, {int status = 200}) =>
    ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Map<String, dynamic> postJson(int id, {int userId = 1, String? title}) => {
      'id': id,
      'userId': userId,
      'title': title ?? 'Post title $id',
      'body': 'Body of post $id',
    };

Map<String, dynamic> userJson(int id, String name) => {
      'id': id,
      'name': name,
      'username': 'user$id',
      'email': 'user$id@mail.kz',
    };

Map<String, dynamic> commentJson(int id, int postId, String name) => {
      'postId': postId,
      'id': id,
      'name': name,
      'email': 'comment$id@mail.kz',
      'body': 'Comment body $id',
    };

/// Страница из [count] постов, начиная с id = (page - 1) * 10 + 1.
List<Map<String, dynamic>> pageJson(
  int page, {
  int count = 10,
  int userId = 1,
}) =>
    [
      for (var i = 0; i < count; i++)
        postJson((page - 1) * 10 + i + 1, userId: userId),
    ];

int queryInt(RequestOptions o, String key) =>
    int.parse(o.queryParameters[key].toString());

/// POST /posts отвечает телом запроса с id = 101, как JSONPlaceholder.
ResponseBody echoCreated(RequestOptions o) {
  final sent = o.data is String ? jsonDecode(o.data as String) : o.data;
  return jsonResponse({...sent as Map<String, dynamic>, 'id': 101}, status: 201);
}
