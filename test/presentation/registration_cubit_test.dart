import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practicevskodin/core/di/injection.dart';
import 'package:practicevskodin/core/error/exceptions.dart';
import 'package:practicevskodin/core/error/failures.dart';
import 'package:practicevskodin/src/data/datasources/registration_remote_data_source.dart';
import 'package:practicevskodin/src/data/repositories/notifications_repository_impl.dart';
import 'package:practicevskodin/src/data/repositories/registration_repository_impl.dart';
import 'package:practicevskodin/src/domain/usecases/registration_usecases.dart';
import 'package:practicevskodin/src/presentation/bloc/registration/registration_cubit.dart';
import 'package:practicevskodin/src/presentation/utils/failure_message.dart';

import '../helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestEnv env;
  late RegistrationCubit cubit;

  setUp(() async {
    env = await setUpTestDi((o) async => jsonResponse(<Object>[]));
    cubit = getIt<RegistrationCubit>();
  });

  tearDown(() => cubit.close());

  Future<void> submit() => cubit.submit(
        name: '  Динмухаммед ',
        email: 'Test@Mail.KZ',
        phone: '+7 700 123 45 67',
        city: ' ',
      );

  test('успешная регистрация: запись в базу, push и отметка на устройстве',
      () async {
    final isRegistered = getIt<CheckRegistrationUseCase>();
    expect(await isRegistered(), isFalse);
    expect(cubit.state.deviceToken, 'fcm-token-123');

    await submit();

    expect(cubit.state.status, RegistrationStatus.success);
    expect(cubit.state.userKey, '-Nkey1');
    expect(env.registrationRemote.saved.single, {
      'name': 'Динмухаммед',
      'email': 'test@mail.kz',
      'phone': '+7 700 123 45 67',
      'fcmToken': 'fcm-token-123',
    });
    expect(env.push.shown.single, contains('Динмухаммед'));
    expect(await isRegistered(), isTrue);
  });

  test('нет доступа к базе → понятная ошибка, push не отправляется', () async {
    env.registrationRemote.error =
        const BackendException(BackendIssue.permissionDenied);

    await submit();

    expect(cubit.state.status, RegistrationStatus.failure);
    expect(
      cubit.state.failure,
      const BackendFailure(BackendIssue.permissionDenied),
    );
    expect(cubit.state.failure!.message, contains('режим Test'));
    expect(env.push.shown, isEmpty);
  });

  test('сырое исключение Firebase тоже не доходит до UI', () async {
    env.registrationRemote.error = FirebaseException(
      plugin: 'firebase_database',
      code: 'weird',
      message: 'internal stack details',
    );

    await submit();

    expect(cubit.state.failure, const UnknownFailure());
    expect(cubit.state.failure!.message, isNot(contains('internal')));
  });

  test('Firebase не настроен → BackendFailure(notConfigured)', () async {
    final notConfigured = RegistrationCubit(
      RegisterUserUseCase(
        RegistrationRepositoryImpl(
          remote: const UnavailableRegistrationDataSource(),
          local: getIt(),
        ),
        NotificationsRepositoryImpl(env.push),
      ),
      getIt(),
    );

    await notConfigured.submit(
      name: 'Анна',
      email: 'a@mail.kz',
      phone: '87001234567',
    );

    expect(
      notConfigured.state.failure,
      const BackendFailure(BackendIssue.notConfigured),
    );
    expect(
      notConfigured.state.failure!.message,
      contains('google-services.json'),
    );
    await notConfigured.close();
  });

  test('повторное нажатие во время отправки не создаёт дубликат', () async {
    env.registrationRemote.completer = Completer<String>();

    final first = submit();
    final second = submit();
    expect(cubit.state.isSubmitting, isTrue);
    env.registrationRemote.completer!.complete('-Nonly');
    await Future.wait([first, second]);

    expect(env.registrationRemote.saved, hasLength(1));
    expect(env.push.shown, hasLength(1));
    expect(cubit.state.userKey, '-Nonly');
  });
}
