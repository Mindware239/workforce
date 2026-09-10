import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    final optimisticMessage =
        <String, dynamic>{
      'id': localId,
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
      ),
    );

    // Return immediately so the UI does not wait.
    return optimisticMessage;
  }

  Future<void> _sendTextToServer({
    required int conversationId,
    required String localId,
    required String body,
  }) async {
    try {
      final serverMessage =
          await repository.sendMessage(
        conversationId: conversationId,
        body: body,
      );

      final current = thread(conversationId);

      final updated =
          current.messages.map((message) {
        if (message['id']?.toString() ==
            localId) {
          return {
            ...serverMessage,
            'pending': false,
            'failed': false,
            'localOnly': false,
            'type': _messageType(
              serverMessage,
              fallback: 'text',
            ),
          };
        }

        return message;
      }).toList();

      _setThread(
        conversationId,
        current.copyWith(
          messages:
              _deduplicateMessages(updated),
          isSending: false,
          clearError: true,
        ),
      );

      await _saveMessagesLocally(
        conversationId,
        updated,
      );

      // Update chat list without showing a loader.
      unawaited(
        loadConversations(
          showLoading: false,
        ),
      );
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

    final updated =
        current.messages.map((item) {
      if (item['id']?.toString() == localId) {
        return {
          ...item,
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
  }) async {
    if (!await file.exists()) {
      return null;
    }

    final localId =
        'local_${type}_${DateTime.now().microsecondsSinceEpoch}';

    final optimisticMessage =
        <String, dynamic>{
      'id': localId,
      'conversationId': conversationId,
      'body': '',
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
      ),
    );

    return optimisticMessage;
  }

  Future<void> _sendAttachmentToServer({
    required int conversationId,
    required String localId,
    required File file,
    required String type,
  }) async {
    try {
      final serverMessage =
          await repository.sendAttachment(
        conversationId: conversationId,
        file: file,
      );

      final current = thread(conversationId);

      final updated =
          current.messages.map((message) {
        if (message['id']?.toString() ==
            localId) {
          return {
            ...serverMessage,
            'pending': false,
            'failed': false,
            'localOnly': false,
            'type': type,
            'attachmentType': type,
          };
        }

        return message;
      }).toList();

      _setThread(
        conversationId,
        current.copyWith(
          messages:
              _deduplicateMessages(updated),
          isSending: false,
          clearError: true,
        ),
      );

      await _saveMessagesLocally(
        conversationId,
        updated,
      );

      unawaited(
        loadConversations(
          showLoading: false,
        ),
      );
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

    final updated =
        current.messages.map((item) {
      if (item['id']?.toString() == localId) {
        return {
          ...item,
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

      _setConversationUnreadCount(
        conversationId,
        0,
      );
    } catch (_) {
      // Do not block UI.
    }
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

    for (final local in localOnly) {
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

        if (type == 'text') {
          return 'text';
        }
      }
    }

    if (message['attachment'] != null) {
      final attachment =
          message['attachment'];

      if (attachment is Map) {
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