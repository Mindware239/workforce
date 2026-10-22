import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/network/network_providers.dart';

import '../data/warehouse_repository.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

final warehouseRepositoryProvider = Provider<WarehouseRepository>((ref) {
  return WarehouseRepository(apiClient: ref.read(apiClientProvider));
});

final warehouseProvider =
    StateNotifierProvider<WarehouseNotifier, WarehouseState>((ref) {
  return WarehouseNotifier(ref.read(warehouseRepositoryProvider));
});

final pickListProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, id) {
  return ref.read(warehouseRepositoryProvider).getPickList(id);
});

final transferDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, id) {
  return ref.read(warehouseRepositoryProvider).getTransfer(id);
});

final countDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, id) {
  return ref.read(warehouseRepositoryProvider).getCount(id);
});

/// Bins of one warehouse (without stock), for "move to" and "put away to".
final warehouseLocationsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, warehouseId) {
  return ref.read(warehouseRepositoryProvider).getLocations(warehouseId);
});

/// Where the put-away rules would put a line.
class PutawayQuery {
  final int warehouseId;
  final int variantId;
  final int? batchId;
  final num? quantity;

  const PutawayQuery({
    required this.warehouseId,
    required this.variantId,
    this.batchId,
    this.quantity,
  });

  @override
  bool operator ==(Object other) =>
      other is PutawayQuery &&
      other.warehouseId == warehouseId &&
      other.variantId == variantId &&
      other.batchId == batchId &&
      other.quantity == quantity;

  @override
  int get hashCode => Object.hash(warehouseId, variantId, batchId, quantity);
}

final putawaySuggestionProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, PutawayQuery>((ref, q) {
  return ref.read(warehouseRepositoryProvider).suggestPutaway(
        warehouseId: q.warehouseId,
        variantId: q.variantId,
        batchId: q.batchId,
        quantity: q.quantity,
      );
});

// ============================================================================
// STATE
// ============================================================================

class WarehouseState {
  final bool loadingWork;
  final List<Map<String, dynamic>> pickLists;
  final List<Map<String, dynamic>> transfers;
  final List<Map<String, dynamic>> counts;

  final bool resolving;
  final String? resolveError;

  /// What the last scan (or a tap on open work) turned out to be.
  final Map<String, dynamic>? hit;

  const WarehouseState({
    this.loadingWork = false,
    this.pickLists = const [],
    this.transfers = const [],
    this.counts = const [],
    this.resolving = false,
    this.resolveError,
    this.hit,
  });

  WarehouseState copyWith({
    bool? loadingWork,
    List<Map<String, dynamic>>? pickLists,
    List<Map<String, dynamic>>? transfers,
    List<Map<String, dynamic>>? counts,
    bool? resolving,
    String? resolveError,
    bool clearResolveError = false,
    Map<String, dynamic>? hit,
    bool clearHit = false,
  }) {
    return WarehouseState(
      loadingWork: loadingWork ?? this.loadingWork,
      pickLists: pickLists ?? this.pickLists,
      transfers: transfers ?? this.transfers,
      counts: counts ?? this.counts,
      resolving: resolving ?? this.resolving,
      resolveError:
          clearResolveError ? null : resolveError ?? this.resolveError,
      hit: clearHit ? null : hit ?? this.hit,
    );
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================

class WarehouseNotifier extends StateNotifier<WarehouseState> {
  final WarehouseRepository repository;

  WarehouseNotifier(this.repository) : super(const WarehouseState());

  /// My pick sheets, transfers on their way and open counts. Each list is
  /// optional: one the user may not see (permission) is simply empty, as
  /// on the web.
  Future<void> loadOpenWork() async {
    state = state.copyWith(loadingWork: true);

    Future<List<Map<String, dynamic>>> safe(
      Future<List<Map<String, dynamic>>> Function() call,
    ) async {
      try {
        return await call();
      } catch (_) {
        return const [];
      }
    }

    final results = await Future.wait([
      safe(repository.getMyPickLists),
      safe(repository.getInTransitTransfers),
      safe(repository.getOpenCounts),
    ]);

    if (!mounted) return;

    state = state.copyWith(
      loadingWork: false,
      pickLists: results[0],
      transfers: results[1],
      counts: results[2],
    );
  }

  /// Resolve a scanned or typed code. Returns true when it named something.
  Future<bool> resolve(String code) async {
    final value = code.trim();

    if (value.isEmpty) return false;

    state = state.copyWith(resolving: true, clearResolveError: true);

    try {
      final hit = await repository.resolve(value);

      state = state.copyWith(resolving: false, hit: hit);

      return true;
    } catch (e) {
      state = state.copyWith(
        resolving: false,
        resolveError: cleanErrorMessage(e),
      );

      return false;
    }
  }

  /// Open a piece of open work as if it had been scanned.
  void open({
    required String type,
    required int id,
    required String label,
    String? sub,
    String? status,
  }) {
    state = state.copyWith(
      clearResolveError: true,
      hit: {
        'type': type,
        'id': id,
        'label': label,
        'sub': sub,
        'status': status,
        'code': label,
      },
    );
  }

  void clearResolveError() {
    if (state.resolveError != null) {
      state = state.copyWith(clearResolveError: true);
    }
  }

  /// "Scan another": close the result and refresh the open work.
  void closeHit() {
    state = state.copyWith(clearHit: true);

    loadOpenWork();
  }
}
