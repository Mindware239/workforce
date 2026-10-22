import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/network/network_providers.dart';

import '../data/asset_repository.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return AssetRepository(apiClient: ref.read(apiClientProvider));
});

final assetProvider = StateNotifierProvider<AssetNotifier, AssetState>((ref) {
  return AssetNotifier(ref.read(assetRepositoryProvider));
});

// ============================================================================
// STATE
// ============================================================================

class AssetState {
  final bool isLoading;
  final bool loaded;
  final String? error;
  final AssetHoldings holdings;

  /// The assignment an acknowledge / report call is running for.
  final int? busyAssignmentId;

  const AssetState({
    this.isLoading = false,
    this.loaded = false,
    this.error,
    this.holdings = const AssetHoldings(),
    this.busyAssignmentId,
  });

  AssetState copyWith({
    bool? isLoading,
    bool? loaded,
    String? error,
    AssetHoldings? holdings,
    int? busyAssignmentId,
    bool clearBusy = false,
    bool clearError = false,
  }) {
    return AssetState(
      isLoading: isLoading ?? this.isLoading,
      loaded: loaded ?? this.loaded,
      error: clearError ? null : error ?? this.error,
      holdings: holdings ?? this.holdings,
      busyAssignmentId:
          clearBusy ? null : busyAssignmentId ?? this.busyAssignmentId,
    );
  }

  int get pendingAcknowledgements => holdings.current
      .where((a) => a['acknowledgedAt'] == null)
      .length;
}

// ============================================================================
// NOTIFIER
// ============================================================================

class AssetNotifier extends StateNotifier<AssetState> {
  final AssetRepository repository;

  AssetNotifier(this.repository) : super(const AssetState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final holdings = await repository.getMine();

      state = state.copyWith(
        isLoading: false,
        loaded: true,
        holdings: holdings,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanErrorMessage(e));
    }
  }

  /// Returns null on success, or the error message.
  Future<String?> acknowledge(int assignmentId) async {
    state = state.copyWith(busyAssignmentId: assignmentId);

    try {
      final holdings = await repository.acknowledge(assignmentId);

      state = state.copyWith(holdings: holdings, clearBusy: true);

      return null;
    } catch (e) {
      state = state.copyWith(clearBusy: true);

      return cleanErrorMessage(e);
    }
  }

  /// Returns null on success, or the error message.
  Future<String?> reportIssue({
    required int assignmentId,
    required String kind,
    required String description,
  }) async {
    state = state.copyWith(busyAssignmentId: assignmentId);

    try {
      final holdings = await repository.reportIssue(
        assignmentId: assignmentId,
        kind: kind,
        description: description,
      );

      state = state.copyWith(holdings: holdings, clearBusy: true);

      return null;
    } catch (e) {
      state = state.copyWith(clearBusy: true);

      return cleanErrorMessage(e);
    }
  }
}
