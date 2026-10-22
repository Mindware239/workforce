import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/api_error.dart';

/// The employee's side of `/api/leaves`, as the web Leave page uses it.
///
/// `/leaves/mine` rows keep the database's snake_case names
/// (`leave_category`, `start_date`, `total_days`, ...); `/leaves/balances`
/// answers `{ balances: [...], permission, ledger }`.
class LeaveRepository {
  final ApiClient apiClient;

  LeaveRepository({
    required this.apiClient,
  });

  /// The request body, as JSON or (with a voice note) as multipart.
  Future<Object> _payload({
    String? leaveType,
    String? leaveCategory,
    String? startDate,
    String? endDate,
    String? halfDaySession,
    String? startTime,
    String? endTime,
    String? reason,
    String? voiceNotePath,
  }) async {
    final fields = <String, dynamic>{
      'leaveType': ?leaveType,
      'leaveCategory': ?leaveCategory,
      'startDate': ?startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      if (halfDaySession != null && halfDaySession.isNotEmpty)
        'halfDaySession': halfDaySession,
      if (startTime != null && startTime.isNotEmpty) 'startTime': startTime,
      if (endTime != null && endTime.isNotEmpty) 'endTime': endTime,
      'reason': ?reason,
    };

    if (voiceNotePath == null || voiceNotePath.isEmpty) return fields;

    final name = voiceNotePath.split(RegExp(r'[\\/]')).last;

    return FormData.fromMap({
      ...fields,
      'voiceNote': await MultipartFile.fromFile(voiceNotePath, filename: name),
    });
  }

  // ============================================================
  // APPLY LEAVE — POST /api/leaves
  // ============================================================

  /// leaveType: full_day | half_day | partial (hours / permission)
  /// leaveCategory: casual | sick | earned | unpaid | comp_off
  Future<Map<String, dynamic>> applyLeave({
    required String leaveType,
    required String leaveCategory,
    required String startDate,
    String? endDate,
    String? halfDaySession,
    String? startTime,
    String? endTime,
    required String reason,
    String? voiceNotePath,
  }) async {
    try {
      final response = await apiClient.post(
        '/leaves',
        data: await _payload(
          leaveType: leaveType,
          leaveCategory: leaveCategory,
          startDate: startDate,
          endDate: endDate,
          halfDaySession: halfDaySession,
          startTime: startTime,
          endTime: endTime,
          reason: reason,
          voiceNotePath: voiceNotePath,
        ),
      );

      return asMap(response.data);
    } catch (e) {
      throw apiException(e, 'Unable to submit leave request.');
    }
  }

  /// PUT /api/leaves/:id/resubmit — only for a request sent back for changes.
  Future<Map<String, dynamic>> resubmitLeave(
    int id, {
    required String leaveType,
    required String leaveCategory,
    required String startDate,
    String? endDate,
    String? halfDaySession,
    String? startTime,
    String? endTime,
    required String reason,
    String? voiceNotePath,
  }) async {
    try {
      final response = await apiClient.put(
        '/leaves/$id/resubmit',
        data: await _payload(
          leaveType: leaveType,
          leaveCategory: leaveCategory,
          startDate: startDate,
          endDate: endDate,
          halfDaySession: halfDaySession,
          startTime: startTime,
          endTime: endTime,
          reason: reason,
          voiceNotePath: voiceNotePath,
        ),
      );

      return asMap(response.data);
    } catch (e) {
      throw apiException(e, 'Unable to resubmit the request.');
    }
  }

  // ============================================================
  // GET /api/leaves/balances
  // ============================================================

  /// `{ balances: [{category, total, used, pending, remaining}],
  ///    permission: {cap, perRequest, used, pending, remaining} | null,
  ///    ledger: [...] }`
  Future<Map<String, dynamic>> getBalanceSheet({int? year}) async {
    try {
      final response = await apiClient.get(
        '/leaves/balances',
        queryParameters: {'year': ?year},
      );

      final data = unwrapData(response.data);

      // Older servers answered the bare list.
      if (data is List) return {'balances': asMapList(data)};

      return asMap(data);
    } catch (e) {
      throw apiException(e, 'Unable to load leave balances.');
    }
  }

  // ============================================================
  // GET /api/leaves/mine
  // ============================================================

  Future<List<Map<String, dynamic>>> getMyLeaveRequests() async {
    try {
      final response = await apiClient.get('/leaves/mine');

      return asMapList(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to load leave requests.');
    }
  }

  // ============================================================
  // ONE REQUEST
  // ============================================================

  /// GET /api/leaves/:id -> `{ leave, approvals, events, balance,
  /// workflow, permissions: {canCancel, canResubmit, canComment, ...} }`
  Future<Map<String, dynamic>> getLeave(int id) async {
    try {
      final response = await apiClient.get('/leaves/$id');

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Could not load this request.');
    }
  }

  /// PUT /api/leaves/:id/cancel — withdraw a request.
  Future<void> cancelLeave(int id) async {
    try {
      await apiClient.put('/leaves/$id/cancel');
    } catch (e) {
      throw apiException(e, 'Could not withdraw this request.');
    }
  }

  /// POST /api/leaves/:id/comments `{ note }`
  Future<void> addComment(int id, String note) async {
    try {
      await apiClient.post('/leaves/$id/comments', data: {'note': note});
    } catch (e) {
      throw apiException(e, 'Could not post the comment.');
    }
  }

  /// GET /api/leaves/:id/voice-note — the recording's bytes.
  Future<Uint8List> getVoiceNote(int id) async {
    try {
      final response = await apiClient.dio.get<List<int>>(
        '/leaves/$id/voice-note',
        options: Options(responseType: ResponseType.bytes),
      );

      return Uint8List.fromList(response.data ?? const []);
    } catch (e) {
      throw apiException(e, 'Could not load the voice note.');
    }
  }
}
