/// The live half of chat: folds every pushed chat event into [chatProvider]
/// (so the list, the open thread and the bottom-nav badge redraw without
/// refetching), keeps presence and typing, and catches up after a reconnect.
///
/// Parity target: frontend/src/components/realtime/realtime-provider.tsx and
/// frontend/src/lib/realtime/chat-store.ts.
///
///   server → client handled here
///     message:new           { conversationId, message }
///     message:deleted       { conversationId, messageId }
///     receipt:update        { conversationId, userId, lastReadAt, lastDeliveredAt }
///     typing                { conversationId, userId, fullName, typing }
///     presence:update       { userId, online, lastSeenAt }
///     conversation:updated  { conversationId, removedUserIds }
///
///   client → server sent from chat
///     message:send       { conversationId, body, clientId } → { message }
///     message:delivered  { conversationId, messageId }
///     message:read       { conversationId }
///     typing             { conversationId, typing }
///     presence:query     { userIds }                       → { presence: [...] }
///
/// [chatRealtimeProvider] is watched by the signed-in shell (DashboardPage),
/// which is what starts the socket and keeps this wiring alive.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/realtime/realtime_service.dart';
import 'package:workforce/core/services/secure_storage.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/chat/providers/chat_provider.dart';

// =============================================================================
// The open thread
// =============================================================================

class ChatLive {
  ChatLive._();

  /// Which conversation is on screen, if any. A message arriving there is
  /// read, not unread, and the list's badge for it must not count up.
  static int? activeConversationId;

  static bool get appVisible {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  static bool isOnScreen(int conversationId) =>
      activeConversationId == conversationId && appVisible;
}

int? _asInt(dynamic value) => int.tryParse(value?.toString() ?? '');

// =============================================================================
// Presence
// =============================================================================

class ChatPresence {
  final bool online;
  final String? lastSeenAt;

  const ChatPresence({required this.online, this.lastSeenAt});
}

class ChatPresenceNotifier extends StateNotifier<Map<int, ChatPresence>> {
  ChatPresenceNotifier(this._realtime) : super(const {});

  final RealtimeService _realtime;

  /// Asked since the last connect; not asked again until the next one.
  final Set<int> _asked = {};
  final Set<int> _queue = {};
  Timer? _flush;

  /// Asks for a person's presence. Many rows ask at once when the list
  /// renders, so ids are gathered for a moment and sent as one query.
  void want(int? userId) {
    if (userId == null || userId <= 0) return;
    if (_asked.contains(userId)) return;
    _queue.add(userId);
    _flush ??= Timer(const Duration(milliseconds: 50), _send);
  }

  void _send() {
    _flush = null;
    if (!_realtime.isConnected) return; // asked again on the next connect
    final ids = _queue.take(200).toList();
    _queue.removeAll(ids);
    if (ids.isEmpty) return;
    _asked.addAll(ids);

    _realtime
        .emitWithAck('presence:query', {'userIds': ids})
        .then((reply) {
          if (!mounted) return;
          final list = reply['presence'];
          if (list is! List) return;
          final next = Map<int, ChatPresence>.from(state);
          for (final item in list.whereType<Map>()) {
            final id = _asInt(item['userId']);
            if (id == null) continue;
            next[id] = ChatPresence(
              online: item['online'] == true,
              lastSeenAt: item['lastSeenAt']?.toString(),
            );
          }
          state = next;
        })
        .catchError((_) {
          _asked.removeAll(ids);
        });

    if (_queue.isNotEmpty) {
      _flush = Timer(const Duration(milliseconds: 50), _send);
    }
  }

  void set(int userId, ChatPresence presence) {
    state = {...state, userId: presence};
  }

  /// After a reconnect: everyone already known is asked again.
  void refreshKnown() {
    final known = {...state.keys, ..._asked, ..._queue};
    _asked.clear();
    for (final id in known) {
      want(id);
    }
  }

  /// Presence is unknown while the socket is down.
  void clear() {
    final known = {...state.keys, ..._asked};
    _asked.clear();
    _queue.addAll(known);
    state = const {};
  }

  void reset() {
    _flush?.cancel();
    _flush = null;
    _asked.clear();
    _queue.clear();
    state = const {};
  }

  @override
  void dispose() {
    _flush?.cancel();
    super.dispose();
  }
}

final chatPresenceProvider =
    StateNotifierProvider<ChatPresenceNotifier, Map<int, ChatPresence>>(
  (ref) => ChatPresenceNotifier(ref.read(realtimeServiceProvider)),
);

// =============================================================================
// Typing
// =============================================================================

class ChatTypist {
  final String name;
  final DateTime expires;

