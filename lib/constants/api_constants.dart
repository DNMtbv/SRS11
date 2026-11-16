/// Настройки REST API.
abstract final class ApiConstants {
  static const baseUrl = 'https://jsonplaceholder.typicode.com';

  static const connectTimeout = Duration(seconds: 10);
  static const receiveTimeout = Duration(seconds: 15);
  static const sendTimeout = Duration(seconds: 10);

  /// Сколько раз повторять GET при сбое сети / 5xx.
  static const maxRetries = 2;
  static const retryBaseDelay = Duration(milliseconds: 500);

  /// Размер страницы списка постов.
  static const pageSize = 10;

  static const clientHeader = 'posts-app/2.0';
}
