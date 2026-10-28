import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/offline/offline_queue_models.dart';
import 'package:workforce/core/offline/offline_sync_service.dart';
import 'package:workforce/features/task/data/task_repository.dart';

/// The read side of one task and of the employee's own record: the full
/// detail (timeline, reviews, checklist, files, permissions), its notes,
/// attachment bytes, the performance report and the history list.

/// GET /tasks/:id/detail, fetched fresh each time a task is opened.
final taskDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, taskId) {
  return ref.read(taskRepositoryProvider).getTaskDetail(taskId);
});

/// GET /tasks/:id/comments.
final taskCommentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, taskId) {
  return ref.read(taskRepositoryProvider).getTaskComments(taskId);
});

/// The bytes of one attachment, for an image thumbnail or preview.
final taskAttachmentBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, ({int taskId, int attachmentId})>((ref, key) {
  return ref
      .read(taskRepositoryProvider)
      .downloadAttachment(key.taskId, key.attachmentId);
});

typedef TaskPeriodQuery = ({String period, String? from, String? to});

/// GET /tasks/performance for the signed-in employee.
final taskPerformanceProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, TaskPeriodQuery>((ref, query) {
  return ref.read(taskRepositoryProvider).getPerformance(
        period: query.period,
        from: query.from,
        to: query.to,
      );
});

typedef TaskHistoryQuery = ({
  String period,
  String? from,
  String? to,
  String? outcome,
  int page,
});

const int taskHistoryPageSize = 15;

/// GET /tasks/history, one page at a time.
final taskHistoryProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, TaskHistoryQuery>((ref, query) {
  return ref.read(taskRepositoryProvider).getHistory(
        period: query.period,
        from: query.from,
        to: query.to,
        outcome: query.outcome,
        page: query.page,
        limit: taskHistoryPageSize,
      );
});

typedef TaskActionResult = ({bool success, bool isOffline, String? error});

/// The employee's moves on a task, used by the detail screen with offline queueing support.
class TaskActions {
  final TaskRepository repository;
  final Ref ref;

  TaskActions(this.repository, this.ref);

  Future<String?> run(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } catch (e) {
      return cleanErrorMessage(e);
    }
  }

  Future<TaskActionResult> runLifecycle(
    int taskId,
    String action, {
    Map<String, dynamic>? data,
  }) async {
    try {
      await repository.runLifecycleAction(taskId, action, data: data);
      return (success: true, isOffline: false, error: null);
    } catch (e) {
      if (isNetworkError(e)) {
        await ref.read(offlineSyncProvider.notifier).queueTaskAction(
          TaskQueueItem(
            id: 'task_${DateTime.now().millisecondsSinceEpoch}',
            taskId: taskId,
            actionType: 'lifecycle',
            action: action,
            payload: data,
            timestamp: DateTime.now(),
          ),
        );
        return (success: true, isOffline: true, error: null);
      }
      return (success: false, isOffline: false, error: cleanErrorMessage(e));
    }
  }

  Future<TaskActionResult> setProgress(
    int taskId,
    int percent,
  ) async {
    try {
      await repository.setProgress(taskId, percent);
      return (success: true, isOffline: false, error: null);
    } catch (e) {
      if (isNetworkError(e)) {
        await ref.read(offlineSyncProvider.notifier).queueTaskAction(
          TaskQueueItem(
            id: 'task_${DateTime.now().millisecondsSinceEpoch}',
            taskId: taskId,
            actionType: 'progress',
            payload: {'progressPercent': percent},
            timestamp: DateTime.now(),
          ),
        );
        return (success: true, isOffline: true, error: null);
      }
      return (success: false, isOffline: false, error: cleanErrorMessage(e));
    }
  }

  Future<TaskActionResult> tickChecklist(
    int taskId,
    int itemId,
    bool done,
  ) async {
    try {
      await repository.tickChecklist(taskId, itemId, done);
      return (success: true, isOffline: false, error: null);
    } catch (e) {
      if (isNetworkError(e)) {
        await ref.read(offlineSyncProvider.notifier).queueTaskAction(
          TaskQueueItem(
            id: 'task_${DateTime.now().millisecondsSinceEpoch}',
            taskId: taskId,
            actionType: 'checklist',
            itemId: itemId,
            done: done,
            timestamp: DateTime.now(),
          ),
        );
        return (success: true, isOffline: true, error: null);
      }
      return (success: false, isOffline: false, error: cleanErrorMessage(e));
    }
  }

  Future<TaskActionResult> uploadAttachments(
    int taskId, {
    required List<({String path, String name})> files,
    String? caption,
  }) async {
    try {
      await repository.uploadAttachments(taskId, files: files, caption: caption);
      return (success: true, isOffline: false, error: null);
    } catch (e) {
      if (isNetworkError(e)) {
        await ref.read(offlineSyncProvider.notifier).queueTaskAction(
          TaskQueueItem(
            id: 'task_${DateTime.now().millisecondsSinceEpoch}',
            taskId: taskId,
            actionType: 'attachment',
            files: files.map((f) => {'path': f.path, 'name': f.name}).toList(),
            caption: caption,
            timestamp: DateTime.now(),
          ),
        );
        return (success: true, isOffline: true, error: null);
      }
      return (success: false, isOffline: false, error: cleanErrorMessage(e));
    }
  }

  Future<TaskActionResult> addTaskComment(
    int taskId,
    String body,
  ) async {
    try {
      await repository.addTaskComment(taskId: taskId, body: body);
      return (success: true, isOffline: false, error: null);
    } catch (e) {
      if (isNetworkError(e)) {
        await ref.read(offlineSyncProvider.notifier).queueTaskAction(
          TaskQueueItem(
            id: 'task_${DateTime.now().millisecondsSinceEpoch}',
            taskId: taskId,
            actionType: 'comment',
            payload: {'body': body},
            timestamp: DateTime.now(),
          ),
        );
        return (success: true, isOffline: true, error: null);
      }
      return (success: false, isOffline: false, error: cleanErrorMessage(e));
    }
  }
}

final taskActionsProvider = Provider<TaskActions>((ref) {
  return TaskActions(ref.read(taskRepositoryProvider), ref);
});
