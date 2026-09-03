import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/network_providers.dart';
import 'package:workforce/core/services/auth_service.dart';
import 'package:workforce/core/services/secure_storage.dart';

class AuthRepository {
  final ApiClient apiClient;
  final SecureStorage secureStorage;

  AuthRepository({
    required this.apiClient,
    required this.secureStorage,
  });

  Future<Map<String, dynamic>> login({
    required String mobileNumber,
  }) async {
    final response = await apiClient.post(
      '/auth/login',
      data: {
        'mobileNumber': mobileNumber,
      },
    );

    debugPrint('LOGIN RESPONSE: ${response.data}');

    final responseData =
        Map<String, dynamic>.from(response.data);

    final data = Map<String, dynamic>.from(
      responseData['data'] ?? {},
    );

    final token = data['token'];

    if (token == null || token.toString().isEmpty) {
      throw Exception('Token not received');
    }

    final user = Map<String, dynamic>.from(
      data['user'] ?? {},
    );

    // Save JWT
    await secureStorage.saveToken(
      token.toString(),
    );

    // IMPORTANT: Save employee data
    await secureStorage.saveUser(user);

    // Mark authenticated
    AuthService.login();

    return user;
  }

  // Restore saved employee data after app restart
  Future<Map<String, dynamic>?> getSavedUser() async {
    return secureStorage.getUser();
  }
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.read(apiClientProvider),
    secureStorage: ref.read(secureStorageProvider),
  );
});