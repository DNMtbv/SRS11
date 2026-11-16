/// Ключи SharedPreferences. Собраны в одном месте, чтобы не было опечаток
/// и пересечений между data sources.
abstract final class StorageKeys {
  static const postsPagePrefix = 'cache.posts.';
  static const authors = 'cache.users';
  static const localPosts = 'cache.local_posts';

  static const registrationUserKey = 'registration.user_key';
  static const registrationUserName = 'registration.user_name';

  static const favorites = 'favorites.posts';
}
