import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/network/network_providers.dart';

import '../data/announcement_repository.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository(apiClient: ref.read(apiClientProvider));
});

final announcementProvider =
    StateNotifierProvider<AnnouncementNotifier, AnnouncementState>((ref) {
  return AnnouncementNotifier(ref.read(announcementRepositoryProvider));
});

// ============================================================================
// STATE
// ============================================================================

class AnnouncementState {
  static const int pageSize = 20;

  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final List<Map<String, dynamic>> pinned;
  final List<Map<String, dynamic>> recent;

  /// How many announcements (pinned + recent) were asked for.
  final int limit;

  const AnnouncementState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.pinned = const [],
    this.recent = const [],
    this.limit = pageSize,
  });

  AnnouncementState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    List<Map<String, dynamic>>? pinned,
    List<Map<String, dynamic>>? recent,
    int? limit,
    bool clearError = false,
  }) {
    return AnnouncementState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : error ?? this.error,
      pinned: pinned ?? this.pinned,
      recent: recent ?? this.recent,
      limit: limit ?? this.limit,
    );
  }

  bool get isEmpty => pinned.isEmpty && recent.isEmpty;

  /// The server filled the whole page, so there may be more behind it.
  bool get canLoadMore =>
      recent.isNotEmpty && pinned.length + recent.length >= limit;
}

// ============================================================================
// NOTIFIER
// ============================================================================

class AnnouncementNotifier extends StateNotifier<AnnouncementState> {
  final AnnouncementRepository repository;

  AnnouncementNotifier(this.repository) : super(const AnnouncementState());

  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      limit: AnnouncementState.pageSize,
    );

    try {
      final feed = await repository.getMine(limit: AnnouncementState.pageSize);

      state = state.copyWith(
        isLoading: false,
        pinned: feed.pinned,
        recent: feed.recent,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanErrorMessage(e));
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore) return;

    final limit = state.limit + AnnouncementState.pageSize;

    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final feed = await repository.getMine(limit: limit);

      state = state.copyWith(
        isLoadingMore: false,
        pinned: feed.pinned,
        recent: feed.recent,
        limit: limit,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: cleanErrorMessage(e));
    }
  }
}
