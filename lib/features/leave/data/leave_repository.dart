import 'package:flutter/material.dart';
import 'package:workforce/core/network/api_client.dart';

class LeaveRepository {
  final ApiClient apiClient;

  LeaveRepository({required this.apiClient});

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

        // Full Day only
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,

        // Half Day only
        if (startTime != null && startTime.isNotEmpty) 'startTime': startTime,

        if (endTime != null && endTime.isNotEmpty) 'endTime': endTime,

        'reason': reason,
      },
    );

    return Map<String, dynamic>.from(response.data);
  }

  Future<List<Map<String, dynamic>>> getMyLeaveRequests() async {
    try {
      final response = await apiClient.get('/leaves/mine');

      debugPrint('========== LEAVE REQUESTS API ==========');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Response type: ${response.data.runtimeType}');
      debugPrint('Response: ${response.data}');
      debugPrint('========================================');

      final data = response.data;

      // Case 1:
      // API returns:
      // [
      //   {...},
      //   {...}
      // ]
      if (data is List) {
        return data
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      // Case 2:
      // API returns:
      // {
      //   "data": [...]
      // }
      if (data is Map && data['data'] is List) {
        final list = data['data'] as List;

        return list
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      // Case 3:
      // API returns:
      // {
      //   "success": true,
      //   "data": [...]
      // }
      if (data is Map && data['result'] is List) {
        final list = data['result'] as List;

        return list
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      throw Exception('Invalid leave requests response from server.');
    } catch (e) {
      debugPrint('========== LEAVE REQUESTS ERROR ==========');
      debugPrint(e as String?);
      debugPrint('==========================================');
      rethrow;
    }
  }
}
