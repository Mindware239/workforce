import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/network_providers.dart';

import '../data/leave_repository.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepository(
    apiClient: ref.read(apiClientProvider),
  );
});

final leaveProvider =
    StateNotifierProvider<LeaveNotifier, LeaveState>((ref) {
  return LeaveNotifier(
    ref.read(leaveRepositoryProvider),
  );
});

// ============================================================================
// LEAVE STATE
// ============================================================================

class LeaveState {
  final bool isLoading;
  final bool isLoadingRequests;
  final String? error;
  final Map<String, dynamic>? data;
  final List<Map<String, dynamic>> requests;

  const LeaveState({
    this.isLoading = false,
    this.isLoadingRequests = false,
    this.error,
    this.data,
    this.requests = const [],
  });

  LeaveState copyWith({
    bool? isLoading,
    bool? isLoadingRequests,
    String? error,
    Map<String, dynamic>? data,
    List<Map<String, dynamic>>? requests,
    bool clearError = false,
  }) {
    return LeaveState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingRequests:
          isLoadingRequests ?? this.isLoadingRequests,
      error: clearError
          ? null
          : error ?? this.error,
      data: data ?? this.data,
      requests: requests ?? this.requests,
    );
  }
}

// ============================================================================
// LEAVE NOTIFIER
// ============================================================================

class LeaveNotifier
    extends StateNotifier<LeaveState> {
  final LeaveRepository repository;

  LeaveNotifier(this.repository)
      : super(const LeaveState());

  // ============================================================
  // APPLY LEAVE
  // ============================================================

  Future<bool> applyLeave({
    required String leaveType,
    required String leaveCategory,
    required String startDate,
    String? endDate,
    String? startTime,
    String? endTime,
    required String reason,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final response =
          await repository.applyLeave(
        leaveType: leaveType,
        leaveCategory: leaveCategory,
        startDate: startDate,
        endDate: endDate,
        startTime: startTime,
        endTime: endTime,
        reason: reason,
      );

      // --------------------------------------------------------
      // API SUCCESS CHECK
      // --------------------------------------------------------

      if (response['success'] != true) {
        state = state.copyWith(
          isLoading: false,
          error: response['message']
                  ?.toString() ??
              'Unable to submit leave request.',
        );

        return false;
      }

      // --------------------------------------------------------
      // SAVE RESPONSE DATA
      // --------------------------------------------------------

      Map<String, dynamic>? responseData;

      if (response['data'] is Map) {
        responseData =
            Map<String, dynamic>.from(
          response['data'],
        );
      }

      state = state.copyWith(
        isLoading: false,
        data: responseData,
        clearError: true,
      );

      // --------------------------------------------------------
      // REFRESH RECENT REQUESTS
      // --------------------------------------------------------

      await getMyLeaveRequests();

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _cleanError(e),
      );

      return false;
    }
  }

  // ============================================================
  // GET MY LEAVE REQUESTS
  // ============================================================

  Future<void> getMyLeaveRequests() async {
    state = state.copyWith(
      isLoadingRequests: true,
      clearError: true,
    );

    try {
      final requests =
          await repository.getMyLeaveRequests();

      state = state.copyWith(
        isLoadingRequests: false,
        requests: requests,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingRequests: false,
        error: _cleanError(e),
      );
    }
  }

  // ============================================================
  // CLEAN ERROR
  // ============================================================

  String _cleanError(Object error) {
    final message = error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        )
        .trim();

    if (message.isEmpty) {
      return 'Something went wrong.';
    }

    return message;
  }
}