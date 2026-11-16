import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/storage_keys.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/logger.dart';
import '../../../models/favorite_post_model.dart';

/// Избранное на устройстве. Бросает только [CacheException].
abstract interface class FavoritesLocalDataSource {
  List<FavoritePostModel> readAll();

  Future<void> saveAll(List<FavoritePostModel> favorites);
}

class FavoritesLocalDataSourceImpl implements FavoritesLocalDataSource {
  const FavoritesLocalDataSourceImpl(this._prefs);

  final SharedPreferences _prefs;

  @override
  List<FavoritePostModel> readAll() {
    final raw = _prefs.getString(StorageKeys.favorites);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => FavoritePostModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, s) {
      // Битые данные не удаляем молча: это выбор пользователя.
      // Сообщаем об ошибке, пусть решает UI.
      AppLogger.error('Повреждено избранное', error: e, stackTrace: s);
      throw const CacheException();
    }
  }

  @override
  Future<void> saveAll(List<FavoritePostModel> favorites) async {
    final ok = await _prefs.setString(
      StorageKeys.favorites,
      jsonEncode(favorites.map((f) => f.toJson()).toList()),
    );
    if (!ok) throw const CacheException();
  }
}
