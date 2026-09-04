import 'package:dio/dio.dart';

import 'package:workforce/core/network/api_client.dart';

class FingerprintRepository {
  final ApiClient apiClient;

  FingerprintRepository({
    required this.apiClient,
  });

  /// Register biometric device.
  /// Call once per device/key.
  Future<Map<String, dynamic>> registerDevice({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String publicKey,
    required String algorithm,
  }) async {
    try {
      final response = await apiClient.post(
        '/fingerprint/register',
        data: {
          'deviceId': deviceId,
          'deviceName': deviceName,
          'platform': platform,
          'publicKey': publicKey,
          'algorithm': algorithm,
        },
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(
        e,
        'Unable to register fingerprint device.',
      );
    }
  }

  /// Request a new challenge.
  Future<Map<String, dynamic>> createChallenge({
    required String deviceId,
    required String purpose,
  }) async {
    try {
      final response = await apiClient.post(
        '/fingerprint/challenge',
        data: {
          'deviceId': deviceId,
          'purpose': purpose,
        },
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(
        e,
        'Unable to create fingerprint challenge.',
      );
    }
  }

  /// Verify signed challenge.
  ///
  /// This endpoint verifies the fingerprint signature
  /// AND marks attendance.
  Future<Map<String, dynamic>> verify({
    required String deviceId,
    required int challengeId,
    required String signature,
    required double lat,
    required double lng,
    double? accuracy,
  }) async {
    try {
      final response = await apiClient.post(
        '/fingerprint/verify',
        data: {
          'deviceId': deviceId,
          'challengeId': challengeId,
          'signature': signature,
          'lat': lat,
          'lng': lng,
          if (accuracy != null) 'accuracy': accuracy,
        },
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(
        e,
        'Fingerprint verification failed.',
      );
    }
  }

  Exception _handleError(
    DioException e,
    String fallback,
  ) {
    final statusCode = e.response?.statusCode;
    final responseData = e.response?.data;

    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'];

      if (message != null &&
          message.toString().trim().isNotEmpty) {
        return Exception(message.toString());
      }
    }

    switch (statusCode) {
      case 400:
        return Exception(
          'Invalid fingerprint request.',
        );

      case 401:
        return Exception(
          'Fingerprint verification failed. '
          'Please request a new challenge.',
        );

      case 403:
        return Exception(
          'You must be inside the workspace to mark attendance.',
        );

      case 404:
        return Exception(
          'This fingerprint device is not registered.',
        );

      case 409:
        return Exception(
          'This challenge has already been used. '
          'Please request a new challenge.',
        );

      case 429:
        return Exception(
          'Too many requests. Please try again later.',
        );

      default:
        return Exception(
          e.message ?? fallback,
        );
    }
  }
}