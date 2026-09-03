import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/network_providers.dart';

class AttendanceRepository {
  final ApiClient apiClient;

  AttendanceRepository({
    required this.apiClient,
  });

  Future<Map<String, dynamic>> checkIn({
    required String photoPath,
    required double lat,
    required double lng,
    double? accuracy,
  }) async {
    // If accuracy is available, it must be within 100 metres.
    if (accuracy != null && accuracy > 100) {
      throw Exception(
        'Your location accuracy is too low. Please move to an open area and try again.',
      );
    }

    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(
        photoPath,
        filename: photoPath.split('/').last,
      ),
      'lat': lat.toString(),
      'lng': lng.toString(),

      // Send accuracy only when available.
      if (accuracy != null) 'accuracy': accuracy.toString(),
    });

    try {
      final response = await apiClient.dio.post(
        '/attendance/entry',
        data: formData,
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception(
          'You have already checked in today.',
        );
      }

      final responseData = e.response?.data;

      if (responseData is Map<String, dynamic>) {
        final message = responseData['message'];

        if (message != null) {
          throw Exception(message.toString());
        }
      }

      throw Exception(
        e.message ?? 'Unable to check in. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> checkGeofence({
  required double lat,
  required double lng,
  double? accuracy,
}) async {
  try {
    final response = await apiClient.post(
      '/attendance/geofence-check',
      data: {
        'lat': lat,
        'lng': lng,
        if (accuracy != null) 'accuracy': accuracy,
      },
    );

    debugPrint('📍 GEOFENCE RESPONSE: ${response.data}');

    return Map<String, dynamic>.from(response.data);
  } on DioException catch (e) {
    debugPrint('❌ GEOFENCE ERROR: ${e.message}');
    debugPrint('❌ STATUS: ${e.response?.statusCode}');
    debugPrint('❌ RESPONSE: ${e.response?.data}');

    final data = e.response?.data;

    if (data is Map<String, dynamic> && data['message'] != null) {
      throw Exception(data['message'].toString());
    }

    throw Exception(
      e.message ?? 'Unable to verify office location.',
    );
  }
}
}

final attendanceRepositoryProvider =
    Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(
    apiClient: ref.read(apiClientProvider),
  );
});