import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/network/network_providers.dart';

import '../data/expense_repository.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(apiClient: ref.read(apiClientProvider));
});

final expenseProvider =
    StateNotifierProvider<ExpenseNotifier, ExpenseState>((ref) {
  return ExpenseNotifier(ref.read(expenseRepositoryProvider));
});

/// One claim with its approval history, read fresh each time it is opened.
final expenseDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, id) {
  return ref.read(expenseRepositoryProvider).getClaim(id);
});

// ============================================================================
// STATE
// ============================================================================

class ExpenseState {
  final bool isLoading;
  final bool isSubmitting;
  final bool isCancelling;
  final String? error;
  final List<Map<String, dynamic>> claims;

  /// Above this amount a receipt is required; null = always optional.
  final num? receiptRequiredAbove;
  final bool settingsLoaded;

  const ExpenseState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.isCancelling = false,
    this.error,
    this.claims = const [],
    this.receiptRequiredAbove,
    this.settingsLoaded = false,
  });

  ExpenseState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    bool? isCancelling,
    String? error,
    List<Map<String, dynamic>>? claims,
    num? receiptRequiredAbove,
    bool clearThreshold = false,
    bool? settingsLoaded,
    bool clearError = false,
  }) {
    return ExpenseState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isCancelling: isCancelling ?? this.isCancelling,
      error: clearError ? null : error ?? this.error,
      claims: claims ?? this.claims,
      receiptRequiredAbove: clearThreshold
          ? null
          : receiptRequiredAbove ?? this.receiptRequiredAbove,
      settingsLoaded: settingsLoaded ?? this.settingsLoaded,
    );
  }

  num _sum(String status) => claims
      .where((c) => c['status'] == status)
      .fold<num>(0, (sum, c) => sum + _amount(c));

  num get pendingTotal => _sum('pending');
  num get approvedUnpaidTotal => _sum('approved');
  num get paidTotal => _sum('paid');

  int countOf(String status) =>
      claims.where((c) => c['status'] == status).length;

  static num _amount(Map<String, dynamic> claim) {
    final value = claim['amount'];

    if (value is num) return value;

    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================

class ExpenseNotifier extends StateNotifier<ExpenseState> {
  final ExpenseRepository repository;

  ExpenseNotifier(this.repository) : super(const ExpenseState());

  Future<void> load() async {
    await Future.wait([loadClaims(), loadSettings()]);
  }

  Future<void> loadClaims() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final claims = await repository.getMyClaims();

      state = state.copyWith(isLoading: false, claims: claims);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanErrorMessage(e));
    }
  }

  Future<void> loadSettings() async {
    try {
      final threshold = await repository.getReceiptThreshold();

      state = threshold == null
          ? state.copyWith(clearThreshold: true, settingsLoaded: true)
          : state.copyWith(
              receiptRequiredAbove: threshold,
              settingsLoaded: true,
            );
    } catch (_) {
      // The server still enforces the rule; the form just cannot pre-warn.
      state = state.copyWith(settingsLoaded: true);
    }
  }

  /// Returns null on success, or the error message.
  Future<String?> submitClaim({
    required String expenseDate,
    required String category,
    required num amount,
    required String description,
    String? receiptPath,
    String? receiptName,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      await repository.createClaim(
        expenseDate: expenseDate,
        category: category,
        amount: amount,
        description: description,
        receiptPath: receiptPath,
        receiptName: receiptName,
      );

      state = state.copyWith(isSubmitting: false);

      await loadClaims();

      return null;
    } catch (e) {
      state = state.copyWith(isSubmitting: false);

      return cleanErrorMessage(e);
    }
  }

  /// Returns null on success, or the error message.
  Future<String?> cancelClaim(int id) async {
    state = state.copyWith(isCancelling: true);

    try {
      await repository.cancelClaim(id);

      state = state.copyWith(isCancelling: false);

      await loadClaims();

      return null;
    } catch (e) {
      state = state.copyWith(isCancelling: false);

      return cleanErrorMessage(e);
    }
  }
}
