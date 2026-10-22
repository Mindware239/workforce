import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/network/network_providers.dart';

import '../data/leave_repository.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

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

/// One request with its approval ladder, comments and permissions, read
/// fresh each time it is opened.
final leaveDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, id) {
  return ref.read(leaveRepositoryProvider).getLeave(id);
});

// ============================================================================
// LEAVE STATE
// ============================================================================

class LeaveState {
  final bool isLoading;
  final bool isLoadingRequests;
  final bool isLoadingBalances;

  final String? error;

  final Map<String, dynamic>? data;

  final List<Map<String, dynamic>> requests;

  /// `[{category, total, used, pending, remaining}]`; a null total/remaining
  /// means the entitlement is not tracked (unlimited).
  final List<Map<String, dynamic>> balances;

  /// Permission (short leave in hours) usage this month, or null.
  final Map<String, dynamic>? permission;

  const LeaveState({
    this.isLoading = false,
    this.isLoadingRequests = false,
    this.isLoadingBalances = false,
    this.error,
    this.data,
    this.requests = const [],
    this.balances = const [],
    this.permission,
  });

  LeaveState copyWith({
    bool? isLoading,
    bool? isLoadingRequests,
    bool? isLoadingBalances,
    String? error,
    Map<String, dynamic>? data,
    List<Map<String, dynamic>>? requests,
    List<Map<String, dynamic>>? balances,
    Map<String, dynamic>? permission,
    bool clearPermission = false,
    bool clearError = false,
  }) {
    return LeaveState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingRequests: isLoadingRequests ?? this.isLoadingRequests,
      isLoadingBalances: isLoadingBalances ?? this.isLoadingBalances,
      error: clearError ? null : error ?? this.error,
      data: data ?? this.data,
      requests: requests ?? this.requests,
      balances: balances ?? this.balances,
      permission: clearPermission ? null : permission ?? this.permission,
    );
  }
}

// ============================================================================
// LEAVE NOTIFIER
// ============================================================================

class LeaveNotifier extends StateNotifier<LeaveState> {
  final LeaveRepository repository;

  LeaveNotifier(this.repository) : super(const LeaveState());

  /// Submits a new request, or answers one sent back when [resubmitId] is set.
  Future<bool> applyLeave({
    required String leaveType,
    required String leaveCategory,
    required String startDate,
    String? endDate,
    String? halfDaySession,
    String? startTime,
    String? endTime,
    required String reason,
    String? voiceNotePath,
    int? resubmitId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = resubmitId != null
          ? await repository.resubmitLeave(
              resubmitId,
              leaveType: leaveType,
              leaveCategory: leaveCategory,
              startDate: startDate,
              endDate: endDate,
              halfDaySession: halfDaySession,
              startTime: startTime,
              endTime: endTime,
              reason: reason,
              voiceNotePath: voiceNotePath,
            )
          : await repository.applyLeave(
              leaveType: leaveType,
              leaveCategory: leaveCategory,
              startDate: startDate,
              endDate: endDate,
              halfDaySession: halfDaySession,
              startTime: startTime,
              endTime: endTime,
              reason: reason,
              voiceNotePath: voiceNotePath,
            );

      if (response['success'] == false) {
        state = state.copyWith(
          isLoading: false,
          error: response['message']?.toString() ??
              'Unable to submit leave request.',
        );

        return false;
      }

      final responseData = response['data'];

      state = state.copyWith(
        isLoading: false,
        data: responseData is Map
            ? Map<String, dynamic>.from(responseData)
            : null,
        clearError: true,
      );

      await loadLeaveData();

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanErrorMessage(e));

      return false;
    }
  }

  /// Withdraws a request. Null on success, otherwise the reason.
  Future<String?> cancelLeave(int id) async {
    try {
      await repository.cancelLeave(id);
      await loadLeaveData();

      return null;
    } catch (e) {
      return cleanErrorMessage(e);
    }
  }

  /// Null on success, otherwise the reason.
  Future<String?> addComment(int id, String note) async {
    try {
      await repository.addComment(id, note);

      return null;
    } catch (e) {
      return cleanErrorMessage(e);
    }
  }

  Future<void> getMyLeaveRequests() async {
    state = state.copyWith(isLoadingRequests: true, clearError: true);

    try {
      final requests = await repository.getMyLeaveRequests();

      state = state.copyWith(
        isLoadingRequests: false,
        requests: requests,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingRequests: false,
        error: cleanErrorMessage(e),
      );
    }
  }

  Future<void> getLeaveBalances({int? year}) async {
    state = state.copyWith(isLoadingBalances: true);

    try {
      final sheet = await repository.getBalanceSheet(
        year: year ?? DateTime.now().year,
      );

      final permission = sheet['permission'];

      state = state.copyWith(
        isLoadingBalances: false,
        balances: asMapList(sheet['balances']),
        permission: permission is Map
            ? Map<String, dynamic>.from(permission)
            : null,
        clearPermission: permission is! Map,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingBalances: false,
        error: cleanErrorMessage(e),
      );
    }
  }

  Future<void> loadLeaveData() async {
    await Future.wait([
      getMyLeaveRequests(),
      getLeaveBalances(),
    ]);
  }
}
