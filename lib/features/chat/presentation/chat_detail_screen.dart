import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/chat/providers/chat_provider.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final int conversationId;
  final String title;

  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    required this.title,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_handleScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ref.read(chatProvider.notifier).loadMessages(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // PAGINATION
  // ============================================================

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;

    // ListView is reversed.
    //
    // pixels near maxScrollExtent means the user is reaching
    // the oldest/top side of the conversation.
    if (position.pixels >= position.maxScrollExtent - 120) {
      ref.read(chatProvider.notifier).loadOlderMessages(widget.conversationId);
    }
  }

  Future<void> _refresh() async {
    await ref
        .read(chatProvider.notifier)
        .loadMessages(widget.conversationId, refresh: true);
  }

  // ============================================================
  // SEND
  // ============================================================

  Future<void> _send() async {
    final text = _messageController.text.trim();

    if (text.isEmpty) {
      return;
    }

    _messageController.clear();

    final message = await ref
        .read(chatProvider.notifier)
        .sendMessage(conversationId: widget.conversationId, body: text);

    if (!mounted || message == null) {
      return;
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _confirmDelete(Map<String, dynamic> message) async {
    final messageId = int.tryParse(message['id']?.toString() ?? '');

    if (messageId == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _DeleteMessageDialog(message: message['body']?.toString() ?? '');
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    await ref
        .read(chatProvider.notifier)
        .deleteMessage(
          conversationId: widget.conversationId,
          messageId: messageId,
        );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);

    final thread =
        state.threads[widget.conversationId] ?? const ChatThreadState();

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,

      appBar: AppBar(
        backgroundColor: AppColors.whiteBackgroundColor,
        surfaceTintColor: AppColors.whiteBackgroundColor,
        elevation: 0,

        title: Row(
          children: [
            _buildAvatar(widget.title, 40),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textColor,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    'Chat',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.mutedColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: thread.isLoading && thread.messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      color: AppColors.primaryFillColor,
                      onRefresh: _refresh,
                      child: _buildMessages(thread),
                    ),
            ),

            _buildComposer(thread),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages(ChatThreadState thread) {
    if (thread.error != null && thread.messages.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              thread.error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            ),
          ),
        ],
      );
    }

    if (thread.messages.isEmpty) {
      return ListView(
        reverse: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [_buildEmptyConversation()],
      );
    }

    final displayItems = _buildChatDisplayItems(thread.messages);

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: displayItems.length + (thread.isLoadingOlder ? 1 : 0),
      itemBuilder: (context, index) {
        // Loading indicator belongs at the oldest/top side.
        if (thread.isLoadingOlder && index == displayItems.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        // Because reverse=true:
        //
        // index 0 = newest visual item
        // last index = oldest visual item
        final itemIndex = displayItems.length - 1 - index;

        final item = displayItems[itemIndex];

        if (item.isDateSeparator) {
          return _buildDateSeparator(item.date!);
        }

        return _buildMessageBubble(item.message!, thread);
      },
    );
  }

  // ============================================================
  // DATE GROUPING
  // ============================================================

  List<_ChatDisplayItem> _buildChatDisplayItems(
    List<Map<String, dynamic>> messages,
  ) {
    final items = <_ChatDisplayItem>[];

    DateTime? previousDate;

    for (final message in messages) {
      final createdAt = DateTime.tryParse(
        message['createdAt']?.toString() ?? '',
      );

      // If the message does not contain a valid date,
      // still show the message.
      if (createdAt == null) {
        items.add(_ChatDisplayItem.message(message));

        continue;
      }

      final localDate = createdAt.toLocal();

      final currentDay = DateTime(
        localDate.year,
        localDate.month,
        localDate.day,
      );

      final isNewDay =
          previousDate == null ||
          previousDate.year != currentDay.year ||
          previousDate.month != currentDay.month ||
          previousDate.day != currentDay.day;

      if (isNewDay) {
        items.add(_ChatDisplayItem.date(currentDay));
      }

      items.add(_ChatDisplayItem.message(message));

      previousDate = currentDay;
    }

    return items;
  }

  Widget _buildDateSeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.mutedColor.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _formatDateLabel(date),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF665F63),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final yesterday = today.subtract(const Duration(days: 1));

    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    }

    if (dateOnly == yesterday) {
      return 'Yesterday';
    }

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} '
        '${date.day}, '
        '${date.year}';
  }

  // ============================================================
  // MESSAGE BUBBLE
  // ============================================================

  Widget _buildMessageBubble(
    Map<String, dynamic> message,
    ChatThreadState thread,
  ) {
    final mine = message['mine'] == true;

    final body = message['body']?.toString() ?? '';

    final createdAt = DateTime.tryParse(message['createdAt']?.toString() ?? '');

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: mine || message['senderId'] != null
            ? () => _confirmDelete(message)
            : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * .78,
          ),
          child: IntrinsicWidth(
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: mine
                    ? AppColors.primaryFillColor
                    : AppColors.mutedColor.withValues(alpha: .05),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(mine ? 16 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 16),
                ),
                boxShadow: mine
                    ? [
                        BoxShadow(
                          color: AppColors.primaryFillColor.withOpacity(.16),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(.025),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (body.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        body,
                        softWrap: true,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.35,
                          color: mine ? Colors.white : AppColors.textColor,
                        ),
                      ),
                    ),

                  const SizedBox(height: 4),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (createdAt != null)
                        Text(
                          _formatTime(createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                            color: mine
                                ? Colors.white.withOpacity(.78)
                                : const Color(0xFF999296),
                          ),
                        ),

                      if (mine) ...[
                        const SizedBox(width: 4),

                        _buildReadReceipt(message, thread),

                        // const SizedBox(width: 5),

                        // GestureDetector(
                        //   behavior: HitTestBehavior.opaque,
                        //   onTap: () => _confirmDelete(message),
                        //   child: Icon(
                        //     Icons.close_rounded,
                        //     size: 12,
                        //     color: Colors.white.withOpacity(.72),
                        //   ),
                        // ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // READ RECEIPT
  // ============================================================

  Widget _buildReadReceipt(
    Map<String, dynamic> message,
    ChatThreadState thread,
  ) {
    final createdAt = DateTime.tryParse(message['createdAt']?.toString() ?? '');

    if (createdAt == null) {
      return const Icon(Icons.done_rounded, size: 13, color: Colors.white70);
    }

    bool readByEveryone = false;

    for (final reader in thread.readers) {
      final lastReadAt = DateTime.tryParse(
        reader['lastReadAt']?.toString() ?? '',
      );

      if (lastReadAt != null && !lastReadAt.isBefore(createdAt)) {
        readByEveryone = true;
        break;
      }
    }

    return Icon(
      readByEveryone ? Icons.done_all_rounded : Icons.done_rounded,
      size: 13,
      color: Colors.white70,
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyConversation() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 150),

        Container(
          width: 68,
          height: 68,
          decoration: const BoxDecoration(
            color: Color(0xFFFFE8ED),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppColors.primaryFillColor,
            size: 30,
          ),
        ),

        const SizedBox(height: 14),

        Text(
          'Say hello',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textColor,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          'No messages here yet — send the first one.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: const Color(0xFF777177),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // COMPOSER
  // ============================================================

  Widget _buildComposer(ChatThreadState thread) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDE5E8))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, maxHeight: 120),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEDE5E8)),
              ),
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppColors.textColor,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFFAAA2A6),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          SizedBox(
            width: 44,
            height: 44,
            child: Material(
              color: AppColors.primaryFillColor,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: thread.isSending ? null : _send,
                child: thread.isSending
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _buildAvatar(String name, double size) {
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryFillColor.withValues(alpha: .1),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: GoogleFonts.inter(
          fontSize: size * .34,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryFillColor,
        ),
      ),
    );
  }

  // ============================================================
  // TIME
  // ============================================================

  String _formatTime(DateTime date) {
    final local = date.toLocal();

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;

    final minute = local.minute.toString().padLeft(2, '0');

    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}

