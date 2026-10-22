import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/network/network_providers.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';

import '../data/field_work_repository.dart';
import '../services/field_work_tracker.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

final fieldWorkRepositoryProvider = Provider<FieldWorkRepository>((ref) {
  return FieldWorkRepository(apiClient: ref.read(apiClientProvider));
});

final fieldWorkProvider =
    StateNotifierProvider<FieldWorkNotifier, FieldWorkState>((ref) {
  return FieldWorkNotifier(ref.read(fieldWorkRepositoryProvider));
});

/// The points recorded for one session, for the "N updates sent" line.
final fieldSessionHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, id) {
  return ref.read(fieldWorkRepositoryProvider).sessionHistory(id);
});

// ============================================================================
// STATE
// ============================================================================

class FieldWorkState {
  final bool isLoading;
  final bool isSubmitting;
  final bool isBusy;
  final String? error;
  final List<Map<String, dynamic>> sessions;

  /// GET /location/office: main fence plus `places` (every fence).
  final Map<String, dynamic>? office;

  const FieldWorkState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.isBusy = false,
    this.error,
    this.sessions = const [],
    this.office,
  });

  FieldWorkState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    bool? isBusy,
    String? error,
    bool clearError = false,
    List<Map<String, dynamic>>? sessions,
    Map<String, dynamic>? office,
  }) {
    return FieldWorkState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : error ?? this.error,
      sessions: sessions ?? this.sessions,
      office: office ?? this.office,
    );
  }

  /// A running session, else one approved for today — the web's `current`.
  Map<String, dynamic>? get current {
    final today = apiDateKey(DateTime.now());

    for (final s in sessions) {
      if (s['status'] == 'active') return s;
    }

    for (final s in sessions) {
      if (s['status'] == 'approved' && sessionDateKey(s) == today) return s;
    }

    return null;
  }

  static String sessionDateKey(Map<String, dynamic> session) {
    final raw = session['requested_date']?.toString() ?? '';

    // A DATE column may arrive as `YYYY-MM-DD` or as a timestamp.
    if (raw.length == 10) return raw;

    final parsed = parseApiDate(raw);

    return parsed == null ? raw : apiDateKey(parsed);
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================

class FieldWorkNotifier extends StateNotifier<FieldWorkState> {
  final FieldWorkRepository repository;

  FieldWorkNotifier(this.repository) : super(const FieldWorkState());

  Future<void> load() async {
    await Future.wait([loadSessions(), loadOffice()]);
  }

  Future<void> loadSessions() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final sessions = await repository.mySessions();

      state = state.copyWith(isLoading: false, sessions: sessions);

      await _syncTracker(sessions);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanErrorMessage(e));
    }
  }

  Future<void> loadOffice() async {
    try {
      final office = await repository.office();

      state = state.copyWith(office: office);
    } catch (_) {
      // The distance line is a nicety; the page works without it.
    }
  }

  /// Keeps the stored session id in step with the server: a session running
  /// when the screen opens resumes its pings (as the web does), and one that
  /// has ended elsewhere stops them.
  Future<void> _syncTracker(List<Map<String, dynamic>> sessions) async {
    final stored = await FieldWorkTracker.activeSessionId();

    Map<String, dynamic>? active;

    for (final s in sessions) {
      if (s['status'] == 'active') active = s;
    }

    final activeId = active == null ? null : toInt(active['id']);

    if (activeId == null) {
      if (stored != null) await FieldWorkTracker.clear();
    } else if (stored != activeId) {
      await FieldWorkTracker.setActiveSession(activeId);
    }
  }

  /// Returns null on success, or the error message.
  Future<String?> submitRequest({
    required String requestedDate,
    required String purpose,
  }) async {
    state = state.copyWith(isSubmitting: true);

    try {
      await repository.createSession(
        purpose: purpose,
        requestedDate: requestedDate,
      );

      state = state.copyWith(isSubmitting: false);

      await loadSessions();

      return null;
    } catch (e) {
      state = state.copyWith(isSubmitting: false);

      return cleanErrorMessage(e);
    }
  }

  /// Returns null on success, or the error message.
  Future<String?> start(int id) async {
    state = state.copyWith(isBusy: true);

    try {
      await repository.startSession(id);
      await FieldWorkTracker.setActiveSession(id);

      state = state.copyWith(isBusy: false);

      await loadSessions();

      return null;
    } catch (e) {
      state = state.copyWith(isBusy: false);

      return cleanErrorMessage(e);
    }
  }

  /// Returns null on success, or the error message.
  Future<String?> end(int id) async {
    state = state.copyWith(isBusy: true);

    // Stop pinging first, as the web stops its watch before the call.
    await FieldWorkTracker.clear();

    try {
      await repository.endSession(id);

      state = state.copyWith(isBusy: false);

      await loadSessions();

      return null;
    } catch (e) {
      state = state.copyWith(isBusy: false);

      await loadSessions();

      return cleanErrorMessage(e);
    }
  }
}
