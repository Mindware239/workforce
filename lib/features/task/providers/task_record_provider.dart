import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:workforce/core/network/api_error.dart';
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

/// The employee's moves on a task, used by the detail screen.
class TaskActions {
  final TaskRepository repository;

  TaskActions(this.repository);

  Future<String?> run(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } catch (e) {
      return cleanErrorMessage(e);
    }
  }
}

final taskActionsProvider = Provider<TaskActions>((ref) {
  return TaskActions(ref.read(taskRepositoryProvider));
});
