import 'package:dio/dio.dart';
import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/services/auth_service.dart';
import 'package:workforce/core/services/navigation_service.dart';
import 'package:workforce/core/services/secure_storage.dart';

class ApiClient {
  /// The REST base URL. The realtime socket derives its origin from this, so
  /// pointing the app at another server stays a one-line change here.
  // static const String baseUrl = 'https://workforce.orkuts.com/api';
  static const String baseUrl = 'http://192.168.1.142:5050/api';

  late final Dio dio;

  final SecureStorage secureStorage;

  ApiClient({required this.secureStorage}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
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
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            final path = error.requestOptions.path;
            if (!path.contains('/auth/login')) {
              await secureStorage.clearAuth();
              AuthService.logout();
              NavigationService.router.go(AppRoutes.login);
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<Response> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return dio.get(endpoint, queryParameters: queryParameters);
  }

  Future<Response> post(String endpoint, {dynamic data}) async {
    return dio.post(endpoint, data: data);
  }

  Future<Response> put(String endpoint, {dynamic data}) async {
    return dio.put(endpoint, data: data);
  }

  Future<Response> delete(String endpoint, {dynamic data}) async {
    return dio.delete(endpoint, data: data);
  }
}