// ================================================================
// CHAT DISPLAY ITEM
// ================================================================

class _ChatDisplayItem {
  final Map<String, dynamic>? message;
  final DateTime? date;

  const _ChatDisplayItem.message(this.message) : date = null;

  const _ChatDisplayItem.date(this.date) : message = null;

  bool get isDateSeparator => date != null;
}

// ================================================================
// DELETE SHEET
// ================================================================
class _DeleteMessageDialog extends StatelessWidget {
  final String message;

  const _DeleteMessageDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------------------------------------------------------
            // HEADER
            // -------------------------------------------------------

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Delete message',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textColor,
                    ),
                  ),
                ),

                // InkWell(
                //   borderRadius: BorderRadius.circular(20),
                //   onTap: () {
                //     Navigator.of(context).pop(false);
                //   },
                //   child: const Padding(
                //     padding: EdgeInsets.all(4),
                //     child: Icon(
                //       Icons.close_rounded,
                //       size: 24,
                //       color: Color(0xFF777177),
                //     ),
                //   ),
                // ),
              ],
            ),

            const SizedBox(height: 12),

            // -------------------------------------------------------
            // DESCRIPTION
            // -------------------------------------------------------
            Text(
              'This message will disappear for everyone in this chat. This cannot be undone.',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: const Color(0xFF777177),
              ),
            ),

            // -------------------------------------------------------
            // MESSAGE PREVIEW
            // -------------------------------------------------------
            if (message.trim().isNotEmpty) ...[
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.mutedColor.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    height: 1.4,
                    color: AppColors.textColor,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // -------------------------------------------------------
            // ACTIONS
            // -------------------------------------------------------
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: const BorderSide(color: AppColors.borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: AppColors.primaryFillColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Delete',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
