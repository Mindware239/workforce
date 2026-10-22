import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/network/network_providers.dart';

import '../data/account_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(apiClient: ref.read(apiClientProvider));
});

/// The organization's terms and conditions, read fresh each time.
final organizationTermsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.read(accountRepositoryProvider).getTerms();
});

// ============================================================================
// ACCOUNT DELETION
// ============================================================================

class AccountDeletionState {
  final bool isLoading;
  final bool isSubmitting;
  final String? error;

  /// The latest request (pending, approved, rejected or cancelled), or null.
  final Map<String, dynamic>? request;

  const AccountDeletionState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.request,
  });

  bool get isPending => request?['status'] == 'pending';

  AccountDeletionState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    Map<String, dynamic>? request,
    bool clearRequest = false,
  }) {
    return AccountDeletionState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : error ?? this.error,
      request: clearRequest ? null : request ?? this.request,
    );
  }
}

final accountDeletionProvider = StateNotifierProvider.autoDispose<
    AccountDeletionNotifier, AccountDeletionState>((ref) {
  return AccountDeletionNotifier(ref.read(accountRepositoryProvider));
});

class AccountDeletionNotifier extends StateNotifier<AccountDeletionState> {
  final AccountRepository repository;

  AccountDeletionNotifier(this.repository)
      : super(const AccountDeletionState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final request = await repository.getMyDeletionRequest();

      state = state.copyWith(
        isLoading: false,
        request: request,
        clearRequest: request == null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanErrorMessage(e));
    }
  }

  /// Returns null on success, otherwise the error message.
  Future<String?> request(String? reason) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final request = await repository.requestDeletion(reason: reason);

      state = state.copyWith(isSubmitting: false, request: request);

      return null;
    } catch (e) {
      final message = cleanErrorMessage(e);

      state = state.copyWith(isSubmitting: false);

      return message;
    }
  }

  Future<String?> cancel() async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final request = await repository.cancelDeletion();

      state = state.copyWith(isSubmitting: false, request: request);

      return null;
    } catch (e) {
      final message = cleanErrorMessage(e);

      state = state.copyWith(isSubmitting: false);

      return message;
    }
  }
}
