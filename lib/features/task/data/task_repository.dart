import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/api_error.dart';
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
  // GET /tasks/{id}/detail
  // The task with its timeline, reviews, sessions, checklist,
  // files and the server's `permissions` for the caller.
  // ============================================================

  Future<Map<String, dynamic>> getTaskDetail(int taskId) async {
    try {
      final response = await apiClient.get('/tasks/$taskId/detail');

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to load the task.');
    }
  }

  // ============================================================
  // LIFECYCLE (the employee's moves)
  // POST /tasks/{id}/accept | start | pause | unblock
  // POST /tasks/{id}/block   { reasonCode, note? }
  // POST /tasks/{id}/submit  { note? }
  // ============================================================

  Future<void> runLifecycleAction(
    int taskId,
    String action, {
    Map<String, dynamic>? data,
  }) async {
    try {
      await apiClient.post('/tasks/$taskId/$action', data: data ?? {});
    } catch (e) {
      throw apiException(e, 'Unable to update the task.');
    }
  }

  // ============================================================
  // PATCH /tasks/{id}/progress  { progressPercent 0-100 }
  // ============================================================

  Future<void> setProgress(int taskId, int percent) async {
    try {
      await apiClient.dio.patch(
        '/tasks/$taskId/progress',
        data: {'progressPercent': percent},
      );
    } catch (e) {
      throw apiException(e, 'Unable to update progress.');
    }
  }

  // ============================================================
  // PATCH /tasks/{id}/checklist/{itemId}  { done }
  // ============================================================

  Future<void> tickChecklist(int taskId, int itemId, bool done) async {
    try {
      await apiClient.dio.patch(
        '/tasks/$taskId/checklist/$itemId',
        data: {'done': done},
      );
    } catch (e) {
      throw apiException(e, 'Unable to update the checklist.');
    }
  }

  // ============================================================
  // POST /tasks/{id}/attachments  multipart `files` (up to 10),
  // `kind` = proof for an employee, optional `caption`.
  // Photos, PDF, Word, Excel or text.
  // ============================================================

  Future<void> uploadAttachments(
    int taskId, {
    required List<({String path, String name})> files,
    String? caption,
  }) async {
    try {
      final formData = FormData();

      for (final file in files) {
        formData.files.add(
          MapEntry(
            'files',
            await MultipartFile.fromFile(
              file.path,
              filename: file.name,
              contentType: _mediaTypeFor(file.name),
            ),
          ),
        );
      }

      formData.fields.add(const MapEntry('kind', 'proof'));

      if (caption != null && caption.trim().isNotEmpty) {
        formData.fields.add(MapEntry('caption', caption.trim()));
      }

      await apiClient.dio.post('/tasks/$taskId/attachments', data: formData);
    } catch (e) {
      throw apiException(e, 'Unable to upload the files.');
    }
  }

  // ============================================================
  // GET /tasks/{id}/attachments/{attachmentId}  (bytes)
  // ============================================================

  Future<Uint8List> downloadAttachment(int taskId, int attachmentId) async {
    try {
      final response = await apiClient.dio.get<List<int>>(
        '/tasks/$taskId/attachments/$attachmentId',
        options: Options(responseType: ResponseType.bytes),
      );

      return Uint8List.fromList(response.data ?? const []);
    } catch (e) {
      throw apiException(e, 'Unable to open the file.');
    }
  }

  /// Saves an attachment to Downloads (Android) or the app documents folder
  /// and returns the saved path.
  Future<String> saveAttachment(
    int taskId,
    int attachmentId,
    String fileName,
  ) async {
    final bytes = await downloadAttachment(taskId, attachmentId);

    Directory directory = Directory('/storage/emulated/0/Download');

    if (!Platform.isAndroid || !await directory.exists()) {
      directory = await getApplicationDocumentsDirectory();
    }

    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${directory.path}/$safeName');

    await file.writeAsBytes(bytes, flush: true);

    return file.path;
  }

  // ============================================================
  // DELETE /tasks/{id}/attachments/{attachmentId}
  // (an employee may remove only their own uploads)
  // ============================================================

  Future<void> removeAttachment(int taskId, int attachmentId) async {
    try {
      await apiClient.delete('/tasks/$taskId/attachments/$attachmentId');
    } catch (e) {
      throw apiException(e, 'Unable to remove the file.');
    }
  }

  // ============================================================
  // GET /tasks/performance?period=&from=&to=
  // ============================================================

  Future<Map<String, dynamic>> getPerformance({
    required String period,
    String? from,
    String? to,
  }) async {
    try {
      final response = await apiClient.get(
        '/tasks/performance',
        queryParameters: {
          'period': period,
          if (period == 'custom' && from != null) 'from': from,
          if (period == 'custom' && to != null) 'to': to,
        },
      );

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Could not load your report.');
    }
  }

  // ============================================================
  // GET /tasks/history?period=&from=&to=&outcome=&page=&limit=
  // ============================================================

  Future<Map<String, dynamic>> getHistory({
    required String period,
    String? from,
    String? to,
    String? outcome,
    int page = 1,
    int limit = 15,
  }) async {
    try {
      final response = await apiClient.get(
        '/tasks/history',
        queryParameters: {
          'period': period,
          if (period == 'custom' && from != null) 'from': from,
          if (period == 'custom' && to != null) 'to': to,
          if (outcome != null && outcome.isNotEmpty) 'outcome': outcome,
          'page': page,
          'limit': limit,
        },
      );

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Could not load your record.');
    }
  }

  static DioMediaType? _mediaTypeFor(String name) {
    final lower = name.toLowerCase();

    if (lower.endsWith('.pdf')) return DioMediaType('application', 'pdf');
    if (lower.endsWith('.png')) return DioMediaType('image', 'png');
    if (lower.endsWith('.webp')) return DioMediaType('image', 'webp');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return DioMediaType('image', 'jpeg');
    }
    if (lower.endsWith('.txt')) return DioMediaType('text', 'plain');
    if (lower.endsWith('.csv')) return DioMediaType('text', 'csv');
    if (lower.endsWith('.doc')) return DioMediaType('application', 'msword');
    if (lower.endsWith('.docx')) {
      return DioMediaType(
        'application',
        'vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    }
    if (lower.endsWith('.xls')) {
      return DioMediaType('application', 'vnd.ms-excel');
    }
    if (lower.endsWith('.xlsx')) {
      return DioMediaType(
        'application',
        'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    }

    return null;
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