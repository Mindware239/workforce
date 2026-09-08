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

    final responseData =
        Map<String, dynamic>.from(response.data);

    final data =
        Map<String, dynamic>.from(
      responseData['data'] ?? {},
    );

    final token = data['token'];

    if (token == null ||
        token.toString().isEmpty) {
      throw Exception('Token not received');
    }

    final user =
        Map<String, dynamic>.from(
      data['user'] ?? {},
    );

    await secureStorage.saveToken(
      token.toString(),
    );

    await secureStorage.saveUser(user);

    AuthService.login();

    return user;
  }

  // --------------------------------------------------------
  // ONBOARDING STATUS
  // --------------------------------------------------------

  Future<Map<String, dynamic>> getOnboardingStatus() async {
    final response = await apiClient.get(
      '/auth/onboarding-status',
    );

    final responseData =
        Map<String, dynamic>.from(response.data);

    final data =
        Map<String, dynamic>.from(
      responseData['data'] ?? {},
    );

    return data;
  }

  // --------------------------------------------------------
  // SUBMIT ONBOARDING
  // --------------------------------------------------------

  Future<Map<String, dynamic>> submitOnboarding({
    required String emergencyContact1Relation,
    required String emergencyContact1Number,
    required String emergencyContact2Relation,
    required String emergencyContact2Number,
    required String permanentAddress,
    required String correspondenceAddress,
    required bool termsAccepted,

    String? fullName,
    String? mobileNumber,
    String? email,
  }) async {
    final body = <String, dynamic>{
      'emergencyContact1Relation':
          emergencyContact1Relation,
      'emergencyContact1Number':
          emergencyContact1Number,
      'emergencyContact2Relation':
          emergencyContact2Relation,
      'emergencyContact2Number':
          emergencyContact2Number,
      'permanentAddress':
          permanentAddress,
      'correspondenceAddress':
          correspondenceAddress,
      'termsAccepted':
          termsAccepted,
    };

    // Send identity fields only when provided.
    if (fullName != null) {
      body['fullName'] = fullName;
    }

    if (mobileNumber != null) {
      body['mobileNumber'] = mobileNumber;
    }

    if (email != null) {
      body['email'] = email;
    }

    final response = await apiClient.post(
      '/auth/onboarding',
      data: body,
    );

    final responseData =
        Map<String, dynamic>.from(response.data);

    return Map<String, dynamic>.from(
      responseData['data'] ?? {},
    );
  }

  Future<Map<String, dynamic>?> getSavedUser() async {
    return secureStorage.getUser();
  }
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.read(apiClientProvider),
    secureStorage:
        ref.read(secureStorageProvider),
  );
});