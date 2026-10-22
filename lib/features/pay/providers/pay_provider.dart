import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/network/network_providers.dart';

import '../data/pay_repository.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

final payRepositoryProvider = Provider<PayRepository>((ref) {
  return PayRepository(apiClient: ref.read(apiClientProvider));
});

final payProvider = StateNotifierProvider<PayNotifier, PayState>((ref) {
  return PayNotifier(ref.read(payRepositoryProvider));
});

// ============================================================================
// STATE
// ============================================================================

class PayState {
  final int year;
  final int month;
  final bool isLoading;
  final bool isDownloading;
  final String? error;

  /// The `/payroll/me` answer for [year]/[month]; null until loaded.
  final Map<String, dynamic>? data;

  final List<Map<String, dynamic>> history;

  const PayState({
    required this.year,
    required this.month,
    this.isLoading = false,
    this.isDownloading = false,
    this.error,
    this.data,
    this.history = const [],
  });

  factory PayState.initial() {
    final now = DateTime.now();

    return PayState(year: now.year, month: now.month);
  }

  PayState copyWith({
    int? year,
    int? month,
    bool? isLoading,
    bool? isDownloading,
    String? error,
    Map<String, dynamic>? data,
    bool clearData = false,
    List<Map<String, dynamic>>? history,
    bool clearError = false,
  }) {
    return PayState(
      year: year ?? this.year,
      month: month ?? this.month,
      isLoading: isLoading ?? this.isLoading,
      isDownloading: isDownloading ?? this.isDownloading,
      error: clearError ? null : error ?? this.error,
      data: clearData ? null : data ?? this.data,
      history: history ?? this.history,
    );
  }

  /// The finalized record, or null when the month is not available.
  Map<String, dynamic>? get record =>
      data != null && data!['available'] == true ? data : null;

  bool get isCurrentMonth {
    final now = DateTime.now();

    return year == now.year && month == now.month;
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================

class PayNotifier extends StateNotifier<PayState> {
  final PayRepository repository;

  PayNotifier(this.repository) : super(PayState.initial());

  Future<void> load() async {
    await Future.wait([loadMonth(), loadHistory()]);
  }

  Future<void> loadMonth() async {
    final year = state.year;
    final month = state.month;

    state = state.copyWith(isLoading: true, clearError: true, clearData: true);

    try {
      final data = await repository.getMyPayroll(year, month);

      // A newer selection may have been made while this one was loading.
      if (state.year != year || state.month != month) return;

      state = state.copyWith(isLoading: false, data: data);
    } catch (e) {
      if (state.year != year || state.month != month) return;

      state = state.copyWith(isLoading: false, error: cleanErrorMessage(e));
    }
  }

  Future<void> loadHistory() async {
    try {
      final history = await repository.getHistory();

      state = state.copyWith(history: history);
    } catch (_) {
      // The month view still works without the list of previous months.
    }
  }

  Future<void> selectPeriod(int year, int month) async {
    final now = DateTime.now();

    // No future months: there is nothing to show yet.
    if (year > now.year || (year == now.year && month > now.month)) return;

    state = state.copyWith(year: year, month: month);

    await loadMonth();
  }

  Future<void> shift(int delta) {
    final next = DateTime(state.year, state.month + delta, 1);

    return selectPeriod(next.year, next.month);
  }

  /// Returns the saved path, or throws with the message to show.
  Future<String> downloadPayslip({
    required int payslipId,
    required String fileName,
  }) async {
    state = state.copyWith(isDownloading: true);

    try {
      final path = await repository.downloadPayslip(
        payslipId: payslipId,
        fileName: fileName,
      );

      state = state.copyWith(isDownloading: false);

      return path;
    } catch (e) {
      state = state.copyWith(isDownloading: false);

      throw Exception(cleanErrorMessage(e));
    }
  }
}
