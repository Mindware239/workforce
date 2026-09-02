import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/network_providers.dart';

class AuthRepository {
  final ApiClient apiClient;

  AuthRepository(this.apiClient);

  Future<Map<String, dynamic>> login({
    required String employeeId,
    required String password,
  }) async {
    final response = await apiClient.post(
      '/auth/login',
      data: {
        'employeeId': employeeId,
        'password': password,
      },
    );

    return Map<String, dynamic>.from(response.data);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(apiClientProvider),
  );
});