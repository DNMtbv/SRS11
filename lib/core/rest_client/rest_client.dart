import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../constants/api_constants.dart';
import '../logger.dart';
import 'interceptors.dart';

/// Единственный Dio на всё приложение. Регистрируется в DI один раз;
/// Presentation и Domain о нём не знают.
class RestClient {
  RestClient({
    String baseUrl = ApiConstants.baseUrl,
    HttpClientAdapter? adapter,
    Duration retryDelay = ApiConstants.retryBaseDelay,
    bool enableLogging = kDebugMode,
  }) : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: ApiConstants.connectTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
            sendTimeout: ApiConstants.sendTimeout,
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
          ),
        ) {
    if (adapter != null) dio.httpClientAdapter = adapter;

    dio.interceptors.addAll([
      HeadersInterceptor(),
      if (enableLogging)
        LogInterceptor(
          requestBody: true,
          responseBody: false,
          logPrint: (o) => AppLogger.info(o.toString()),
        ),
      RetryInterceptor(dio: dio, baseDelay: retryDelay),
      ErrorInterceptor(),
    ]);
  }

  final Dio dio;
}
