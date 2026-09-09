import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:workforce/core/network/network_providers.dart';
import 'package:workforce/core/network/api_client.dart';

class ChatRepository {
  final ApiClient apiClient;

  ChatRepository({
    required this.apiClient,
  });

  // ============================================================
  // GET /api/chat/contacts
  // ============================================================

  Future<List<Map<String, dynamic>>> getContacts({
    String? search,
  }) async {
    try {
      final response = await apiClient.get(
        '/chat/contacts',
        queryParameters: {
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      );

      debugPrint('💬 Chat contacts: ${response.data}');

      final body = response.data;

      if (body is! Map) {
        throw Exception('Invalid contacts response.');
      }

      final data = body['data'];

      if (data is! List) {
        throw Exception('Contacts data not found.');
      }

      return data
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } on DioException catch (e) {
      throw _apiException(e);
    }
  }

  // ============================================================
  // GET /api/chat/conversations
  // ============================================================

  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final response = await apiClient.get(
        '/chat/conversations',
      );

      debugPrint('💬 Chat conversations: ${response.data}');

      final body = response.data;

      if (body is! Map) {
        throw Exception('Invalid conversations response.');
      }

      final data = body['data'];

      if (data is! List) {
        throw Exception('Conversations data not found.');
      }

      return data
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } on DioException catch (e) {
      throw _apiException(e);
    }
  }

  // ============================================================
  // GET /api/chat/unread-count
  // ============================================================

  Future<int> getUnreadCount() async {
    try {
      final response = await apiClient.get(
        '/chat/unread-count',
      );

      debugPrint('💬 Chat unread count: ${response.data}');

      final body = response.data;

      if (body is! Map) {
        return 0;
      }

      final data = body['data'];

      if (data is! Map) {
        return 0;
      }

      return int.tryParse(
            data['total']?.toString() ?? '0',
          ) ??
          0;
    } on DioException catch (e) {
      // Backend intentionally returns 0 when chat is disabled.
      if (e.response?.statusCode == 403) {
        return 0;
      }

      throw _apiException(e);
    }
  }

  // ============================================================
  // POST /api/chat/conversations/direct
  // ============================================================

  Future<Map<String, dynamic>> openDirectConversation({
    required int userId,
  }) async {
    try {
      final response = await apiClient.post(
        '/chat/conversations/direct',
        data: {
          'userId': userId,
        },
      );

      debugPrint(
        '💬 Open direct conversation: ${response.data}',
      );

      return _extractMap(
        response.data,
        fallbackMessage: 'Conversation not found.',
      );
    } on DioException catch (e) {
      throw _apiException(e);
    }
  }

  // ============================================================
  // GET /api/chat/conversations/{id}
  // ============================================================

  Future<Map<String, dynamic>> getConversation({
    required int conversationId,
  }) async {
    try {
      final response = await apiClient.get(
        '/chat/conversations/$conversationId',
      );

      debugPrint(
        '💬 Conversation $conversationId: ${response.data}',
      );

      return _extractMap(
        response.data,
        fallbackMessage: 'Conversation not found.',
      );
    } on DioException catch (e) {
      throw _apiException(e);
    }
  }

  // ============================================================
  // GET /api/chat/conversations/{id}/messages
  //
  // Pagination:
  //
  // Initial:
  //   no before/after
  //
  // Older:
  //   before = oldest message ID we currently have
  //
  // New:
  //   after = newest message ID we currently have
  // ============================================================

  Future<ChatMessagesPage> getMessages({
    required int conversationId,
    int? before,
    int? after,
    int limit = 50,
  }) async {
    try {
      final response = await apiClient.get(
        '/chat/conversations/$conversationId/messages',
        queryParameters: {
          if (before != null) 'before': before,
          if (after != null) 'after': after,
          'limit': limit,
        },
      );

      debugPrint(
        '💬 Messages $conversationId: ${response.data}',
      );

      final body = response.data;

      if (body is! Map) {
        throw Exception('Invalid messages response.');
      }

      final rawData = body['data'];

      if (rawData is! Map) {
        throw Exception('Messages data not found.');
      }

      final items = rawData['items'];

      final messages = items is List
          ? items
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList()
          : <Map<String, dynamic>>[];

      final readers = rawData['readers'] is List
          ? (rawData['readers'] as List)
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList()
          : <Map<String, dynamic>>[];

      return ChatMessagesPage(
        items: messages,
        hasMore: rawData['hasMore'] == true,
        readers: readers,
      );
    } on DioException catch (e) {
      throw _apiException(e);
    }
  }

  // ============================================================
  // POST /api/chat/conversations/{id}/messages
  //
  // Text message
  // ============================================================

  Future<Map<String, dynamic>> sendMessage({
    required int conversationId,
    required String body,
  }) async {
    try {
      final response = await apiClient.post(
        '/chat/conversations/$conversationId/messages',
        data: {
          'body': body,
        },
      );

      debugPrint(
        '💬 Sent message: ${response.data}',
      );

      return _extractMap(
        response.data,
        fallbackMessage: 'Message could not be sent.',
      );
    } on DioException catch (e) {
      throw _apiException(e);
    }
  }

  // ============================================================
  // POST /api/chat/conversations/{id}/messages
  //
  // Attachment + optional caption
  // ============================================================

  Future<Map<String, dynamic>> sendAttachment({
    required int conversationId,
    required File file,
    String? body,
  }) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;

      final formData = FormData.fromMap({
        if (body != null && body.trim().isNotEmpty)
          'body': body.trim(),
        'attachment': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      final response = await apiClient.dio.post(
        '/chat/conversations/$conversationId/messages',
        data: formData,
      );

      debugPrint(
        '💬 Sent attachment: ${response.data}',
      );

      return _extractMap(
        response.data,
        fallbackMessage: 'Attachment could not be sent.',
      );
    } on DioException catch (e) {
      throw _apiException(e);
    }
  }

  // ============================================================
  // POST /api/chat/conversations/{id}/read
  // ============================================================

  Future<void> markConversationRead({
    required int conversationId,
  }) async {
    try {
      final response = await apiClient.post(
        '/chat/conversations/$conversationId/read',
      );

      debugPrint(
        '💬 Marked conversation $conversationId read: '
        '${response.data}',
      );
    } on DioException catch (e) {
      throw _apiException(e);
    }
  }

  // ============================================================
  // DELETE /api/chat/messages/{messageId}
  // ============================================================

  Future<void> deleteMessage({
    required int messageId,
  }) async {
    try {
      final response = await apiClient.delete(
        '/chat/messages/$messageId',
      );

      debugPrint(
        '💬 Deleted message $messageId: ${response.data}',
      );
    } on DioException catch (e) {
      throw _apiException(e);
    }
  }

  // ============================================================
  // Response helpers
  // ============================================================

  Map<String, dynamic> _extractMap(
    dynamic responseData, {
    required String fallbackMessage,
  }) {
    if (responseData is! Map) {
      throw Exception(fallbackMessage);
    }

    // Normal API response:
    //
    // {
    //   success: true,
    //   data: {...}
    // }
    if (responseData['data'] is Map) {
      return Map<String, dynamic>.from(
        responseData['data'],
      );
    }

    // Also support APIs returning the object directly.
    return Map<String, dynamic>.from(
      responseData,
    );
  }

  Exception _apiException(DioException error) {
    final statusCode = error.response?.statusCode;

    final data = error.response?.data;

    if (data is Map) {
      final message = data['message'];

      if (message != null &&
          message.toString().trim().isNotEmpty) {
        return Exception(message.toString());
      }
    }

    if (statusCode == 401) {
      return Exception('Invalid or expired token');
    }

    if (statusCode == 403) {
      return Exception(
        'You do not have permission to perform this action',
      );
    }

    if (statusCode == 404) {
      return Exception('Resource not found');
    }

    return Exception(
      error.message ?? 'Something went wrong.',
    );
  }
}

// ================================================================
// Messages pagination response
// ================================================================

class ChatMessagesPage {
  final List<Map<String, dynamic>> items;
  final bool hasMore;
  final List<Map<String, dynamic>> readers;

  const ChatMessagesPage({
    required this.items,
    required this.hasMore,
    required this.readers,
  });
}

// ================================================================
// Providers
// ================================================================

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    apiClient: ref.read(apiClientProvider),
  );
});