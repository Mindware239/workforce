import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/network_providers.dart';
import 'package:workforce/features/attendence/data/fingerprint_repository.dart';

class AttendanceRepository {
  final ApiClient apiClient;

  AttendanceRepository({required this.apiClient});

  Future<Map<String, dynamic>> getTodayAttendance() async {
    final response = await apiClient.get('/attendance/me/today');

    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> getMonthlyReport({
    required int year,
    required int month,
  }) async {
    final response = await apiClient.get(
      '/reports/me/monthly',
      queryParameters: {'year': year, 'month': month},
    );

    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> getMySalary({
    required int year,
    required int month,
  }) async {
    final response = await apiClient.get(
      '/reports/me/salary',
      queryParameters: {'year': year, 'month': month},
    );

    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> getAttendanceHistory({
    required int year,
    required int month,
  }) async {
    final response = await apiClient.get(
      '/attendance/me/history',
      queryParameters: {'year': year, 'month': month},
    );

    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> getDashboard() async {
  final response = await apiClient.get(
    '/attendance/me/dashboard',
  );

  return Map<String, dynamic>.from(response.data);
}

  Future<Map<String, dynamic>> checkIn({
    required String attendanceType,
    String? photoPath,
    String? signature,
    required double lat,
    required double lng,
    double? accuracy,
  }) async {
    // =========================================================
    // Validate attendance type
    // =========================================================

    if (attendanceType != 'face' && attendanceType != 'fingerprint') {
      throw Exception('Invalid attendance type.');
    }

    // =========================================================
    // Validate location accuracy
    // =========================================================

    if (accuracy != null && accuracy > 100) {
      throw Exception(
        'Your location accuracy is too low. '
        'Please move to an open area and try again.',
      );
    }

    // =========================================================
    // Face attendance requires photo
    // =========================================================

    if (attendanceType == 'face' && (photoPath == null || photoPath.isEmpty)) {
      throw Exception('Face photo is required for face attendance.');
    }

    // =========================================================
    // Fingerprint attendance requires signature
    // =========================================================

    if (attendanceType == 'fingerprint' &&
        (signature == null || signature.isEmpty)) {
      throw Exception(
        'Biometric signature is required for fingerprint attendance.',
      );
    }

    // =========================================================
    // Build multipart request
    // =========================================================

    final Map<String, dynamic> fields = {
      'attendance_type': attendanceType,
      'lat': lat.toString(),
      'lng': lng.toString(),

      if (accuracy != null) 'accuracy': accuracy.toString(),

      // Fingerprint biometric signature
      if (attendanceType == 'fingerprint') 'signature': signature,
    };

    // =========================================================
    // Add photo only for face attendance
    // =========================================================

    if (attendanceType == 'face' && photoPath != null && photoPath.isNotEmpty) {
      fields['photo'] = await MultipartFile.fromFile(
        photoPath,
        filename: photoPath.split('/').last,
      );
    }

    final formData = FormData.fromMap(fields);

    debugPrint('========== ATTENDANCE REQUEST ==========');
    debugPrint('Attendance Type: $attendanceType');
    debugPrint('Latitude: $lat');
    debugPrint('Longitude: $lng');
    debugPrint('Accuracy: $accuracy');
    debugPrint('Photo: ${photoPath != null}');
    debugPrint('Signature: ${signature != null}');
    debugPrint('========================================');

    // =========================================================
    // API REQUEST
    // =========================================================

    try {
      final response = await apiClient.dio.post(
        '/attendance/entry',
        data: formData,
      );

      debugPrint('✅ ATTENDANCE RESPONSE: ${response.data}');

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      debugPrint('❌ ATTENDANCE ERROR: ${e.message}');

      debugPrint('❌ STATUS: ${e.response?.statusCode}');

      debugPrint('❌ RESPONSE: ${e.response?.data}');

      // Already checked in
      if (e.response?.statusCode == 409) {
        throw Exception('You have already checked in today.');
      }

      final responseData = e.response?.data;

      if (responseData is Map<String, dynamic>) {
        final message = responseData['message'];

        if (message != null) {
          throw Exception(message.toString());
        }
      }

      throw Exception(e.message ?? 'Unable to check in. Please try again.');
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

      throw Exception(e.message ?? 'Unable to verify office location.');
    }
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(apiClient: ref.read(apiClientProvider));
});

final fingerprintRepositoryProvider = Provider<FingerprintRepository>((ref) {
  return FingerprintRepository(apiClient: ref.read(apiClientProvider));
});
