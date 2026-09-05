import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/network_providers.dart';

class TaskRepository {
  final ApiClient apiClient;

  TaskRepository({
    required this.apiClient,
  });

  // ============================================================
  // GET /tasks
  // ============================================================

  Future<Map<String, dynamic>> getTasks({
    String scope = 'mine',
    String? status,
    String? priority,
    int? assignedTo,
    bool? overdue,
    int page = 1,
    int limit = 50,
  }) async {
    final queryParameters = <String, dynamic>{
      'scope': scope,
      'page': page,
      'limit': limit,
    };

    if (status != null && status.isNotEmpty) {
      queryParameters['status'] = status;
    }

    if (priority != null && priority.isNotEmpty) {
      queryParameters['priority'] = priority;
    }

    if (assignedTo != null) {
      queryParameters['assignedTo'] = assignedTo;
    }

    if (overdue != null) {
      queryParameters['overdue'] = overdue;
    }

    try {
      final response = await apiClient.get(
        '/tasks',
        queryParameters: queryParameters,
      );

      debugPrint('========== TASKS API ==========');
      debugPrint(response.data.toString());
      debugPrint('===============================');

      return Map<String, dynamic>.from(
        response.data,
      );
    } on DioException catch (e) {
      debugPrint(
        '❌ GET TASKS ERROR: ${e.response?.data}',
      );

      throw Exception(
        _getErrorMessage(
          e,
          'Unable to fetch tasks.',
        ),
      );
    }
  }

  // ============================================================
  // GET /tasks/{id}
  // ============================================================

  Future<Map<String, dynamic>> getTask(
    int taskId,
  ) async {
    try {
      final response = await apiClient.get(
        '/tasks/$taskId',
      );

      return Map<String, dynamic>.from(
        response.data,
      );
    } on DioException catch (e) {
      debugPrint(
        '❌ GET TASK ERROR: ${e.response?.data}',
      );

      throw Exception(
        _getErrorMessage(
          e,
          'Unable to fetch task.',
        ),
      );
    }
  }

  // ============================================================
  // GET /tasks/summary
  // ============================================================

  Future<Map<String, dynamic>> getTaskSummary({
    String scope = 'mine',
  }) async {
    try {
      final response = await apiClient.get(
        '/tasks/summary',
        queryParameters: {
          'scope': scope,
        },
      );

      debugPrint(
        '========== TASK SUMMARY =========',
      );
      debugPrint(
        response.data.toString(),
      );
      debugPrint(
        '=================================',
      );

      return Map<String, dynamic>.from(
        response.data,
      );
    } on DioException catch (e) {
      debugPrint(
        '❌ TASK SUMMARY ERROR: ${e.response?.data}',
      );

      throw Exception(
        _getErrorMessage(
          e,
          'Unable to fetch task summary.',
        ),
      );
    }
  }

  // ============================================================
  // PATCH /tasks/{id}/status
  // ============================================================

  Future<Map<String, dynamic>> updateTaskStatus({
    required int taskId,
    required String status,
  }) async {
    try {
      final response = await apiClient.dio.patch(
        '/tasks/$taskId/status',
        data: {
          'status': status,
        },
      );

      debugPrint(
        '========== TASK STATUS =========',
      );
      debugPrint(
        response.data.toString(),
      );
      debugPrint(
        '================================',
      );

      return Map<String, dynamic>.from(
        response.data,
      );
    } on DioException catch (e) {
      debugPrint(
        '❌ UPDATE TASK STATUS ERROR: ${e.response?.data}',
      );

      throw Exception(
        _getErrorMessage(
          e,
          'Unable to update task status.',
        ),
      );
    }
  }

  // ============================================================
  // GET /tasks/{id}/comments
  // ============================================================

  Future<List<Map<String, dynamic>>> getTaskComments(
    int taskId,
  ) async {
    try {
      final response = await apiClient.get(
        '/tasks/$taskId/comments',
      );

      final responseData = response.data;

      if (responseData is! Map) {
        throw Exception(
          'Invalid task comments response.',
        );
      }

      final data = responseData['data'];

      if (data is! List) {
        return [];
      }

      return data
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(
              item,
            ),
          )
          .toList();
    } on DioException catch (e) {
      debugPrint(
        '❌ GET TASK COMMENTS ERROR: ${e.response?.data}',
      );

      throw Exception(
        _getErrorMessage(
          e,
          'Unable to fetch task comments.',
        ),
      );
    }
  }

  // ============================================================
  // POST /tasks/{id}/comments
  // ============================================================

  Future<Map<String, dynamic>> addTaskComment({
    required int taskId,
    required String body,
  }) async {
    if (body.trim().isEmpty) {
      throw Exception(
        'Comment cannot be empty.',
      );
    }

    try {
      final response = await apiClient.post(
        '/tasks/$taskId/comments',
        data: {
          'body': body.trim(),
        },
      );

      return Map<String, dynamic>.from(
        response.data,
      );
    } on DioException catch (e) {
      debugPrint(
        '❌ ADD COMMENT ERROR: ${e.response?.data}',
      );

      throw Exception(
        _getErrorMessage(
          e,
          'Unable to add comment.',
        ),
      );
    }
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  String _getErrorMessage(
    DioException e,
    String fallback,
  ) {
    final data = e.response?.data;

    if (data is Map) {
      final message = data['message'];

      if (message != null &&
          message.toString().isNotEmpty) {
        return message.toString();
      }
    }

    return e.message ?? fallback;
  }
}

// ============================================================
// PROVIDER
// ============================================================

final taskRepositoryProvider =
    Provider<TaskRepository>((ref) {
  return TaskRepository(
    apiClient: ref.read(apiClientProvider),
  );
});