import '../../../core/either.dart';
import '../../../core/error/error_handler.dart';
import '../../../core/error/failures.dart';
import '../../domain/entities/registration_data.dart';
import '../../domain/repositories/registration_repository.dart';
import '../datasources/registration_local_data_source.dart';
import '../datasources/registration_remote_data_source.dart';
import '../mapper/registration_mapper.dart';

class RegistrationRepositoryImpl implements RegistrationRepository {
  const RegistrationRepositoryImpl({
    required this._remote,
    required this._local,
  });

  final RegistrationRemoteDataSource _remote;
  final RegistrationLocalDataSource _local;

  @override
  Future<bool> isRegistered() async => _local.readUserKey() != null;

  @override
  Future<Either<Failure, String>> register(
    RegistrationData data, {
    String? deviceToken,
  }) =>
      ErrorHandler.guard(() async {
        final key = await _remote.saveUser(data.toModel(fcmToken: deviceToken));
        await _local.saveUser(key: key, name: data.name);
        return key;
      });
}