  const ChatTypist(this.name, this.expires);
}

/// conversationId → userId → who is typing there.
class ChatTypingNotifier
    extends StateNotifier<Map<int, Map<int, ChatTypist>>> {
  ChatTypingNotifier() : super(const {});

  /// A typing flag that is not refreshed within this long is dropped.
  static const ttl = Duration(seconds: 6);

  void set(int conversationId, int userId, String name, bool typing) {
    final next = Map<int, Map<int, ChatTypist>>.from(state);
    final entries = Map<int, ChatTypist>.from(next[conversationId] ?? {});
    if (typing) {
      entries[userId] = ChatTypist(name, DateTime.now().add(ttl));
      Timer(ttl + const Duration(milliseconds: 50), () => _prune(conversationId));
    } else {
      if (!entries.containsKey(userId)) return;
      entries.remove(userId);
    }
    next[conversationId] = entries;
    state = next;
  }

  void _prune(int conversationId) {
    if (!mounted) return;
    final entries = state[conversationId];
    if (entries == null) return;
    final now = DateTime.now();
    final kept = Map<int, ChatTypist>.from(entries)
      ..removeWhere((_, t) => !t.expires.isAfter(now));
    if (kept.length == entries.length) return;
    state = {...state, conversationId: kept};
  }

  void clear() {
    if (state.isNotEmpty) state = const {};
  }
}

final chatTypingProvider = StateNotifierProvider<ChatTypingNotifier,
    Map<int, Map<int, ChatTypist>>>((ref) => ChatTypingNotifier());

/// Names typing in one conversation right now.
List<String> typingNamesIn(
  Map<int, Map<int, ChatTypist>> typing,
  int conversationId,
) {
  final entries = typing[conversationId];
  if (entries == null || entries.isEmpty) return const [];
  final now = DateTime.now();
  return entries.values
      .where((t) => t.expires.isAfter(now))
      .map((t) => t.name)
      .toList();
}

/// "typing…", "Asha is typing…" or "3 people are typing…".
String? typingLine(WidgetRef ref, List<String> names, {required bool group}) {
  if (names.isEmpty) return null;
  if (!group) return ref.tr('chat.typing');
  if (names.length == 1) {
    final first = names.first.trim().split(' ').first;
    return ref.tr('chat.typingNamed').replaceAll('{name}', first);
  }
  return ref
      .tr('chat.typingMany')
      .replaceAll('{count}', names.length.toString());
}

/// Sends typing on/off for one conversation: at most every three seconds
/// while keys are pressed, and "off" four seconds after the last key or on
/// send — the web's useTypingSignal.
class ChatTypingSignal {
  ChatTypingSignal(this.conversationId);

  final int conversationId;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _on = false;
  Timer? _timer;

  void keystroke() {
    final now = DateTime.now();
    if (!_on || now.difference(_lastSent) > const Duration(seconds: 3)) {
      _on = true;
      _lastSent = now;
      _send(true);
    }
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 4), stop);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_on) {
      _on = false;
      _send(false);
    }
  }

  void dispose() => stop();

  void _send(bool typing) {
    RealtimeService.instance.emitQuiet('typing', {
      'conversationId': conversationId,
      'typing': typing,
    });
  }
}

// =============================================================================
// The bridge
// =============================================================================

class ChatRealtimeBridge {
  ChatRealtimeBridge(this._ref);

  final Ref _ref;
  final List<StreamSubscription<dynamic>> _subs = [];
  RealtimeService get _realtime => _ref.read(realtimeServiceProvider);

  int? _myId;
  Future<int?>? _myIdLoading;

  Future<int?> _me() {
    if (_myId != null) return Future.value(_myId);
    return _myIdLoading ??= SecureStorage().getUser().then((user) {
      _myId = _asInt(user?['id']);
      _myIdLoading = null;
      return _myId;
    }).catchError((_) {
      _myIdLoading = null;
      return null;
    });
  }

  ChatNotifier get _chat => _ref.read(chatProvider.notifier);
  ChatPresenceNotifier get _presence => _ref.read(chatPresenceProvider.notifier);
  ChatTypingNotifier get _typing => _ref.read(chatTypingProvider.notifier);

