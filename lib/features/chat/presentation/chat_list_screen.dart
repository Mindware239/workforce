import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/chat/providers/chat_provider.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ref.read(chatProvider.notifier).loadConversations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(chatProvider.notifier).refreshChatList();
  }

  // ============================================================
  // CHAT LIST SEARCH
  // ============================================================

  void _searchChats(String value) {
    setState(() {
      _searchQuery = value.trim().toLowerCase();
    });
  }

  List<Map<String, dynamic>> _getFilteredConversations(
    List<Map<String, dynamic>> conversations,
  ) {
    if (_searchQuery.isEmpty) {
      return conversations;
    }

    return conversations.where((conversation) {
      final title = _conversationTitle(conversation).toLowerCase();

      final lastMessage = conversation['lastMessage'];

      String body = '';
      String senderName = '';

      if (lastMessage is Map) {
        body = lastMessage['body']?.toString().toLowerCase() ?? '';
        senderName = lastMessage['senderName']?.toString().toLowerCase() ?? '';
      }

      final company = conversation['company']?.toString().toLowerCase() ?? '';

      final companyName =
          conversation['companyName']?.toString().toLowerCase() ?? '';

      return title.contains(_searchQuery) ||
          body.contains(_searchQuery) ||
          senderName.contains(_searchQuery) ||
          company.contains(_searchQuery) ||
          companyName.contains(_searchQuery);
    }).toList();
  }

  String _conversationTitle(Map<String, dynamic> conversation) {
    final title = conversation['title']?.toString().trim();

    if (title != null && title.isNotEmpty) {
      return title;
    }

    final name = conversation['name']?.toString().trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final userName = conversation['userName']?.toString().trim();

    if (userName != null && userName.isNotEmpty) {
      return userName;
    }

    final participantName = conversation['participantName']?.toString().trim();

    if (participantName != null && participantName.isNotEmpty) {
      return participantName;
    }

    return 'Chat';
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(state),

            Expanded(
              child: RefreshIndicator(
                color: AppColors.primaryFillColor,
                onRefresh: _refresh,
                child: _buildConversationList(state),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildNewMessageButton(),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(ChatState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Chat',
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),

              const Spacer(),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            'Message your manager and the owner.',
            style: GoogleFonts.inter(fontSize: 16, color: AppColors.mutedColor),
          ),

          const SizedBox(height: 16),

          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _searchChats,
              textInputAction: TextInputAction.search,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textColor,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,

                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 24,
                  color: Color(0xFF8A8387),
                ),

                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF8A8387),
                        ),
                      )
                    : null,

                hintText: 'Search chats',

                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.mutedColor,
                ),

                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONVERSATIONS
  // ============================================================

  Widget _buildConversationList(ChatState state) {
    if (state.isLoadingConversations && state.conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (state.error != null && state.conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [const SizedBox(height: 150), _buildError(state.error!)],
      );
    }

    if (state.conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [const SizedBox(height: 130), _buildEmptyState()],
      );
    }

    final conversations = _getFilteredConversations(state.conversations);

    if (conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [const SizedBox(height: 130), _buildNoSearchResults()],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];

        return _buildConversationTile(conversation);
      },
    );
  }

  // ============================================================
  // CONVERSATION TILE
  // ============================================================

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final id = int.tryParse(conversation['id']?.toString() ?? '');

    if (id == null) {
      return const SizedBox.shrink();
    }

    final title = _conversationTitle(conversation);

    final unread =
        int.tryParse(conversation['unreadCount']?.toString() ?? '0') ?? 0;

    final lastMessage = conversation['lastMessage'];

    final body = lastMessage is Map
        ? lastMessage['body']?.toString() ?? ''
        : '';

    final senderName = lastMessage is Map
        ? lastMessage['senderName']?.toString() ?? ''
        : '';

    final lastMessageAt = DateTime.tryParse(
      conversation['lastMessageAt']?.toString() ?? '',
    );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        context.push(
          '${AppRoutes.chat}/$id'
          '?title=${Uri.encodeComponent(title)}',
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildAvatar(title, size: 48),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textColor,
                          ),
                        ),
                      ),

                      if (lastMessageAt != null)
                        Text(
                          _formatTime(lastMessageAt),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF918A8E),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          body.isEmpty
                              ? 'No messages yet'
                              : senderName.isNotEmpty && senderName != title
                              ? '$senderName: $body'
                              : body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.mutedColor,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),

                      if (unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primaryFillColor,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unread > 99 ? '99' : unread.toString(),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NEW MESSAGE
  // ============================================================

  Widget _buildNewMessageButton() {
    return FloatingActionButton.extended(
      backgroundColor: AppColors.primaryFillColor,
      foregroundColor: Colors.white,
      elevation: 3,
      onPressed: _showContactsSheet,
      icon: const Icon(Icons.edit_rounded, size: 18),
      label: Text(
        'New message',
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _showContactsSheet() async {
    final notifier = ref.read(chatProvider.notifier);

    await notifier.loadContacts();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _ContactsSheet(
          onSelected: (contact) async {
            Navigator.of(context).pop();

            final userId = int.tryParse(contact['id']?.toString() ?? '');

            if (userId == null) {
              return;
            }

            final conversation = await ref
                .read(chatProvider.notifier)
                .openDirectChat(userId: userId);

            if (!mounted || conversation == null) {
              return;
            }

            final conversationId = int.tryParse(
              conversation['id']?.toString() ?? '',
            );

            if (conversationId == null) {
              return;
            }

            final title = contact['fullName']?.toString() ?? 'Chat';

            context.push(
              '${AppRoutes.chat}/$conversationId'
              '?title=${Uri.encodeComponent(title)}',
            );
          },
        );
      },
    );
  }

  // ============================================================
  // EMPTY / ERROR
  // ============================================================

  Widget _buildEmptyState() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primaryFillColor.withValues(alpha: .10),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppColors.primaryFillColor,
            size: 28,
          ),
        ),

        const SizedBox(height: 14),

        Text(
          'No chats yet',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textColor,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          'Start a conversation with someone from your contacts.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.mutedColor),
        ),
      ],
    );
  }

  Widget _buildNoSearchResults() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primaryFillColor.withValues(alpha: .10),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.search_off_rounded,
            color: AppColors.primaryFillColor,
            size: 28,
          ),
        ),

        const SizedBox(height: 14),

        Text(
          'No chats found',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textColor,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          'Try searching with a different name or message.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.mutedColor),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: Colors.redAccent,
          ),

          const SizedBox(height: 10),

          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _buildAvatar(String name, {double size = 48}) {
    final trimmedName = name.trim();

    final first = trimmedName.isEmpty
        ? '?'
        : trimmedName.characters.first.toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryFillColor.withValues(alpha: .10),
        shape: BoxShape.circle,
      ),
      child: Text(
        first,
        style: GoogleFonts.inter(
          fontSize: size * .32,
          fontWeight: FontWeight.bold,
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
// CONTACTS BOTTOM SHEET
// ================================================================

class _ContactsSheet extends ConsumerStatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSelected;

  const _ContactsSheet({required this.onSelected});

  @override
  ConsumerState<_ContactsSheet> createState() => _ContactsSheetState();
}

class _ContactsSheetState extends ConsumerState<_ContactsSheet> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;

      ref.read(chatProvider.notifier).loadContacts(search: value.trim());
    });
  }

  void _clearSearch() {
    _searchController.clear();

    ref.read(chatProvider.notifier).loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);

    return Container(
      height: MediaQuery.of(context).size.height * .82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D3D6),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'New message',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textColor,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: _search,
                textInputAction: TextInputAction.search,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textColor,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),

                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            setState(() {});
                            _clearSearch();
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        )
                      : null,

                  hintText: 'Search people',

                  hintStyle: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFFAAA2A6),
                  ),

                  filled: true,

                  fillColor: const Color(0xFFFFF8FA),

                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryFillColor,
                    ),
                  ),

                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryFillColor,
                    ),
                  ),

                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryFillColor,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: state.isLoadingContacts
                  ? const Center(child: CircularProgressIndicator())
                  : state.contacts.isEmpty
                  ? Center(
                      child: Text(
                        'No people found',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF777177),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.contacts.length,
                      itemBuilder: (context, index) {
                        final contact = state.contacts[index];

                        return _buildContact(contact);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContact(Map<String, dynamic> contact) {
    final name = contact['fullName']?.toString() ?? 'Employee';

    final employeeId = contact['employeeId']?.toString() ?? '';

    final designation = contact['designation']?.toString() ?? '';

    final role = contact['role']?.toString() ?? '';

    final trimmedName = name.trim();

    final first = trimmedName.isEmpty
        ? '?'
        : trimmedName.characters.first.toUpperCase();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => widget.onSelected(contact),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryFillColor.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: Text(
                first,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryFillColor,
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textColor,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    [
                      if (employeeId.isNotEmpty) employeeId,
                      if (designation.isNotEmpty) designation,
                      if (designation.isEmpty && role.isNotEmpty) role,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF777177),
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.mutedColor,
            ),
          ],
        ),
      ),
    );
  }
}
