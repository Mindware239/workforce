import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/network_providers.dart';
import 'package:workforce/features/call/data/call_models.dart';

/// REST half of calls: the ICE configuration and a conversation's call ledger.
class CallRepository {
  CallRepository(this.apiClient);

  final ApiClient apiClient;

  /// GET /api/chat/rtc-config → { iceServers, iceTransportPolicy, ttlSeconds }
  Future<RtcConfig?> rtcConfig() async {
    final response = await apiClient.get('/chat/rtc-config');
    final body = response.data;
    return RtcConfig.fromJson(body is Map && body['data'] is Map ? body['data'] : body);
  }

  /// GET /api/chat/conversations/:id/calls → newest first.
  Future<List<CallRecord>> calls(int conversationId, {int limit = 50}) async {
    final response = await apiClient.get(
      '/chat/conversations/$conversationId/calls',
      queryParameters: {'limit': limit},
    );
    final body = response.data;
    final list = body is Map ? body['data'] : body;
    if (list is! List) return const [];
    return list.map(CallRecord.fromJson).whereType<CallRecord>().toList();
  }
}

final callRepositoryProvider = Provider<CallRepository>(
  (ref) => CallRepository(ref.read(apiClientProvider)),
);

/// conversationId → its calls, oldest first (for merging into the thread).
class CallHistoryNotifier extends StateNotifier<Map<int, List<CallRecord>>> {
  CallHistoryNotifier(this._repo) : super(const {});

  final CallRepository _repo;
  final Map<int, Future<void>> _loading = {};

  Future<void> load(int conversationId) {
    // The block body matters: a callback returning the removed future would
    // make whenComplete wait for itself.
    return _loading[conversationId] ??= _fetch(conversationId).whenComplete(() {
      _loading.remove(conversationId);
    });
  }

  Future<void> _fetch(int conversationId) async {
    try {
      final rows = await _repo.calls(conversationId);
      if (!mounted) return;
      rows.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = {...state, conversationId: rows};
    } catch (err) {
      debugPrint('[call] history for $conversationId not loaded: $err');
    }
  }

  /// Everything already loaded, again (after a reconnect).
  void refreshLoaded() {
    for (final id in state.keys.toList()) {
      load(id);
    }
  }

  void reset() {
    if (state.isNotEmpty) state = const {};
  }
}

final callHistoryProvider =
    StateNotifierProvider<CallHistoryNotifier, Map<int, List<CallRecord>>>(
  (ref) => CallHistoryNotifier(ref.read(callRepositoryProvider)),
);