  void start() {
    final rt = _realtime;

    _subs.addAll([
      rt.onConnected.listen((_) => _onConnected()),
      rt.onResumed.listen((_) => _onResumed()),
      rt.statusStream.listen(_onStatus),
      rt.on('message:new').listen((d) => _guard(() => _onMessage(d))),
      rt.on('message:deleted').listen((d) => _guard(() => _onDeleted(d))),
      rt.on('receipt:update').listen((d) => _guard(() => _onReceipt(d))),
      rt.on('typing').listen((d) => _guard(() => _onTyping(d))),
      rt.on('presence:update').listen((d) => _guard(() => _onPresence(d))),
      rt
          .on('conversation:updated')
          .listen((d) => _guard(() => _onConversation(d))),
    ]);

    unawaited(rt.connect());
    if (rt.isConnected) _onConnected();
  }

  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
  }

  Future<void> _guard(FutureOr<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      debugPrint('Chat realtime event failed: $e');
    }
  }

  /// Whatever happened while the socket was down is fetched once; the push
  /// takes over again from here.
  Future<void> _onConnected() async {
    _myId = null;
    await _me();
    _presence.refreshKnown();
    unawaited(_chat.refreshChatList());
    final active = ChatLive.activeConversationId;
    if (active != null) {
      unawaited(_chat.catchUp(active, markRead: ChatLive.isOnScreen(active)));
    }
  }

  /// Messages that arrived in the open thread while the app was in the
  /// background were counted unread; now they are on screen.
  void _onResumed() {
    final active = ChatLive.activeConversationId;
    if (active == null || !_realtime.isConnected) return;
    final row = _ref.read(chatProvider).conversations.where(
          (c) => _asInt(c['id']) == active,
        );
    final unread = row.isEmpty ? 0 : (_asInt(row.first['unreadCount']) ?? 0);
    if (unread > 0) unawaited(_chat.markConversationRead(active));
  }

  void _onStatus(RealtimeStatus status) {
    if (status == RealtimeStatus.connected) return;
    _presence.clear();
    _typing.clear();
    if (status == RealtimeStatus.idle) {
      // Signed out: nothing of this account stays in memory.
      _myId = null;
      _presence.reset();
      _chat.reset();
    }
  }

  Future<void> _onMessage(dynamic data) async {
    if (data is! Map) return;
    final cid = _asInt(data['conversationId']);
    final raw = data['message'];
    if (cid == null || raw is! Map) return;
    final message = Map<String, dynamic>.from(raw);

    final me = await _me();
    final mine = me != null && _asInt(message['senderId']) == me;
    final onScreen = ChatLive.isOnScreen(cid);

    _chat.applyIncomingMessage(cid, message, mine: mine, onScreen: onScreen);

    if (!mine) {
      final senderId = _asInt(message['senderId']);
      if (senderId != null) {
        _typing.set(cid, senderId, message['senderName']?.toString() ?? '', false);
      }
      if (onScreen) {
        _realtime.emitQuiet('message:read', {'conversationId': cid});
      } else {
        final messageId = _asInt(message['id']);
        if (messageId != null) {
          _realtime.emitQuiet('message:delivered', {
            'conversationId': cid,
            'messageId': messageId,
          });
        }
      }
    }
  }

  void _onDeleted(dynamic data) {
    if (data is! Map) return;
    final cid = _asInt(data['conversationId']);
    final mid = _asInt(data['messageId']);
    if (cid == null || mid == null) return;
    _chat.applyDeletedMessage(cid, mid);
  }

  void _onReceipt(dynamic data) {
    if (data is! Map) return;
    final cid = _asInt(data['conversationId']);
    final uid = _asInt(data['userId']);
    if (cid == null || uid == null) return;
    _chat.applyReceipt(
      cid,
      uid,
      lastReadAt: data['lastReadAt']?.toString(),
      lastDeliveredAt: data['lastDeliveredAt']?.toString(),
    );
  }

  void _onTyping(dynamic data) {
    if (data is! Map) return;
    final cid = _asInt(data['conversationId']);
    final uid = _asInt(data['userId']);
    if (cid == null || uid == null) return;
    _typing.set(
      cid,
      uid,
      data['fullName']?.toString() ?? '',
      data['typing'] == true,
    );
  }

  void _onPresence(dynamic data) {
    if (data is! Map) return;
    final uid = _asInt(data['userId']);
    if (uid == null) return;
    _presence.set(
      uid,
      ChatPresence(
        online: data['online'] == true,
        lastSeenAt: data['lastSeenAt']?.toString(),
      ),
    );
  }

  Future<void> _onConversation(dynamic data) async {
    if (data is! Map) return;
    final cid = _asInt(data['conversationId']);
    if (cid == null) return;
    final removed = (data['removedUserIds'] is List)
        ? (data['removedUserIds'] as List).map(_asInt).whereType<int>().toSet()
        : <int>{};
    final me = await _me();
    _chat.applyConversationUpdated(
      cid,
      removedMe: me != null && removed.contains(me),
      markRead: ChatLive.isOnScreen(cid),
    );
  }
}

