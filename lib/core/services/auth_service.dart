import 'package:workforce/core/services/secure_storage.dart';

class AuthService {
  static bool isAuthenticated = false;

  static Future<void> initialize(
    SecureStorage secureStorage,
  ) async {
    final token = await secureStorage.getToken();

    isAuthenticated = token != null && token.isNotEmpty;
  }

  static void login() {
    isAuthenticated = true;
  }

  static void logout() {
    isAuthenticated = false;
  }
}