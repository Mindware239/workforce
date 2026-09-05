import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/features/task/data/task_repository.dart';

enum TaskStatus { initial, loading, success, error }

class TaskState {
  final TaskStatus status;

  final List<Map<String, dynamic>> tasks;

  final int total;
  final int page;
  final int limit;

  // Summary
  final int totalCount;
  final int pendingCount;
  final int inProgressCount;
  final int completedCount;
  final int overdueCount;

  // Current filters
  final String scope;
  final String? selectedStatus;

  // Details
  final Map<String, dynamic>? selectedTask;
  final List<Map<String, dynamic>> comments;

  final bool isLoadingTask;
  final bool isLoadingComments;
  final bool isUpdatingStatus;

  final String? message;

  const TaskState({
    this.status = TaskStatus.initial,
    this.tasks = const [],
    this.total = 0,
    this.page = 1,
    this.limit = 50,
    this.totalCount = 0,
    this.pendingCount = 0,
    this.inProgressCount = 0,
    this.completedCount = 0,
    this.overdueCount = 0,
    this.scope = 'mine',
    this.selectedStatus,
    this.selectedTask,
    this.comments = const [],
    this.isLoadingTask = false,
    this.isLoadingComments = false,
    this.isUpdatingStatus = false,
    this.message,
  });

  TaskState copyWith({
    TaskStatus? status,
    List<Map<String, dynamic>>? tasks,
    int? total,
    int? page,
    int? limit,
    int? totalCount,
    int? pendingCount,
    int? inProgressCount,
    int? completedCount,
    int? overdueCount,
    String? scope,
    String? selectedStatus,
    bool clearSelectedStatus = false,
    Map<String, dynamic>? selectedTask,
    bool clearSelectedTask = false,
    List<Map<String, dynamic>>? comments,
    bool? isLoadingTask,
    bool? isLoadingComments,
    bool? isUpdatingStatus,
    String? message,
    bool clearMessage = false,
  }) {
    return TaskState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      total: total ?? this.total,
      page: page ?? this.page,
      limit: limit ?? this.limit,

      totalCount: totalCount ?? this.totalCount,

      pendingCount: pendingCount ?? this.pendingCount,

      inProgressCount: inProgressCount ?? this.inProgressCount,

      completedCount: completedCount ?? this.completedCount,

      overdueCount: overdueCount ?? this.overdueCount,

      scope: scope ?? this.scope,

      selectedStatus: clearSelectedStatus
          ? null
          : selectedStatus ?? this.selectedStatus,

      selectedTask: clearSelectedTask
          ? null
          : selectedTask ?? this.selectedTask,

      comments: comments ?? this.comments,

      isLoadingTask: isLoadingTask ?? this.isLoadingTask,

      isLoadingComments: isLoadingComments ?? this.isLoadingComments,

      isUpdatingStatus: isUpdatingStatus ?? this.isUpdatingStatus,

      message: clearMessage ? null : message ?? this.message,
    );
  }
}

class TaskNotifier extends Notifier<TaskState> {
  late final TaskRepository repository;

  @override
  TaskState build() {
    repository = ref.read(taskRepositoryProvider);

    return const TaskState();
  }

  // ============================================================
  // LOAD TASKS
  // ============================================================

  Future<void> fetchTasks({
    String scope = 'mine',
    String? status,
    int page = 1,
  }) async {
    state = state.copyWith(
      status: TaskStatus.loading,
      scope: scope,
      selectedStatus: status,
      clearSelectedStatus: status == null,
      clearMessage: true,
    );

    try {
      final response = await repository.getTasks(
        scope: scope,
        status: status,
        page: page,
        limit: 50,
      );

      final data = response['data'];

      if (data is! Map) {
        throw Exception('Invalid tasks response.');
      }

      final List<Map<String, dynamic>> items = [];

      final rawItems = data['items'];

      if (rawItems is List) {
        for (final item in rawItems) {
          if (item is Map) {
            items.add(Map<String, dynamic>.from(item));
          }
        }
      }

      state = state.copyWith(
        status: TaskStatus.success,
        tasks: items,
        total: _toInt(data['total']),
        page: _toInt(data['page']),
        limit: _toInt(data['limit']),
        clearMessage: true,
      );
    } catch (e) {
      state = state.copyWith(status: TaskStatus.error, message: _cleanError(e));
    }
  }

  Future<void> fetchSummary({String scope = 'mine'}) async {
    try {
      final response = await repository.getTaskSummary(scope: scope);

      final data = response['data'];

      if (data is! Map) {
        return;
      }

      state = state.copyWith(
        totalCount: _toInt(data['total']),
        pendingCount: _toInt(data['pending']),
        inProgressCount: _toInt(data['inProgress']),
        completedCount: _toInt(data['completed']),
        overdueCount: _toInt(data['overdue']),
      );
    } catch (_) {
      // Summary failure should not
      // break the task list.
    }
  }

  Future<void> loadTasks({String scope = 'mine', String? status}) async {
    await Future.wait([
      fetchTasks(scope: scope, status: status, page: 1),
      fetchSummary(scope: scope),
    ]);
  }

  Future<bool> fetchTask(int taskId) async {
    state = state.copyWith(isLoadingTask: true, clearMessage: true);

    try {
      final response = await repository.getTask(taskId);

      final data = response['data'];

      if (data is! Map) {
        throw Exception('Invalid task details response.');
      }

      final task = Map<String, dynamic>.from(data);

      state = state.copyWith(selectedTask: task, isLoadingTask: false);

      return true;
    } catch (e) {
      state = state.copyWith(isLoadingTask: false, message: _cleanError(e));

      return false;
    }
  }
  // ============================================================
  // START / UPDATE TASK
  // ============================================================

  Future<bool> updateTaskStatus({
    required int taskId,
    required String status,
  }) async {
    state = state.copyWith(isUpdatingStatus: true, clearMessage: true);

    try {
      await repository.updateTaskStatus(taskId: taskId, status: status);

      // Refresh selected task
      await fetchTask(taskId);

      // Refresh task list + summary
      await loadTasks(scope: state.scope, status: state.selectedStatus);

      state = state.copyWith(isUpdatingStatus: false);

      return true;
    } catch (e) {
      state = state.copyWith(isUpdatingStatus: false, message: _cleanError(e));

      return false;
    }
  }
  // ============================================================
  // GET COMMENTS
  // ============================================================

  Future<bool> fetchComments(int taskId) async {
    state = state.copyWith(isLoadingComments: true, clearMessage: true);

    try {
      final comments = await repository.getTaskComments(taskId);

      state = state.copyWith(comments: comments, isLoadingComments: false);

      return true;
    } catch (e) {
      state = state.copyWith(isLoadingComments: false, message: _cleanError(e));

      return false;
    }
  }

  // ============================================================
  // ADD COMMENT
  // ============================================================

  Future<bool> addComment({required int taskId, required String body}) async {
    try {
      await repository.addTaskComment(taskId: taskId, body: body);

      await fetchComments(taskId);

      return true;
    } catch (e) {
      state = state.copyWith(message: _cleanError(e));

      return false;
    }
  }

  // ============================================================
  // CLEAR DETAILS
  // ============================================================

  void clearSelectedTask() {
    state = state.copyWith(clearSelectedTask: true, comments: const []);
  }

  // ============================================================
  // HELPERS
  // ============================================================

  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}

// ============================================================
// PROVIDER
// ============================================================

final taskProvider = NotifierProvider<TaskNotifier, TaskState>(
  TaskNotifier.new,
);
