import 'package:dio/dio.dart';
import 'package:workforce/core/services/secure_storage.dart';

class ApiClient {
  late final Dio dio;

  final SecureStorage secureStorage;

  ApiClient({
    required this.secureStorage,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://workforce.orkuts.com/api',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await secureStorage.getToken();

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },
      ),
    );
  }

  Future<Response> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return dio.get(
      endpoint,
      queryParameters: queryParameters,
    );
  }

  Future<Response> post(
    String endpoint, {
    dynamic data,
  }) async {
    return dio.post(
      endpoint,
      data: data,
    );
  }

  Future<Response> put(
    String endpoint, {
    dynamic data,
  }) async {
    return dio.put(
      endpoint,
      data: data,
    );
  }

  Future<Response> delete(
    String endpoint, {
    dynamic data,
  }) async {
    return dio.delete(
      endpoint,
      data: data,
    );
  }
}