import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/network/network_providers.dart';

import '../data/review_repository.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(apiClient: ref.read(apiClientProvider));
});

final reviewListProvider =
    StateNotifierProvider<ReviewListNotifier, ReviewListState>((ref) {
  return ReviewListNotifier(ref.read(reviewRepositoryProvider));
});

final reviewDetailProvider = StateNotifierProvider.autoDispose
    .family<ReviewDetailNotifier, ReviewDetailState, int>((ref, id) {
  return ReviewDetailNotifier(
    id: id,
    repository: ref.read(reviewRepositoryProvider),
    onChanged: () => ref.read(reviewListProvider.notifier).load(),
  );
});

// ============================================================================
// LIST
// ============================================================================

class ReviewListState {
  final bool isLoading;
  final bool loaded;
  final String? error;
  final List<Map<String, dynamic>> mine;
  final List<Map<String, dynamic>> team;

  const ReviewListState({
    this.isLoading = false,
    this.loaded = false,
    this.error,
    this.mine = const [],
    this.team = const [],
  });

  ReviewListState copyWith({
    bool? isLoading,
    bool? loaded,
    String? error,
    List<Map<String, dynamic>>? mine,
    List<Map<String, dynamic>>? team,
    bool clearError = false,
  }) {
    return ReviewListState(
      isLoading: isLoading ?? this.isLoading,
      loaded: loaded ?? this.loaded,
      error: clearError ? null : error ?? this.error,
      mine: mine ?? this.mine,
      team: team ?? this.team,
    );
  }

  /// Team reviews waiting on the manager: goals to approve or a review to write.
  int get teamWaiting => team.where(needsManager).length;

  static bool needsManager(Map<String, dynamic> r) {
    if (r['cycleStatus'] != 'active') return false;

    return r['goalsStatus'] == 'submitted' ||
        (r['goalsStatus'] == 'approved' && r['managerSubmittedAt'] == null);
  }
}

class ReviewListNotifier extends StateNotifier<ReviewListState> {
  final ReviewRepository repository;

  ReviewListNotifier(this.repository) : super(const ReviewListState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final results = await Future.wait([
        repository.getMine(),
        // The team list is best-effort: most people manage nobody.
        repository.getTeam().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      state = state.copyWith(
        isLoading: false,
        loaded: true,
        mine: results[0],
        team: results[1],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanErrorMessage(e));
    }
  }
}

// ============================================================================
// DETAIL
// ============================================================================

class ReviewDetailState {
  final bool isLoading;
  final String? loadError;

  /// The action running now (e.g. 'submitGoals', 'saveSelf'), for spinners.
  final String? busy;
  final ReviewView? view;

  const ReviewDetailState({
    this.isLoading = false,
    this.loadError,
    this.busy,
    this.view,
  });

  ReviewDetailState copyWith({
    bool? isLoading,
    String? loadError,
    String? busy,
    ReviewView? view,
    bool clearLoadError = false,
    bool clearBusy = false,
  }) {
    return ReviewDetailState(
      isLoading: isLoading ?? this.isLoading,
      loadError: clearLoadError ? null : loadError ?? this.loadError,
      busy: clearBusy ? null : busy ?? this.busy,
      view: view ?? this.view,
    );
  }
}

class ReviewDetailNotifier extends StateNotifier<ReviewDetailState> {
  final int id;
  final ReviewRepository repository;
  final void Function() onChanged;

  ReviewDetailNotifier({
    required this.id,
    required this.repository,
    required this.onChanged,
  }) : super(const ReviewDetailState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearLoadError: true);

    try {
      final view = await repository.getReview(id);

      if (!mounted) return;

      state = state.copyWith(isLoading: false, view: view);
    } catch (e) {
      if (!mounted) return;

      state = state.copyWith(
        isLoading: false,
        loadError: cleanErrorMessage(e),
      );
    }
  }

  /// Runs one write; returns null on success or the error message.
  Future<String?> _run(
    String action,
    Future<ReviewView> Function() call, {
    bool refreshList = false,
  }) async {
    if (state.busy != null) return null;

    state = state.copyWith(busy: action);

    try {
      final view = await call();

      if (!mounted) return null;

      state = state.copyWith(view: view, clearBusy: true);

      if (refreshList) onChanged();

      return null;
    } catch (e) {
      if (mounted) state = state.copyWith(clearBusy: true);

      return cleanErrorMessage(e);
    }
  }

  Future<String?> addGoal(Map<String, dynamic> goal) =>
      _run('goal', () => repository.addGoal(id, goal));

  Future<String?> updateGoal(int goalId, Map<String, dynamic> goal) =>
      _run('goal', () => repository.updateGoal(id, goalId, goal));

  Future<String?> removeGoal(int goalId) =>
      _run('goal', () => repository.removeGoal(id, goalId));

  Future<String?> submitGoals() => _run(
        'submitGoals',
        () => repository.submitGoals(id),
        refreshList: true,
      );

  Future<String?> approveGoals() => _run(
        'approveGoals',
        () => repository.approveGoals(id),
        refreshList: true,
      );

  Future<String?> reopenGoals() => _run(
        'reopenGoals',
        () => repository.reopenGoals(id),
        refreshList: true,
      );

  Future<String?> saveSelf({
    required bool submit,
    required List<Map<String, dynamic>> goals,
    required String overallComments,
  }) =>
      _run(
        submit ? 'submitSelf' : 'saveSelf',
        () => repository.saveSelf(
          id,
          submit: submit,
          goals: goals,
          overallComments: overallComments,
        ),
        refreshList: submit,
      );

  Future<String?> saveManager({
    required bool submit,
    required List<Map<String, dynamic>> goals,
    int? overallRating,
    required String strengths,
    required String improvements,
    required String recommendation,
    num? incrementPercent,
  }) =>
      _run(
        submit ? 'submitManager' : 'saveManager',
        () => repository.saveManager(
          id,
          submit: submit,
          goals: goals,
          overallRating: overallRating,
          strengths: strengths,
          improvements: improvements,
          recommendation: recommendation,
          incrementPercent: incrementPercent,
        ),
        refreshList: submit,
      );

  Future<String?> acknowledge(String? comment) => _run(
        'acknowledge',
        () => repository.acknowledge(id, comment),
        refreshList: true,
      );
}
