import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/storage_keys.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/logger.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';

/// Локальный кэш постов и авторов + посты, созданные на устройстве.
abstract interface class PostsLocalDataSource {
  List<PostModel>? readFirstPage(String queryKey);

  Future<void> saveFirstPage(String queryKey, List<PostModel> posts);

  List<UserModel>? readUsers();

  Future<void> saveUsers(List<UserModel> users);

  List<PostModel> readLocalPosts();

  Future<void> saveLocalPosts(List<PostModel> posts);
}

/// Реализация на SharedPreferences. Храним JSON и разбираем теми же
/// fromJson. Битый кэш удаляется и не роняет приложение.
class PostsLocalDataSourceImpl implements PostsLocalDataSource {
  const PostsLocalDataSourceImpl(this._prefs);

  final SharedPreferences _prefs;

  @override
  List<PostModel>? readFirstPage(String queryKey) =>
      _readList(StorageKeys.postsPagePrefix + queryKey, PostModel.fromJson);

  @override
  Future<void> saveFirstPage(String queryKey, List<PostModel> posts) => _write(
        StorageKeys.postsPagePrefix + queryKey,
        posts.map((p) => p.toJson()).toList(),
      );

  @override
  List<UserModel>? readUsers() =>
      _readList(StorageKeys.authors, UserModel.fromJson);

  @override
  Future<void> saveUsers(List<UserModel> users) =>
      _write(StorageKeys.authors, users.map((u) => u.toJson()).toList());

  @override
  List<PostModel> readLocalPosts() =>
      _readList(StorageKeys.localPosts, PostModel.fromJson) ?? const [];

  @override
  Future<void> saveLocalPosts(List<PostModel> posts) =>
      _write(StorageKeys.localPosts, posts.map((p) => p.toJson()).toList());

  Future<void> _write(String key, List<Map<String, dynamic>> items) async {
    final ok = await _prefs.setString(key, jsonEncode(items));
    if (!ok) throw const CacheException();
  }

  List<T>? _readList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, s) {
      AppLogger.error('Повреждён кэш "$key", удаляю', error: e, stackTrace: s);
      _prefs.remove(key);
      return null;
    }
  }
}
