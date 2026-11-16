import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/either.dart';
import '../../../../core/error/failures.dart';
import '../../../domain/entities/registration_data.dart';
import '../../../domain/usecases/registration_usecases.dart';

enum RegistrationStatus { idle, submitting, success, failure }

class RegistrationState extends Equatable {
  const RegistrationState({
    this.status = RegistrationStatus.idle,
    this.deviceToken,
    this.userKey,
    this.failure,
  });

  final RegistrationStatus status;

  /// FCM-токен — показывается внизу экрана для тестового пуша.
  final String? deviceToken;

  /// Ключ записи в /users после успешной регистрации.
  final String? userKey;
  final Failure? failure;

  bool get isSubmitting => status == RegistrationStatus.submitting;

  @override
  List<Object?> get props => [status, deviceToken, userKey, failure];
}

class RegistrationCubit extends Cubit<RegistrationState> {
  RegistrationCubit(this._registerUser, GetDeviceTokenUseCase getDeviceToken)
      : super(RegistrationState(deviceToken: getDeviceToken()));

  final RegisterUserUseCase _registerUser;

  Future<void> submit({
    required String name,
    required String email,
    required String phone,
    String? city,
  }) async {
    if (state.isSubmitting || state.status == RegistrationStatus.success) {
      return;
    }
    final token = state.deviceToken;
    emit(RegistrationState(
      status: RegistrationStatus.submitting,
      deviceToken: token,
    ));

    final result = await _registerUser(
      RegistrationData(name: name, email: email, phone: phone, city: city),
    );
    if (isClosed) return;
    emit(switch (result) {
      Right(value: final key) => RegistrationState(
          status: RegistrationStatus.success,
          deviceToken: token,
          userKey: key,
        ),
      Left(value: final failure) => RegistrationState(
          status: RegistrationStatus.failure,
          deviceToken: token,
          failure: failure,
        ),
    });
  }
}
