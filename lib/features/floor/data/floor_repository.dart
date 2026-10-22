import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/api_error.dart';

/// The production floor — backend/modules/production and modules/tasks.
/// Same calls as the web employee page `/employee/floor`.
///
/// A floor task (GET /production/my-tasks) carries: taskId, title, status
/// (pending|accepted|in_progress|paused|blocked|changes_requested|submitted|
/// completed|cancelled|rejected), targetQuantity, completedQuantity,
/// progressPercent, totalActiveMinutes, workOrderId, workOrderNumber,
/// workOrderStatus (ASSIGNED|READY|IN_PROGRESS|PAUSED|HANDOVER_PENDING|...),
/// requiredQuantity, requiresQc, productName, variantName, unitCode,
/// stepName, sequenceNumber, workCenterName, openHandoverId.
class FloorRepository {
  final ApiClient apiClient;

  FloorRepository({required this.apiClient});

  // GET /api/production/my-tasks
  Future<List<Map<String, dynamic>>> getMyTasks() async {
    try {
      final response = await apiClient.get('/production/my-tasks');

      return asMapList(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to load your production steps.');
    }
  }

  // POST /api/tasks/:id/start — starts (or resumes) the clock.
  Future<void> startTask(int taskId) async {
    try {
      await apiClient.post('/tasks/$taskId/start');
    } catch (e) {
      throw apiException(e, 'Unable to start the clock.');
    }
  }

  // POST /api/tasks/:id/pause
  Future<void> pauseTask(int taskId) async {
    try {
      await apiClient.post('/tasks/$taskId/pause');
    } catch (e) {
      throw apiException(e, 'Unable to pause.');
    }
  }

  // POST /api/production/work-orders/:id/start — an order that was assigned
  // but never started is started by its first output.
  Future<void> startWorkOrder(int workOrderId) async {
    try {
      await apiClient.post(
        '/production/work-orders/$workOrderId/start',
        data: <String, dynamic>{},
      );
    } catch (e) {
      throw apiException(e, 'Unable to start the work order.');
    }
  }

  // POST /api/production/work-orders/:id/output
  //   { goodQuantity, rejectedQuantity, wasteQuantity, notes }
  Future<void> recordOutput(
    int workOrderId, {
    required num goodQuantity,
    required num rejectedQuantity,
    required num wasteQuantity,
    String? notes,
  }) async {
    try {
      await apiClient.post(
        '/production/work-orders/$workOrderId/output',
        data: {
          'goodQuantity': goodQuantity,
          'rejectedQuantity': rejectedQuantity,
          'wasteQuantity': wasteQuantity,
          'notes': notes,
        },
      );
    } catch (e) {
      throw apiException(e, 'Unable to record the output.');
    }
  }

  // POST /api/production/tasks/:taskId/handover { reason, suggestedUserId }
  Future<void> requestHandover(
    int taskId, {
    required String reason,
    int? suggestedUserId,
  }) async {
    try {
      await apiClient.post(
        '/production/tasks/$taskId/handover',
        data: {'reason': reason, 'suggestedUserId': suggestedUserId},
      );
    } catch (e) {
      throw apiException(e, 'Unable to request the handover.');
    }
  }

  // GET /api/users?role=employee&isActive=true&limit=200
  //
  // The colleague picker, as on the web. The route is admin-only, so for
  // most employees it is refused; the picker then offers only "let the
  // manager decide", which is what the web shows in that case too.
  Future<List<Map<String, dynamic>>> getColleagues() async {
    try {
      final response = await apiClient.get(
        '/users',
        queryParameters: {'role': 'employee', 'isActive': true, 'limit': 200},
      );

      final data = unwrapData(response.data);

      if (data is List) return asMapList(data);

      final map = asMap(data);

      return asMapList(map['items'] ?? map['users']);
    } catch (_) {
      return [];
    }
  }
}
