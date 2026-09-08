import 'dart:io';

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

  Future<Map<String, dynamic>> updateEmployeeLocation({
  required double latitude,
  required double longitude,
  required double accuracy,
  double? speed,
  double? heading,
}) async {
  final response = await apiClient.dio.post(
    '/v1/employee/location',
    data: {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
      'recordedAt': DateTime.now().toUtc().toIso8601String(),
    },
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
    final response = await apiClient.get('/attendance/me/dashboard');

    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> startBreak() async {
    final response = await apiClient.post('/attendance/me/break/start');

    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> endBreak() async {
    final response = await apiClient.post('/attendance/me/break/end');

    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> checkout({
    required String attendanceType,
    String? photoPath,
    String? workAudioPath,
    String? workDescription,
    required double lat,
    required double lng,
    double? accuracy,
    String? deviceId,
    int? challengeId,
    String? signature,
  }) async {
    if (attendanceType != 'face' && attendanceType != 'fingerprint') {
      throw Exception('Invalid attendance type.');
    }

    // ------------------------------------------------------------
    // LOCATION
    // ------------------------------------------------------------

    if (accuracy != null && accuracy > 100) {
      throw Exception(
        'Your location accuracy is too low. '
        'Please move to an open area and try again.',
      );
    }

    // ------------------------------------------------------------
    // FACE VALIDATION
    // ------------------------------------------------------------

    if (attendanceType == 'face') {
      if (photoPath == null || photoPath.isEmpty) {
        throw Exception('Face photo is required for checkout.');
      }

      final photoFile = File(photoPath);

      if (!await photoFile.exists()) {
        throw Exception('Checkout photo could not be found.');
      }
    }

    // ------------------------------------------------------------
    // FINGERPRINT VALIDATION
    // ------------------------------------------------------------

    if (attendanceType == 'fingerprint') {
      if (deviceId == null || deviceId.isEmpty) {
        throw Exception('Device ID is required for fingerprint checkout.');
      }

      if (challengeId == null) {
        throw Exception('Fingerprint challenge is required for checkout.');
      }

      if (signature == null || signature.isEmpty) {
        throw Exception('Biometric signature is required for checkout.');
      }
    }

    try {
      final Map<String, dynamic> fields = {
        'attendance_type': attendanceType,
        'lat': lat.toString(),
        'lng': lng.toString(),
      };

      // ----------------------------------------------------------
      // OPTIONAL LOCATION ACCURACY
      // ----------------------------------------------------------

      if (accuracy != null) {
        fields['accuracy'] = accuracy.toString();
      }

      // ----------------------------------------------------------
      // WORK DESCRIPTION
      // ----------------------------------------------------------

      if (workDescription != null && workDescription.trim().isNotEmpty) {
        fields['workDescription'] = workDescription.trim();
      }

      // ----------------------------------------------------------
      // FACE CHECKOUT
      // ----------------------------------------------------------

      if (attendanceType == 'face') {
        fields['photo'] = await MultipartFile.fromFile(
          photoPath!,
          filename: photoPath.split(Platform.pathSeparator).last,
        );
      }

      // ----------------------------------------------------------
      // FINGERPRINT CHECKOUT
      // ----------------------------------------------------------

      if (attendanceType == 'fingerprint') {
        fields['deviceId'] = deviceId;
        fields['challengeId'] = challengeId;
        fields['signature'] = signature;
      }

      // ----------------------------------------------------------
      // WORK AUDIO
      // ----------------------------------------------------------

      if (workAudioPath != null && workAudioPath.isNotEmpty) {
        final audioFile = File(workAudioPath);

        if (!await audioFile.exists()) {
          throw Exception('Work audio file could not be found.');
        }

        fields['workAudio'] = await MultipartFile.fromFile(
          workAudioPath,
          filename: workAudioPath.split(Platform.pathSeparator).last,
        );
      }

      final formData = FormData.fromMap(fields);

      // ----------------------------------------------------------
      // DEBUG
      // ----------------------------------------------------------

      

      final response = await apiClient.dio.post(
        '/attendance/exit',
        data: formData,
      );

  

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      

      final responseData = e.response?.data;

      if (responseData is Map) {
        final message = responseData['message'];

        if (message != null && message.toString().trim().isNotEmpty) {
          throw Exception(message.toString());
        }

        final error = responseData['error'];

        if (error != null && error.toString().trim().isNotEmpty) {
          throw Exception(error.toString());
        }
      }

      if (e.response?.statusCode == 400) {
        throw Exception('Checkout request was rejected by the server.');
      }

      if (e.response?.statusCode == 404) {
        throw Exception('Attendance session was not found.');
      }

      if (e.response?.statusCode == 409) {
        throw Exception('You have already checked out today.');
      }

      throw Exception(
        e.message ??
            'Unable to end the attendance session. '
                'Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> checkIn({
    required String attendanceType,
    String? photoPath,
    required double lat,
    required double lng,
    double? accuracy,
    String? deviceId,
    int? challengeId,
    String? signature,
  }) async {
    if (attendanceType != 'face' && attendanceType != 'fingerprint') {
      throw Exception('Invalid attendance type.');
    }

    if (accuracy != null && accuracy > 100) {
      throw Exception(
        'Your location accuracy is too low. '
        'Please move to an open area and try again.',
      );
    }

    if (attendanceType == 'face') {
      if (photoPath == null || photoPath.isEmpty) {
        throw Exception('Face photo is required.');
      }

      final file = File(photoPath);

      if (!await file.exists()) {
        throw Exception('Attendance photo could not be found.');
      }
    }

    if (attendanceType == 'fingerprint') {
      if (deviceId == null || deviceId.isEmpty) {
        throw Exception('Device ID is required.');
      }

      if (challengeId == null) {
        throw Exception('Fingerprint challenge is required.');
      }

      if (signature == null || signature.isEmpty) {
        throw Exception('Biometric signature is required.');
      }
    }

    try {
      final Map<String, dynamic> fields = {
        'attendance_type': attendanceType,
        'lat': lat.toString(),
        'lng': lng.toString(),
      };

      if (accuracy != null) {
        fields['accuracy'] = accuracy.toString();
      }

      // FACE
      if (attendanceType == 'face') {
        fields['photo'] = await MultipartFile.fromFile(
          photoPath!,
          filename: photoPath.split(Platform.pathSeparator).last,
        );
      }

      // FINGERPRINT
      if (attendanceType == 'fingerprint') {
        fields['deviceId'] = deviceId;
        fields['challengeId'] = challengeId;
        fields['signature'] = signature;
      }

      final formData = FormData.fromMap(fields);


      final response = await apiClient.dio.post(
        '/attendance/entry',
        data: formData,
      );


      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
     

      final responseData = e.response?.data;

      if (responseData is Map) {
        final message = responseData['message'];

        if (message != null && message.toString().trim().isNotEmpty) {
          throw Exception(message.toString());
        }

        final error = responseData['error'];

        if (error != null && error.toString().trim().isNotEmpty) {
          throw Exception(error.toString());
        }
      }

      if (e.response?.statusCode == 400) {
        throw Exception('Attendance request was rejected by the server.');
      }

      if (e.response?.statusCode == 409) {
        throw Exception('You have already checked in today.');
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

      

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      
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
