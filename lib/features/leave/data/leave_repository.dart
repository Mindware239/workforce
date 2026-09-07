import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:workforce/core/network/api_client.dart';

class LeaveRepository {
  final ApiClient apiClient;

  LeaveRepository({
    required this.apiClient,
  });

  // ============================================================
  // APPLY LEAVE
  // ============================================================

  Future<Map<String, dynamic>> applyLeave({
    required String leaveType,
    required String leaveCategory,
    required String startDate,
    String? endDate,
    String? startTime,
    String? endTime,
    required String reason,
  }) async {
    final response = await apiClient.post(
      '/leaves',
      data: {
        'leaveType': leaveType,
        'leaveCategory': leaveCategory,
        'startDate': startDate,

        if (endDate != null && endDate.isNotEmpty)
          'endDate': endDate,

        if (startTime != null && startTime.isNotEmpty)
          'startTime': startTime,

        if (endTime != null && endTime.isNotEmpty)
          'endTime': endTime,

        'reason': reason,
      },
    );

    return Map<String, dynamic>.from(
      response.data,
    );
  }

  // ============================================================
  // GET LEAVE BALANCES
  // GET /api/leaves/balances
  // ============================================================

  Future<List<Map<String, dynamic>>> getLeaveBalances({
    int? year,
  }) async {
    try {
      final response = await apiClient.get(
        '/leaves/balances',
        queryParameters: {
          'year': ?year,
        },
      );

      debugPrint('========== LEAVE BALANCES ==========');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Response: ${response.data}');
      debugPrint('====================================');

      final responseData = response.data;

      if (responseData is Map &&
          responseData['data'] is List) {
        return (responseData['data'] as List)
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();
      }

      return [];
    } on DioException catch (e) {
      // debugPrint('❌ Leave balances error: ${e.message}');
      // debugPrint('❌ Status: ${e.response?.statusCode}');
      // debugPrint('❌ Response: ${e.response?.data}');

      final responseData = e.response?.data;

      if (responseData is Map &&
          responseData['message'] != null) {
        throw Exception(
          responseData['message'].toString(),
        );
      }

      throw Exception(
        e.message ?? 'Unable to load leave balances.',
      );
    }
  }

  // ============================================================
  // GET MY LEAVE REQUESTS
  // GET /api/leaves/mine
  // ============================================================

  Future<List<Map<String, dynamic>>> getMyLeaveRequests() async {
    try {
      final response = await apiClient.get(
        '/leaves/mine',
      );

      // debugPrint('========== LEAVE REQUESTS API ==========');
      // debugPrint('Status: ${response.statusCode}');
      // debugPrint(
      //   'Response type: ${response.data.runtimeType}',
      // );
      // debugPrint('Response: ${response.data}');
      // debugPrint('========================================');

      final data = response.data;

      // API returns:
      // [
      //   {...},
      //   {...}
      // ]

      if (data is List) {
        return data
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();
      }

      // API returns:
      // {
      //   "data": [...]
      // }

      if (data is Map &&
          data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();
      }

      // API returns:
      // {
      //   "result": [...]
      // }

      if (data is Map &&
          data['result'] is List) {
        return (data['result'] as List)
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();
      }

      throw Exception(
        'Invalid leave requests response from server.',
      );
    } on DioException catch (e) {
      // debugPrint('========== LEAVE REQUESTS ERROR ==========');
      // debugPrint('Status: ${e.response?.statusCode}');
      // debugPrint('Message: ${e.message}');
      // debugPrint('Response: ${e.response?.data}');
      // debugPrint('==========================================');

      final responseData = e.response?.data;

      if (responseData is Map &&
          responseData['message'] != null) {
        throw Exception(
          responseData['message'].toString(),
        );
      }

      throw Exception(
        e.message ?? 'Unable to load leave requests.',
      );
    } catch (e) {
      // debugPrint('========== LEAVE REQUESTS ERROR ==========');
      debugPrint(e.toString());
      // debugPrint('==========================================');

      rethrow;
    }
  }
}