/// Watched by the signed-in shell: opens the socket and keeps chat live.
final chatRealtimeProvider = Provider<ChatRealtimeBridge>((ref) {
  final bridge = ChatRealtimeBridge(ref);
  ref.onDispose(bridge.dispose);
  bridge.start();
  return bridge;
});

// =============================================================================
// Widgets
// =============================================================================

/// A subtle strip while the socket is down. Waits a moment before showing,
/// so a quick reconnect (or the resume after a short background) does not
/// flash it.
class RealtimeConnectionBanner extends ConsumerStatefulWidget {
  const RealtimeConnectionBanner({super.key});

  @override
  ConsumerState<RealtimeConnectionBanner> createState() =>
      _RealtimeConnectionBannerState();
}

class _RealtimeConnectionBannerState
    extends ConsumerState<RealtimeConnectionBanner> {
  Timer? _delay;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _track(ref.read(realtimeServiceProvider).status);
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  void _track(RealtimeStatus status) {
    final down = status == RealtimeStatus.connecting ||
        status == RealtimeStatus.reconnecting ||
        status == RealtimeStatus.refused;
    if (!down) {
      _delay?.cancel();
      _delay = null;
      if (_show) setState(() => _show = false);
      return;
    }
    if (_show || _delay != null) return;
    _delay = Timer(const Duration(milliseconds: 1500), () {
      _delay = null;
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<RealtimeStatus>>(realtimeStatusProvider, (_, next) {
      final value = next.valueOrNull;
      if (value != null) _track(value);
    });
    final status = ref.watch(realtimeStatusProvider).valueOrNull ??
        ref.read(realtimeServiceProvider).status;

    final refused = status == RealtimeStatus.refused;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: !_show
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppColors.saffronTint,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!refused)
                    const SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: AppColors.saffronText,
                      ),
                    )
                  else
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 13,
                      color: AppColors.saffronText,
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      ref.tr(refused ? 'chat.liveOff' : 'chat.connecting'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.saffronText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// One grey tick sent, two when every other participant's device has it,
/// two in navy when everyone has read it — each derived from the
/// participants' own watermarks, as the web's Receipt does.
class ChatReceiptTicks extends ConsumerWidget {
  final Map<String, dynamic> message;
  final List<Map<String, dynamic>> readers;
  final Color color;

  const ChatReceiptTicks({
    super.key,
    required this.message,
    required this.readers,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final at = DateTime.tryParse(message['createdAt']?.toString() ?? '');

    bool reached(dynamic iso) {
      if (at == null || iso == null) return false;
      final t = DateTime.tryParse(iso.toString());
      return t != null && !t.isBefore(at);
    }

    final read = readers.where((r) => reached(r['lastReadAt'])).length;
    final delivered = readers
        .where((r) => reached(r['lastReadAt']) || reached(r['lastDeliveredAt']))
        .length;

    final String state;
    if (readers.isEmpty) {
      state = 'sent';
    } else if (read == readers.length) {
      state = 'read';
    } else if (read > 0) {
      state = 'partial';
    } else if (delivered == readers.length) {
      state = 'delivered';
    } else {
      state = 'sent';
    }

    final label = switch (state) {
      'sent' => ref.tr('chat.receiptSent'),
      'delivered' => ref.tr('chat.receiptDelivered'),
      'partial' => ref
          .tr('chat.receiptReadBy')
          .replaceAll('{count}', '$read')
          .replaceAll('{total}', '${readers.length}'),
      _ => ref.tr('chat.receiptRead'),
    };

    return Semantics(
      label: label,
      child: Tooltip(
        message: label,
        child: Icon(
          state == 'sent' ? Icons.done_rounded : Icons.done_all_rounded,
          size: 13,
          color: state == 'read' ? AppColors.navy : color.withValues(alpha: .8),
        ),
      ),
    );
  }
}
