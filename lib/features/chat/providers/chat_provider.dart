import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:workforce/core/realtime/realtime_service.dart';
import 'package:workforce/features/chat/data/chat_repository.dart';

// ================================================================
// Thread state
// ================================================================

class ChatThreadState {
  final bool isLoading;
  final bool isLoadingOlder;
  final bool isSending;

  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> readers;

  final bool hasMoreOlder;

  final String? error;

  const ChatThreadState({
    this.isLoading = false,
    this.isLoadingOlder = false,
    this.isSending = false,
    this.messages = const [],
    this.readers = const [],
    this.hasMoreOlder = false,
    this.error,
  });

  ChatThreadState copyWith({
    bool? isLoading,
    bool? isLoadingOlder,
    bool? isSending,
    List<Map<String, dynamic>>? messages,
    List<Map<String, dynamic>>? readers,
    bool? hasMoreOlder,
    String? error,
    bool clearError = false,
  }) {
    return ChatThreadState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      isSending: isSending ?? this.isSending,
      messages: messages ?? this.messages,
      readers: readers ?? this.readers,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ================================================================
// Main chat state
// ================================================================

class ChatState {
  final bool isLoadingConversations;
  final bool isLoadingContacts;
  final bool isOpeningConversation;

  final List<Map<String, dynamic>> conversations;
  final List<Map<String, dynamic>> contacts;

  final int unreadCount;

  final Map<int, ChatThreadState> threads;

  final String? error;

  const ChatState({
    this.isLoadingConversations = false,
    this.isLoadingContacts = false,
    this.isOpeningConversation = false,
    this.conversations = const [],
    this.contacts = const [],
    this.unreadCount = 0,
    this.threads = const {},
    this.error,
  });

  ChatState copyWith({
    bool? isLoadingConversations,
    bool? isLoadingContacts,
    bool? isOpeningConversation,
    List<Map<String, dynamic>>? conversations,
    List<Map<String, dynamic>>? contacts,
    int? unreadCount,
    Map<int, ChatThreadState>? threads,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      isLoadingConversations:
          isLoadingConversations ?? this.isLoadingConversations,
      isLoadingContacts:
          isLoadingContacts ?? this.isLoadingContacts,
      isOpeningConversation:
          isOpeningConversation ?? this.isOpeningConversation,
      conversations: conversations ?? this.conversations,
      contacts: contacts ?? this.contacts,
      unreadCount: unreadCount ?? this.unreadCount,
      threads: threads ?? this.threads,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ================================================================
// Notifier
// ================================================================

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository repository;

  ChatNotifier({
    required this.repository,
  }) : super(const ChatState());

  // ==============================================================
  // CHAT LIST
  // ==============================================================

  Future<void> loadConversations({
    bool showLoading = true,
  }) async {
    if (showLoading) {
      state = state.copyWith(
        isLoadingConversations: true,
        clearError: true,
      );
    }

    try {
      final conversations = await repository.getConversations();

      state = state.copyWith(
        isLoadingConversations: false,
        conversations: conversations,
        clearError: true,
      );

      await loadUnreadCount(showLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingConversations: false,
        error: _cleanError(e),
      );
    }
  }

  Future<void> refreshChatList() async {
    await loadConversations(showLoading: false);
    await loadUnreadCount(showLoading: false);
  }

  // ==============================================================
  // UNREAD COUNT
  // ==============================================================

  Future<void> loadUnreadCount({
    bool showLoading = false,
  }) async {
    try {
      final count = await repository.getUnreadCount();

      state = state.copyWith(
        unreadCount: count,
      );
    } catch (_) {
      // Badge failure should not break chat UI.
    }
  }

  // ==============================================================
  // CONTACTS
  // ==============================================================

  Future<void> loadContacts({
    String? search,
  }) async {
    state = state.copyWith(
      isLoadingContacts: true,
      clearError: true,
    );

    try {
      final contacts = await repository.getContacts(
        search: search,
      );

      state = state.copyWith(
        isLoadingContacts: false,
        contacts: contacts,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingContacts: false,
        error: _cleanError(e),
      );
    }
  }

  // ==============================================================
  // OPEN DIRECT CHAT
  // ==============================================================

  Future<Map<String, dynamic>?> openDirectChat({
    required int userId,
  }) async {
    state = state.copyWith(
      isOpeningConversation: true,
      clearError: true,
    );

    try {
      final conversation =
          await repository.openDirectConversation(
        userId: userId,
      );

      state = state.copyWith(
        isOpeningConversation: false,
        clearError: true,
      );

      await loadConversations(
        showLoading: false,
      );

      return conversation;
    } catch (e) {
      state = state.copyWith(
        isOpeningConversation: false,
        error: _cleanError(e),
      );

      return null;
    }
  }

  // ==============================================================
  // THREAD
  // ==============================================================

  ChatThreadState thread(int conversationId) {
    return state.threads[conversationId] ??
        const ChatThreadState();
  }

  void _setThread(
    int conversationId,
    ChatThreadState threadState,
  ) {
    final threads =
        Map<int, ChatThreadState>.from(state.threads);

    threads[conversationId] = threadState;

    state = state.copyWith(
      threads: threads,
    );
  }

  // ==============================================================
  // LOCAL CACHE
  // ==============================================================

  String _cacheKey(int conversationId) {
    return 'chat_messages_$conversationId';
  }

  Future<void> _saveMessagesLocally(
    int conversationId,
    List<Map<String, dynamic>> messages,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Keep the local cache reasonably small.
      final cached = messages.length > 200
          ? messages.sublist(messages.length - 200)
          : messages;

      await prefs.setString(
        _cacheKey(conversationId),
        jsonEncode(cached),
      );
    } catch (_) {
      // Cache failure must never break chat.
    }
  }

  Future<List<Map<String, dynamic>>> _getLocalMessages(
    int conversationId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final value = prefs.getString(
        _cacheKey(conversationId),
      );

      if (value == null || value.isEmpty) {
        return [];
      }

      final decoded = jsonDecode(value);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ==============================================================
  // INITIAL MESSAGE PAGE
  // ==============================================================

  Future<void> loadMessages(
    int conversationId, {
    bool refresh = false,
  }) async {
    var current = thread(conversationId);

    if (current.isLoading) {
      return;
    }

    // ------------------------------------------------------------
    // First show cached messages immediately.
    // ------------------------------------------------------------

    if (current.messages.isEmpty) {
      final localMessages =
          await _getLocalMessages(conversationId);

      if (localMessages.isNotEmpty) {
        current = thread(conversationId);

        _setThread(
          conversationId,
          current.copyWith(
            messages: _deduplicateMessages(localMessages),
            clearError: true,
          ),
        );
      }
    }

    current = thread(conversationId);

    _setThread(
      conversationId,
      current.copyWith(
        isLoading: true,
        clearError: true,

        // Do not clear optimistic messages during refresh.
        messages: current.messages,
      ),
    );

    try {
      final page = await repository.getMessages(
        conversationId: conversationId,
        limit: 50,
      );

      final latestCurrent = thread(conversationId);

      final merged = _mergeServerMessages(
        serverMessages: page.items,
        localMessages: latestCurrent.messages,
      );

      _setThread(
        conversationId,
        latestCurrent.copyWith(
          isLoading: false,
          messages: _deduplicateMessages(merged),
          readers: page.readers,
          hasMoreOlder: page.hasMore,
          clearError: true,
        ),
      );

      final updated = thread(conversationId).messages;

      await _saveMessagesLocally(
        conversationId,
        updated,
      );

      await markConversationRead(conversationId);

      _setConversationUnreadCount(
        conversationId,
        0,
      );

      await loadUnreadCount(
        showLoading: false,
      );
    } catch (e) {
      final latest = thread(conversationId);

      _setThread(
        conversationId,
        latest.copyWith(
          isLoading: false,
          error: _cleanError(e),
        ),
      );
    }
  }

  // ==============================================================
  // LOAD OLDER MESSAGES
  // ==============================================================

  Future<void> loadOlderMessages(
    int conversationId,
  ) async {
    final current = thread(conversationId);

    if (current.isLoadingOlder ||
        !current.hasMoreOlder ||
        current.messages.isEmpty) {
      return;
    }

    final serverMessages = current.messages
        .where(
          (message) => !_isLocalMessage(message),
        )
        .toList();

    if (serverMessages.isEmpty) {
      return;
    }

    final oldestId =
        _messageId(serverMessages.first);

    if (oldestId == null) {
      return;
    }

    _setThread(
      conversationId,
      current.copyWith(
        isLoadingOlder: true,
        clearError: true,
      ),
    );

    try {
      final page = await repository.getMessages(
        conversationId: conversationId,
        before: oldestId,
        limit: 50,
      );

      final latest = thread(conversationId);

      final merged = [
        ...page.items,
        ...latest.messages,
      ];

      final messages =
          _deduplicateMessages(merged);

      _setThread(
        conversationId,
        latest.copyWith(
          isLoadingOlder: false,
          messages: messages,
          readers: page.readers,
          hasMoreOlder: page.hasMore,
        ),
      );

      await _saveMessagesLocally(
        conversationId,
        messages,
      );
    } catch (e) {
      final latest = thread(conversationId);

      _setThread(
        conversationId,
        latest.copyWith(
          isLoadingOlder: false,
          error: _cleanError(e),
        ),
      );
    }
  }

  // ==============================================================
  // SEND TEXT
  //
  // Optimistic:
  // 1. Add message immediately.
  // 2. Save locally.
  // 3. Send API in background.
  // 4. Replace local message with server message.
  // ==============================================================

  Future<Map<String, dynamic>?> sendMessage({
    required int conversationId,
    required String body,
  }) async {
    final text = body.trim();

    if (text.isEmpty) {
      return null;
    }

    final localId =
        'local_text_${DateTime.now().microsecondsSinceEpoch}';

    // Sent with every attempt, so a retry after a dropped connection (or
    // a socket send that timed out and is retried over REST) lands once.
    final clientId = RealtimeService.newClientId();

    final optimisticMessage =
        <String, dynamic>{
      'id': localId,
      'clientId': clientId,
      'conversationId': conversationId,
      'body': text,
      'mine': true,
      'createdAt':
          DateTime.now().toIso8601String(),

      'type': 'text',

      'localOnly': true,
      'pending': true,
      'failed': false,
    };

    final current = thread(conversationId);

    final updated = [
      ...current.messages,
      optimisticMessage,
    ];

    _setThread(
      conversationId,
      current.copyWith(
        messages: _deduplicateMessages(updated),
        isSending: false,
        clearError: true,
      ),
    );

    await _saveMessagesLocally(
      conversationId,
      updated,
    );

    unawaited(
      _sendTextToServer(
        conversationId: conversationId,
        localId: localId,
        body: text,
        clientId: clientId,
      ),
    );

    // Return immediately so the UI does not wait.
    return optimisticMessage;
  }

  /// Text goes over the socket when it is up, and over REST when it is down
  /// or the socket did not answer. Both carry the same clientId.
  Future<void> _sendTextToServer({
    required int conversationId,
    required String localId,
    required String body,
    required String clientId,
  }) async {
    try {
      final realtime = RealtimeService.instance;
      Map<String, dynamic>? serverMessage;

      if (realtime.isConnected) {
        try {
          final reply = await realtime.emitWithAck('message:send', {
            'conversationId': conversationId,
            'body': body,
            'clientId': clientId,
          });
          final message = reply['message'];
          if (message is Map) {
            serverMessage = {
              ...Map<String, dynamic>.from(message),
              'mine': true,
            };
          }
        } on RealtimeException catch (e) {
          // Refused outright (not a member, chat off): REST would say the same.
          if (e.code != 'OFFLINE' && e.code != 'TIMEOUT') rethrow;
        }
      }

      serverMessage ??= await repository.sendMessage(
        conversationId: conversationId,
        body: body,
        clientId: clientId,
      );

      await _settleLocal(
        conversationId,
        localId,
        serverMessage,
        type: _messageType(serverMessage, fallback: 'text'),
      );

      // While live, the server's own echo updates the list.
      if (!realtime.isConnected) {
        unawaited(
          loadConversations(
            showLoading: false,
          ),
        );
      }
    } catch (e) {
      final current = thread(conversationId);

      final updated =
          current.messages.map((message) {
        if (message['id']?.toString() ==
            localId) {
          return {
            ...message,
            'pending': false,
            'failed': true,
            'localOnly': true,
            'error': _cleanError(e),
          };
        }

        return message;
      }).toList();

      _setThread(
        conversationId,
        current.copyWith(
          messages: updated,
          error: _cleanError(e),
        ),
      );

      await _saveMessagesLocally(
        conversationId,
        updated,
      );
    }
  }

  // ==============================================================
  // RETRY TEXT
  // ==============================================================

  Future<void> retryMessage({
    required int conversationId,
    required String localId,
  }) async {
    final current = thread(conversationId);

    Map<String, dynamic>? message;

    for (final item in current.messages) {
      if (item['id']?.toString() == localId) {
        message = item;
        break;
      }
    }

    if (message == null) {
      return;
    }

    final body = message['body']?.toString().trim() ?? '';

    if (body.isEmpty) {
      return;
    }

    // The same clientId as the first attempt: if that one did land, the
    // server hands back the same message instead of a second copy.
    final clientId = _clientIdOf(message) ?? RealtimeService.newClientId();

    final updated =
        current.messages.map((item) {
      if (item['id']?.toString() == localId) {
        return {
          ...item,
          'clientId': clientId,
          'pending': true,
          'failed': false,
          'error': null,
        };
      }

      return item;
    }).toList();

    _setThread(
      conversationId,
      current.copyWith(
        messages: updated,
        clearError: true,
      ),
    );

    await _saveMessagesLocally(
      conversationId,
      updated,
    );

    unawaited(
      _sendTextToServer(
        conversationId: conversationId,
        localId: localId,
        body: body,
        clientId: clientId,
      ),
    );
  }

  // ==============================================================
  // SEND ATTACHMENT
  // ==============================================================

  Future<Map<String, dynamic>?> sendAttachment({
    required int conversationId,
    required File file,
    String type = 'image',
    String? body,
  }) async {
    if (!await file.exists()) {
      return null;
    }

    final localId =
        'local_${type}_${DateTime.now().microsecondsSinceEpoch}';

    final clientId = RealtimeService.newClientId();

    final optimisticMessage =
        <String, dynamic>{
      'id': localId,
      'clientId': clientId,
      'conversationId': conversationId,
      'body': body ?? '',
      'mine': true,
      'createdAt':
          DateTime.now().toIso8601String(),

      'type': type,
      'attachmentType': type,

      'localOnly': true,
      'pending': true,
      'failed': false,

      'localPath': file.path,
    };

    final current = thread(conversationId);

    final updated = [
      ...current.messages,
      optimisticMessage,
    ];

    _setThread(
      conversationId,
      current.copyWith(
        messages: _deduplicateMessages(updated),
        isSending: false,
        clearError: true,
      ),
    );

    await _saveMessagesLocally(
      conversationId,
      updated,
    );

    unawaited(
      _sendAttachmentToServer(
        conversationId: conversationId,
        localId: localId,
        file: file,
        type: type,
        body: body,
        clientId: clientId,
      ),
    );

    return optimisticMessage;
  }

  /// Attachments always go over REST (multipart does not belong on the
  /// socket); the server still pushes the result to every device.
  Future<void> _sendAttachmentToServer({
    required int conversationId,
    required String localId,
    required File file,
    required String type,
    String? body,
    String? clientId,
  }) async {
    try {
      final serverMessage =
          await repository.sendAttachment(
        conversationId: conversationId,
        file: file,
        body: body,
        clientId: clientId,
      );

      await _settleLocal(
        conversationId,
        localId,
        serverMessage,
        type: type,
        attachmentType: type,
      );

      if (!RealtimeService.instance.isConnected) {
        unawaited(
          loadConversations(
            showLoading: false,
          ),
        );
      }
    } catch (e) {
      final current = thread(conversationId);

      final updated =
          current.messages.map((message) {
        if (message['id']?.toString() ==
            localId) {
          return {
            ...message,
            'pending': false,
            'failed': true,
            'localOnly': true,
            'error': _cleanError(e),
          };
        }

        return message;
      }).toList();

      _setThread(
        conversationId,
        current.copyWith(
          messages: updated,
          error: _cleanError(e),
        ),
      );

      await _saveMessagesLocally(
        conversationId,
        updated,
      );
    }
  }

  // ==============================================================
  // RETRY ATTACHMENT
  // ==============================================================

  Future<void> retryAttachment({
    required int conversationId,
    required String localId,
  }) async {
    final current = thread(conversationId);

    Map<String, dynamic>? message;

    for (final item in current.messages) {
      if (item['id']?.toString() == localId) {
        message = item;
        break;
      }
    }

    if (message == null) {
      return;
    }

    final path =
        message['localPath']?.toString() ?? '';

    if (path.isEmpty) {
      return;
    }

    final file = File(path);

    if (!await file.exists()) {
      return;
    }

    final type =
        message['attachmentType']?.toString() ??
            message['type']?.toString() ??
            'image';

    final clientId = _clientIdOf(message) ?? RealtimeService.newClientId();

    final updated =
        current.messages.map((item) {
      if (item['id']?.toString() == localId) {
        return {
          ...item,
          'clientId': clientId,
          'pending': true,
          'failed': false,
          'error': null,
        };
      }

      return item;
    }).toList();

    _setThread(
      conversationId,
      current.copyWith(
        messages: updated,
        clearError: true,
      ),
    );

    await _saveMessagesLocally(
      conversationId,
      updated,
    );

    unawaited(
      _sendAttachmentToServer(
        conversationId: conversationId,
        localId: localId,
        file: file,
        type: type,
        body: message['body']?.toString(),
        clientId: clientId,
      ),
    );
  }

  // ==============================================================
  // REMOVE LOCAL MESSAGE
  // ==============================================================

  Future<void> removeLocalMessage({
    required int conversationId,
    required String localId,
  }) async {
    final current = thread(conversationId);

    final updated =
        current.messages.where(
      (message) =>
          message['id']?.toString() != localId,
    ).toList();

    _setThread(
      conversationId,
      current.copyWith(
        messages: updated,
      ),
    );

    await _saveMessagesLocally(
      conversationId,
      updated,
    );
  }

  // ==============================================================
  // MARK READ
  // ==============================================================

  Future<void> markConversationRead(
    int conversationId,
  ) async {
    try {
      await repository.markConversationRead(
        conversationId: conversationId,
      );

      markReadLocally(conversationId);
    } catch (_) {
      // Do not block UI.
    }
  }

  /// The list's badge for this conversation is cleared in place, and the
  /// total with it, rather than refetched.
  void markReadLocally(int conversationId) {
    var cleared = 0;
    final updated = state.conversations.map((conversation) {
      if (_conversationId(conversation) == conversationId) {
        cleared = _int(conversation['unreadCount']);
        return {...conversation, 'unreadCount': 0};
      }
      return conversation;
    }).toList();

    final total = state.unreadCount - cleared;
    state = state.copyWith(
      conversations: updated,
      unreadCount: total < 0 ? 0 : total,
    );
  }

  // ==============================================================
  // LIVE (socket) EVENTS — see chat_realtime.dart
  // ==============================================================

  /// A pushed `message:new`. The sender's own optimistic bubble is matched
  /// by clientId and replaced, so the message is drawn once.
  void applyIncomingMessage(
    int conversationId,
    Map<String, dynamic> raw, {
    required bool mine,
    required bool onScreen,
  }) {
    final message = <String, dynamic>{
      ...raw,
      'mine': mine,
      'pending': false,
      'failed': false,
      'localOnly': false,
    };

    final current = state.threads[conversationId];

    if (current != null) {
      final id = _messageId(message);
      final known = id != null &&
          current.messages.any((m) => _messageId(m) == id);

      if (!known) {
        final clientId = _clientIdOf(message);
        var replaced = false;
        final updated = <Map<String, dynamic>>[];

        for (final m in current.messages) {
          if (!replaced &&
              clientId != null &&
              _isLocalMessage(m) &&
              _clientIdOf(m) == clientId) {
            updated.add({
              ...message,
              if (m['localPath'] != null) 'localPath': m['localPath'],
              if (m['attachmentType'] != null)
                'attachmentType': m['attachmentType'],
            });
            replaced = true;
          } else {
            updated.add(m);
          }
        }

        if (!replaced) updated.add(message);

        final messages = _deduplicateMessages(updated);
        _setThread(
          conversationId,
          current.copyWith(
            messages: messages,
            readers: mine
                ? null
                : _senderCaughtUp(current.readers, message),
          ),
        );
        unawaited(_saveMessagesLocally(conversationId, messages));
      }
    }

    _touchConversation(
      conversationId,
      message,
      countUnread: !mine && !onScreen,
    );
  }

  /// Sending moves the sender's own read and delivered watermarks to the
  /// message's time on the server, without a receipt:update of its own; a
  /// reply has evidently seen everything before it. Mirrored here so my
  /// ticks turn read when the other person answers.
  List<Map<String, dynamic>> _senderCaughtUp(
    List<Map<String, dynamic>> readers,
    Map<String, dynamic> message,
  ) {
    final senderId = _int(message['senderId']);
    final at = DateTime.tryParse(message['createdAt']?.toString() ?? '');
    if (at == null) return readers;

    String later(dynamic current) {
      final t = DateTime.tryParse(current?.toString() ?? '');
      return t != null && t.isAfter(at) ? current.toString() : at.toUtc().toIso8601String();
    }

    return readers.map((reader) {
      if (_int(reader['userId']) != senderId) return reader;
      return {
        ...reader,
        'lastReadAt': later(reader['lastReadAt']),
        'lastDeliveredAt': later(reader['lastDeliveredAt']),
      };
    }).toList();
  }

  void _touchConversation(
    int conversationId,
    Map<String, dynamic> message, {
    required bool countUnread,
  }) {
    final index = state.conversations.indexWhere(
      (c) => _conversationId(c) == conversationId,
    );

    if (index == -1) {
      // A conversation this list has not seen (new, or never loaded).
      unawaited(loadConversations(showLoading: false));
      return;
    }

    final row = state.conversations[index];
    final attachment = message['attachment'];

    final updatedRow = <String, dynamic>{
      ...row,
      'lastMessageAt': message['createdAt'],
      'unreadCount': countUnread
          ? _int(row['unreadCount']) + 1
          : row['unreadCount'],
      'lastMessage': {
        'body': message['body'],
        'senderId': message['senderId'],
        'senderName': message['senderName'],
        'attachmentKind': attachment is Map ? attachment['kind'] : null,
        'attachmentName': attachment is Map ? attachment['name'] : null,
      },
    };

    state = state.copyWith(
      conversations: [
        updatedRow,
        ...state.conversations.where(
          (c) => _conversationId(c) != conversationId,
        ),
      ],
      unreadCount: countUnread ? state.unreadCount + 1 : null,
    );
  }

  /// A pushed `message:deleted`: the bubble vanishes, the list refetches
  /// (its last line and unread count may both have changed).
  void applyDeletedMessage(int conversationId, int messageId) {
    final current = state.threads[conversationId];

    if (current != null &&
        current.messages.any((m) => _messageId(m) == messageId)) {
      final messages = current.messages
          .where((m) => _messageId(m) != messageId)
          .toList();
      _setThread(conversationId, current.copyWith(messages: messages));
      unawaited(_saveMessagesLocally(conversationId, messages));
    }

    unawaited(loadConversations(showLoading: false));
  }

  /// A pushed `receipt:update`: one participant's watermarks moved, the
  /// ticks on my messages redraw.
  void applyReceipt(
    int conversationId,
    int userId, {
    String? lastReadAt,
    String? lastDeliveredAt,
  }) {
    final current = state.threads[conversationId];
    if (current == null) return;

    var changed = false;
    final readers = current.readers.map((reader) {
      if (_int(reader['userId']) != userId) return reader;
      changed = true;
      return {
        ...reader,
        'lastReadAt': lastReadAt,
        'lastDeliveredAt': lastDeliveredAt,
      };
    }).toList();

    if (changed) {
      _setThread(conversationId, current.copyWith(readers: readers));
    }
  }

  /// A pushed `conversation:updated`: created, renamed, or membership
  /// changed. Removed from it → it leaves the list.
  void applyConversationUpdated(
    int conversationId, {
    required bool removedMe,
    required bool markRead,
  }) {
    if (removedMe) {
      final threads = Map<int, ChatThreadState>.from(state.threads)
        ..remove(conversationId);
      state = state.copyWith(
        threads: threads,
        conversations: state.conversations
            .where((c) => _conversationId(c) != conversationId)
            .toList(),
      );
      unawaited(loadUnreadCount());
      return;
    }

    unawaited(loadConversations(showLoading: false));
    if (state.threads.containsKey(conversationId)) {
      unawaited(catchUp(conversationId, markRead: markRead));
    }
  }

  /// After a reconnect: everything newer than the last message held is
  /// fetched with `?after=`, and the latest page is compared with what is
  /// held to drop messages deleted meanwhile. Readers come along with both.
  Future<void> catchUp(
    int conversationId, {
    bool markRead = false,
  }) async {
    final current = state.threads[conversationId];
    if (current == null || current.isLoading) return;

    final held = current.messages
        .where((m) => !_isLocalMessage(m))
        .map(_messageId)
        .whereType<int>()
        .toList();

    if (held.isEmpty) {
      await loadMessages(conversationId, refresh: true);
      return;
    }

    try {
      var lastId = held.reduce((a, b) => a > b ? a : b);
      final fresh = <Map<String, dynamic>>[];
      List<Map<String, dynamic>>? readers;

      for (var page = 0; page < 10; page++) {
        final result = await repository.getMessages(
          conversationId: conversationId,
          after: lastId,
          limit: 100,
        );
        fresh.addAll(result.items);
        readers = result.readers;
        if (result.items.length < 100) break;
        final next = _messageId(result.items.last);
        if (next == null || next <= lastId) break;
        lastId = next;
      }

      final latest = await repository.getMessages(
        conversationId: conversationId,
        limit: 50,
      );
      readers = latest.readers;

      final latestIds =
          latest.items.map(_messageId).whereType<int>().toSet();
      final oldestLatest = latestIds.isEmpty
          ? null
          : latestIds.reduce((a, b) => a < b ? a : b);
      final freshClientIds =
          fresh.map(_clientIdOf).whereType<String>().toSet();

      final now = thread(conversationId);
      final kept = now.messages.where((m) {
        if (_isLocalMessage(m)) {
          final cid = _clientIdOf(m);
          return cid == null || !freshClientIds.contains(cid);
        }
        final id = _messageId(m);
        // Inside the window the latest page covers, but not on it: deleted.
        if (id != null &&
            oldestLatest != null &&
            id >= oldestLatest &&
            !latestIds.contains(id)) {
          return false;
        }
        return true;
      });

      final messages = _deduplicateMessages([...kept, ...fresh]);

      _setThread(
        conversationId,
        now.copyWith(messages: messages, readers: readers, clearError: true),
      );
      await _saveMessagesLocally(conversationId, messages);

      if (markRead) await markConversationRead(conversationId);
    } catch (_) {
      // The next connect, or pull-to-refresh, tries again.
    }
  }

  /// Sign-out: nothing of the previous account stays in memory.
  void reset() {
    state = const ChatState();
  }

  // ==============================================================
  // DELETE MESSAGE
  // ==============================================================

  Future<bool> deleteMessage({
    required int conversationId,
    required int messageId,
  }) async {
    try {
      await repository.deleteMessage(
        messageId: messageId,
      );

      final current =
          thread(conversationId);

      final updated =
          current.messages.where(
        (message) =>
            _messageId(message) != messageId,
      ).toList();

      _setThread(
        conversationId,
        current.copyWith(
          messages: updated,
          clearError: true,
        ),
      );

      await _saveMessagesLocally(
        conversationId,
        updated,
      );

      return true;
    } catch (e) {
      final current =
          thread(conversationId);

      _setThread(
        conversationId,
        current.copyWith(
          error: _cleanError(e),
        ),
      );

      return false;
    }
  }

  // ==============================================================
  // HELPERS
  // ==============================================================

  void _setConversationUnreadCount(
    int conversationId,
    int unreadCount,
  ) {
    final updated =
        state.conversations.map(
      (conversation) {
        final id = int.tryParse(
          conversation['id']?.toString() ?? '',
        );

        if (id == conversationId) {
          return {
            ...conversation,
            'unreadCount': unreadCount,
          };
        }

        return conversation;
      },
    ).toList();

    state = state.copyWith(
      conversations: updated,
    );
  }

  bool _isLocalMessage(
    Map<String, dynamic> message,
  ) {
    return message['localOnly'] == true ||
        message['pending'] == true ||
        message['id']
                ?.toString()
                .startsWith('local_') ==
            true;
  }

  List<Map<String, dynamic>> _mergeServerMessages({
    required List<Map<String, dynamic>> serverMessages,
    required List<Map<String, dynamic>> localMessages,
  }) {
    final localOnly = localMessages
        .where(_isLocalMessage)
        .toList();

    final result = <Map<String, dynamic>>[
      ...serverMessages,
    ];

    final serverClientIds =
        serverMessages.map(_clientIdOf).whereType<String>().toSet();

    for (final local in localOnly) {
      // Drawn once, as the real one, when the server already has it.
      final clientId = _clientIdOf(local);
      if (clientId != null && serverClientIds.contains(clientId)) {
        continue;
      }

      final localBody =
          local['body']?.toString() ?? '';

      final localCreatedAt =
          DateTime.tryParse(
        local['createdAt']?.toString() ?? '',
      );

      final localType =
          _messageType(local);

      bool alreadyOnServer = false;

      for (final server in serverMessages) {
        final serverBody =
            server['body']?.toString() ?? '';

        final serverType =
            _messageType(server);

        if (localType != serverType) {
          continue;
        }

        if (localBody.isNotEmpty &&
            localBody != serverBody) {
          continue;
        }

        final serverDate =
            DateTime.tryParse(
          server['createdAt']?.toString() ?? '',
        );

        if (localCreatedAt != null &&
            serverDate != null) {
          final difference =
              localCreatedAt
                  .difference(serverDate)
                  .inSeconds
                  .abs();

          if (difference <= 120) {
            alreadyOnServer = true;
            break;
          }
        }
      }

      if (!alreadyOnServer) {
        result.add(local);
      }
    }

    return result;
  }

  List<Map<String, dynamic>> _deduplicateMessages(
    List<Map<String, dynamic>> messages,
  ) {
    final result =
        <String, Map<String, dynamic>>{};

    for (final message in messages) {
      final key = _messageKey(message);

      if (key.isEmpty) {
        continue;
      }

      result[key] = message;
    }

    final list = result.values.toList();

    list.sort((a, b) {
      final aDate = DateTime.tryParse(
        a['createdAt']?.toString() ?? '',
      );

      final bDate = DateTime.tryParse(
        b['createdAt']?.toString() ?? '',
      );

      if (aDate == null && bDate == null) {
        return 0;
      }

      if (aDate == null) {
        return -1;
      }

      if (bDate == null) {
        return 1;
      }

      final comparison =
          aDate.compareTo(bDate);

      if (comparison != 0) {
        return comparison;
      }

      return _messageKey(a)
          .compareTo(_messageKey(b));
    });

    return list;
  }

  String _messageKey(
    Map<String, dynamic> message,
  ) {
    final id = message['id']?.toString();

    if (id != null && id.isNotEmpty) {
      return id;
    }

    final createdAt =
        message['createdAt']?.toString() ?? '';

    final body =
        message['body']?.toString() ?? '';

    return '${createdAt}_$body';
  }

  int? _messageId(
    Map<String, dynamic> message,
  ) {
    return int.tryParse(
      message['id']?.toString() ?? '',
    );
  }

  String? _clientIdOf(Map<String, dynamic> message) {
    final value = message['clientId']?.toString();
    return value == null || value.isEmpty ? null : value;
  }

  int? _conversationId(Map<String, dynamic> conversation) {
    return int.tryParse(conversation['id']?.toString() ?? '');
  }

  int _int(dynamic value) {
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// Replaces the optimistic bubble [localId] with the server's copy. If the
  /// socket's echo already replaced it, only the copy by id is refreshed.
  Future<void> _settleLocal(
    int conversationId,
    String localId,
    Map<String, dynamic> serverMessage, {
    required String type,
    String? attachmentType,
  }) async {
    final current = thread(conversationId);
    final serverId = _messageId(serverMessage);
    var replaced = false;
    final updated = <Map<String, dynamic>>[];

    for (final message in current.messages) {
      final isLocal = message['id']?.toString() == localId;
      final isEcho = serverId != null && _messageId(message) == serverId;

      if (isLocal || isEcho) {
        if (!replaced) {
          updated.add({
            ...serverMessage,
            if (message['localPath'] != null) 'localPath': message['localPath'],
            'mine': true,
            'pending': false,
            'failed': false,
            'localOnly': false,
            'type': type,
            'attachmentType': ?attachmentType,
          });
          replaced = true;
        }
        continue;
      }

      updated.add(message);
    }

    if (!replaced) {
      updated.add({
        ...serverMessage,
        'mine': true,
        'pending': false,
        'failed': false,
        'localOnly': false,
        'type': type,
        'attachmentType': ?attachmentType,
      });
    }

    final messages = _deduplicateMessages(updated);

    _setThread(
      conversationId,
      current.copyWith(
        messages: messages,
        isSending: false,
        clearError: true,
      ),
    );

    await _saveMessagesLocally(conversationId, messages);
  }

  String _messageType(
    Map<String, dynamic> message, {
    String fallback = 'text',
  }) {
    final values = [
      message['type'],
      message['messageType'],
      message['attachmentType'],
      message['mediaType'],
    ];

    for (final value in values) {
      final type =
          value?.toString().trim().toLowerCase();

      if (type != null && type.isNotEmpty) {
        if (type == 'audio') {
          return 'voice';
        }

        if (type == 'voice') {
          return 'voice';
        }

        if (type == 'image') {
          return 'image';
        }

        if (type == 'video') {
          return 'video';
        }

        if (type == 'document') {
          return 'document';
        }

        if (type == 'text') {
          return 'text';
        }
      }
    }

    if (message['attachment'] != null) {
      final attachment =
          message['attachment'];

      if (attachment is Map) {
        final kind =
            attachment['kind']?.toString().toLowerCase();

        if (kind == 'audio') return 'voice';
        if (kind == 'image') return 'image';
        if (kind == 'video') return 'video';
        if (kind == 'document') return 'document';

        final mime =
            attachment['mimeType']
                    ?.toString()
                    .toLowerCase() ??
                '';

        if (mime.startsWith('audio/')) {
          return 'voice';
        }

        if (mime.startsWith('image/')) {
          return 'image';
        }
      }

      final value =
          attachment.toString().toLowerCase();

      if (_looksLikeAudio(value)) {
        return 'voice';
      }

      if (_looksLikeImage(value)) {
        return 'image';
      }
    }

    return fallback;
  }

  bool _looksLikeImage(String value) {
    return value.endsWith('.jpg') ||
        value.endsWith('.jpeg') ||
        value.endsWith('.png') ||
        value.endsWith('.webp') ||
        value.endsWith('.gif');
  }

  bool _looksLikeAudio(String value) {
    return value.endsWith('.m4a') ||
        value.endsWith('.mp3') ||
        value.endsWith('.wav') ||
        value.endsWith('.aac') ||
        value.endsWith('.ogg') ||
        value.endsWith('.webm');
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '');
  }
}

// ================================================================
// Provider
// ================================================================

final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>(
  (ref) {
    return ChatNotifier(
      repository: ref.read(chatRepositoryProvider),
    );
  },
);