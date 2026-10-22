import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/network/network_providers.dart';

import '../data/floor_repository.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

final floorRepositoryProvider = Provider<FloorRepository>((ref) {
  return FloorRepository(apiClient: ref.read(apiClientProvider));
});

final floorProvider = StateNotifierProvider<FloorNotifier, FloorState>((ref) {
  return FloorNotifier(ref.read(floorRepositoryProvider));
});

/// Colleagues who could take over, read when the handover sheet opens.
final floorColleaguesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.read(floorRepositoryProvider).getColleagues();
});

// ============================================================================
// STATE
// ============================================================================

class FloorState {
  final bool isLoading;
  final bool loaded;
  final String? error;
  final List<Map<String, dynamic>> tasks;

  /// The task whose start/pause is in flight.
  final int? busyTaskId;
  final bool isSaving;

  const FloorState({
    this.isLoading = false,
    this.loaded = false,
    this.error,
    this.tasks = const [],
    this.busyTaskId,
    this.isSaving = false,
  });

  FloorState copyWith({
    bool? isLoading,
    bool? loaded,
    String? error,
    bool clearError = false,
    List<Map<String, dynamic>>? tasks,
    int? busyTaskId,
    bool clearBusy = false,
    bool? isSaving,
  }) {
    return FloorState(
      isLoading: isLoading ?? this.isLoading,
      loaded: loaded ?? this.loaded,
      error: clearError ? null : error ?? this.error,
      tasks: tasks ?? this.tasks,
      busyTaskId: clearBusy ? null : busyTaskId ?? this.busyTaskId,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================

class FloorNotifier extends StateNotifier<FloorState> {
  final FloorRepository repository;

  FloorNotifier(this.repository) : super(const FloorState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final tasks = await repository.getMyTasks();

      state = state.copyWith(isLoading: false, loaded: true, tasks: tasks);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        loaded: true,
        tasks: const [],
        error: cleanErrorMessage(e),
      );
    }
  }

  /// Start or resume the clock. Returns null on success, or the error.
  Future<String?> start(int taskId) =>
      _clock(taskId, () => repository.startTask(taskId));

  /// Returns null on success, or the error.
  Future<String?> pause(int taskId) =>
      _clock(taskId, () => repository.pauseTask(taskId));

  Future<String?> _clock(int taskId, Future<void> Function() call) async {
    state = state.copyWith(busyTaskId: taskId);

    try {
      await call();

      state = state.copyWith(clearBusy: true);

      await load();

      return null;
    } catch (e) {
      state = state.copyWith(clearBusy: true);

      return cleanErrorMessage(e);
    }
  }

  /// Record what came off the machine. An order that was assigned but never
  /// started is started first, as the web does. Returns null on success.
  Future<String?> recordOutput({
    required int workOrderId,
    required String workOrderStatus,
    required num good,
    required num rejected,
    required num waste,
    String? notes,
  }) async {
    state = state.copyWith(isSaving: true);

    try {
      if (const ['ASSIGNED', 'READY'].contains(workOrderStatus)) {
        await repository.startWorkOrder(workOrderId);
      }

      await repository.recordOutput(
        workOrderId,
        goodQuantity: good,
        rejectedQuantity: rejected,
        wasteQuantity: waste,
        notes: notes,
      );

      state = state.copyWith(isSaving: false);

      await load();

      return null;
    } catch (e) {
      state = state.copyWith(isSaving: false);

      return cleanErrorMessage(e);
    }
  }

  /// Hand the rest of the step over. Returns null on success.
  Future<String?> requestHandover({
    required int taskId,
    required String reason,
    int? suggestedUserId,
  }) async {
    state = state.copyWith(isSaving: true);

    try {
      await repository.requestHandover(
        taskId,
        reason: reason,
        suggestedUserId: suggestedUserId,
      );

      state = state.copyWith(isSaving: false);

      await load();

      return null;
    } catch (e) {
      state = state.copyWith(isSaving: false);

      return cleanErrorMessage(e);
    }
  }
}
