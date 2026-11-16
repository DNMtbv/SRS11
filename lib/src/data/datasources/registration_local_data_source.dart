import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/storage_keys.dart';
import '../../../core/error/exceptions.dart';

/// Отметка о регистрации на устройстве: при следующем запуске
/// сразу открывается список постов.
abstract interface class RegistrationLocalDataSource {
  String? readUserKey();

  Future<void> saveUser({required String key, required String name});
}

class RegistrationLocalDataSourceImpl implements RegistrationLocalDataSource {
  const RegistrationLocalDataSourceImpl(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? readUserKey() => _prefs.getString(StorageKeys.registrationUserKey);

  @override
  Future<void> saveUser({required String key, required String name}) async {
    final ok = await _prefs.setString(StorageKeys.registrationUserKey, key) &&
        await _prefs.setString(StorageKeys.registrationUserName, name);
    if (!ok) throw const CacheException();
  }
}
