import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      isLoadingOlder:
          isLoadingOlder ?? this.isLoadingOlder,
      isSending: isSending ?? this.isSending,
      messages: messages ?? this.messages,
      readers: readers ?? this.readers,
      hasMoreOlder:
          hasMoreOlder ?? this.hasMoreOlder,
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
          isLoadingConversations ??
              this.isLoadingConversations,
      isLoadingContacts:
          isLoadingContacts ??
              this.isLoadingContacts,
      isOpeningConversation:
          isOpeningConversation ??
              this.isOpeningConversation,
      conversations:
          conversations ?? this.conversations,
      contacts:
          contacts ?? this.contacts,
      unreadCount:
          unreadCount ?? this.unreadCount,
      threads:
          threads ?? this.threads,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ================================================================
// Notifier
// ================================================================

class ChatNotifier
    extends StateNotifier<ChatState> {
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
      final conversations =
          await repository.getConversations();

      state = state.copyWith(
        isLoadingConversations: false,
        conversations: conversations,
        clearError: true,
      );

      // Load unread count independently.
      await loadUnreadCount(
        showLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingConversations: false,
        error: _cleanError(e),
      );
    }
  }

  // ==============================================================
  // PULL TO REFRESH CHAT LIST
  // ==============================================================

  Future<void> refreshChatList() async {
    await loadConversations(
      showLoading: false,
    );

    await loadUnreadCount(
      showLoading: false,
    );
  }

  // ==============================================================
  // UNREAD COUNT
  // ==============================================================

  Future<void> loadUnreadCount({
    bool showLoading = false,
  }) async {
    try {
      final count =
          await repository.getUnreadCount();

      state = state.copyWith(
        unreadCount: count,
      );
    } catch (e) {
      // Don't destroy chat UI because badge failed.
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
      final contacts =
          await repository.getContacts(
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

      // Refresh conversation list because a new
      // conversation may have been created.
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
    ChatThreadState thread,
  ) {
    final threads =
        Map<int, ChatThreadState>.from(
      state.threads,
    );

    threads[conversationId] = thread;

    state = state.copyWith(
      threads: threads,
    );
  }

  // ==============================================================
  // INITIAL MESSAGE PAGE
  //
  // No cursor = newest page
  // ==============================================================

  Future<void> loadMessages(
    int conversationId, {
    bool refresh = false,
  }) async {
    final current =
        thread(conversationId);

    if (current.isLoading) {
      return;
    }

    _setThread(
      conversationId,
      current.copyWith(
        isLoading: true,
        clearError: true,
        messages:
            refresh ? const [] : current.messages,
      ),
    );

    try {
      final page =
          await repository.getMessages(
        conversationId: conversationId,
        limit: 50,
      );

      // Server returns oldest -> newest.
      final messages =
          _deduplicateMessages(
        page.items,
      );

      _setThread(
        conversationId,
        ChatThreadState(
          isLoading: false,
          messages: messages,
          readers: page.readers,
          hasMoreOlder: page.hasMore,
        ),
      );

      // Conversation is considered read when opened.
      await markConversationRead(
        conversationId,
      );

      // Update local conversation unread count.
      _setConversationUnreadCount(
        conversationId,
        0,
      );

      await loadUnreadCount(
        showLoading: false,
      );
    } catch (e) {
      _setThread(
        conversationId,
        current.copyWith(
          isLoading: false,
          error: _cleanError(e),
        ),
      );
    }
  }

  // ==============================================================
  // LOAD OLDER MESSAGES
  //
  // before = oldest message currently held
  // ==============================================================

  Future<void> loadOlderMessages(
    int conversationId,
  ) async {
    final current =
        thread(conversationId);

    if (current.isLoadingOlder ||
        !current.hasMoreOlder ||
        current.messages.isEmpty) {
      return;
    }

    final oldestId =
        _messageId(current.messages.first);

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
      final page =
          await repository.getMessages(
        conversationId: conversationId,
        before: oldestId,
        limit: 50,
      );

      // API returns older messages oldest -> newest.
      final merged = [
        ...page.items,
        ...current.messages,
      ];

      _setThread(
        conversationId,
        current.copyWith(
          isLoadingOlder: false,
          messages:
              _deduplicateMessages(merged),
          readers: page.readers,
          hasMoreOlder: page.hasMore,
        ),
      );
    } catch (e) {
      _setThread(
        conversationId,
        current.copyWith(
          isLoadingOlder: false,
          error: _cleanError(e),
        ),
      );
    }
  }

  // ==============================================================
  // LOAD NEWER MESSAGES
  //
  // after = newest message currently held
  //
  // This is intentionally exposed for FCM/WebSocket integration.
  // Do NOT put a 30-second polling timer here.
  // ==============================================================

  Future<void> loadNewMessages(
    int conversationId,
  ) async {
    final current =
        thread(conversationId);

    if (current.messages.isEmpty) {
      await loadMessages(
        conversationId,
      );
      return;
    }

    final newestId =
        _messageId(current.messages.last);

    if (newestId == null) {
      return;
    }

    try {
      final page =
          await repository.getMessages(
        conversationId: conversationId,
        after: newestId,
        limit: 50,
      );

      if (page.items.isEmpty &&
          page.readers.isEmpty) {
        return;
      }

      final merged = [
        ...current.messages,
        ...page.items,
      ];

      _setThread(
        conversationId,
        current.copyWith(
          messages:
              _deduplicateMessages(merged),
          readers: page.readers,
        ),
      );
    } catch (e) {
      _setThread(
        conversationId,
        current.copyWith(
          error: _cleanError(e),
        ),
      );
    }
  }

  // ==============================================================
  // SEND TEXT
  // ==============================================================

  Future<Map<String, dynamic>?> sendMessage({
    required int conversationId,
    required String body,
  }) async {
    final text = body.trim();

    if (text.isEmpty) {
      return null;
    }

    final current =
        thread(conversationId);

    if (current.isSending) {
      return null;
    }

    _setThread(
      conversationId,
      current.copyWith(
        isSending: true,
        clearError: true,
      ),
    );

    try {
      final message =
          await repository.sendMessage(
        conversationId: conversationId,
        body: text,
      );

      final updatedMessages = [
        ...current.messages,
        message,
      ];

      _setThread(
        conversationId,
        current.copyWith(
          isSending: false,
          messages:
              _deduplicateMessages(
            updatedMessages,
          ),
        ),
      );

      await loadUnreadCount(
        showLoading: false,
      );

      return message;
    } catch (e) {
      _setThread(
        conversationId,
        current.copyWith(
          isSending: false,
          error: _cleanError(e),
        ),
      );

      return null;
    }
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
          current.messages
              .where(
                (message) =>
                    _messageId(message) !=
                    messageId,
              )
              .toList();

      _setThread(
        conversationId,
        current.copyWith(
          messages: updated,
          clearError: true,
        ),
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
        state.conversations.map((conversation) {
      final id =
          int.tryParse(
            conversation['id']?.toString() ?? '',
          );

      if (id == conversationId) {
        return {
          ...conversation,
          'unreadCount': unreadCount,
        };
      }

      return conversation;
    }).toList();

    state = state.copyWith(
      conversations: updated,
    );
  }

  List<Map<String, dynamic>>
      _deduplicateMessages(
    List<Map<String, dynamic>> messages,
  ) {
    final result =
        <int, Map<String, dynamic>>{};

    for (final message in messages) {
      final id =
          _messageId(message);

      if (id != null) {
        result[id] = message;
      }
    }

    final list =
        result.values.toList();

    list.sort((a, b) {
      final aDate =
          DateTime.tryParse(
            a['createdAt']?.toString() ?? '',
          );

      final bDate =
          DateTime.tryParse(
            b['createdAt']?.toString() ?? '',
          );

      if (aDate == null || bDate == null) {
        return 0;
      }

      return aDate.compareTo(bDate);
    });

    return list;
  }

  int? _messageId(
    Map<String, dynamic> message,
  ) {
    return int.tryParse(
      message['id']?.toString() ?? '',
    );
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
    StateNotifierProvider<
        ChatNotifier,
        ChatState>((ref) {
  return ChatNotifier(
    repository:
        ref.read(chatRepositoryProvider),
  );
});