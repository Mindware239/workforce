import 'package:dio/dio.dart';

class ApiClient {
  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://your-api.com/api',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
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