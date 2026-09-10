import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
  ConsumerState<ChatDetailScreen> createState() =>
      _ChatDetailScreenState();
}

class _ChatDetailScreenState
    extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  final ImagePicker _imagePicker =
      ImagePicker();

  final AudioRecorder _audioRecorder =
      AudioRecorder();

  bool _isRecording = false;

  static const String _fileBaseUrl =
      'https://workforce.orkuts.com';

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(
      _handleScroll,
    );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) return;

        ref
            .read(chatProvider.notifier)
            .loadMessages(
              widget.conversationId,
            );
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // ==============================================================
  // SCROLL
  // ==============================================================

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    if (_scrollController.position.pixels <= 100) {
      ref
          .read(chatProvider.notifier)
          .loadOlderMessages(
            widget.conversationId,
          );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted ||
            !_scrollController.hasClients) {
          return;
        }

        _scrollController.animateTo(
          0,
          duration:
              const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      },
    );
  }

  Future<void> _refresh() async {
    await ref
        .read(chatProvider.notifier)
        .loadMessages(
          widget.conversationId,
          refresh: true,
        );
  }

  // ==============================================================
  // SEND TEXT
  // ==============================================================

  Future<void> _send() async {
    final text =
        _messageController.text.trim();

    if (text.isEmpty) {
      return;
    }

    _messageController.clear();

    final message = await ref
        .read(chatProvider.notifier)
        .sendMessage(
          conversationId:
              widget.conversationId,
          body: text,
        );

    if (!mounted || message == null) {
      return;
    }

    _scrollToBottom();
  }

  // ==============================================================
  // IMAGE
  // ==============================================================

  Future<void> _pickImage() async {
    try {
      final image =
          await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        return;
      }

      final file =
          await _makePersistentFile(
        File(image.path),
        prefix: 'image',
        extension: _extension(image.path),
      );

      if (!mounted) return;

      await ref
          .read(chatProvider.notifier)
          .sendAttachment(
            conversationId:
                widget.conversationId,
            file: file,
            type: 'image',
          );

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        _cleanError(e),
      );
    }
  }

  // ==============================================================
  // VOICE
  // ==============================================================

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      final permission =
          await _audioRecorder.hasPermission();

      if (!permission) {
        if (!mounted) return;

        _showMessage(
          'Microphone permission is required.',
        );

        return;
      }

      final file =
          await _createRecordingFile();

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: file.path,
      );

      if (!mounted) return;

      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        _cleanError(e),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) {
      return;
    }

    try {
      final path =
          await _audioRecorder.stop();

      if (!mounted) return;

      setState(() {
        _isRecording = false;
      });

      if (path == null || path.isEmpty) {
        return;
      }

      final file = File(path);

      if (!await file.exists()) {
        return;
      }

      await ref
          .read(chatProvider.notifier)
          .sendAttachment(
            conversationId:
                widget.conversationId,
            file: file,
            type: 'voice',
          );

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isRecording = false;
      });

      _showMessage(
        _cleanError(e),
      );
    }
  }

  Future<File> _createRecordingFile() async {
    final directory =
        await getApplicationDocumentsDirectory();

    final folder = Directory(
      '${directory.path}${Platform.pathSeparator}'
      'chat_media${Platform.pathSeparator}'
      '${widget.conversationId}',
    );

    await folder.create(
      recursive: true,
    );

    return File(
      '${folder.path}${Platform.pathSeparator}'
      'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
  }

  Future<File> _makePersistentFile(
    File source, {
    required String prefix,
    required String extension,
  }) async {
    final directory =
        await getApplicationDocumentsDirectory();

    final folder = Directory(
      '${directory.path}${Platform.pathSeparator}'
      'chat_media${Platform.pathSeparator}'
      '${widget.conversationId}',
    );

    await folder.create(
      recursive: true,
    );

    final destination = File(
      '${folder.path}${Platform.pathSeparator}'
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}$extension',
    );

    return source.copy(
      destination.path,
    );
  }

  String _extension(String path) {
    final index = path.lastIndexOf('.');

    if (index == -1) {
      return '';
    }

    return path.substring(index);
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);

    final thread = state.threads[
            widget.conversationId] ??
        const ChatThreadState();

    return Scaffold(
      backgroundColor:
          AppColors.whiteBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textColor,
          ),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight:
                    FontWeight.w700,
                color:
                    AppColors.textColor,
              ),
            ),
            Text(
              'Chat',
              style: GoogleFonts.inter(
                fontSize: 11,
                color:
                    AppColors.mutedColor,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color:
                  AppColors.primaryFillColor,
              onRefresh: _refresh,
              child:
                  thread.isLoading &&
                          thread.messages.isEmpty
                      ? const Center(
                          child:
                              CircularProgressIndicator(),
                        )
                      : _buildMessages(
                          thread,
                        ),
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  // ==============================================================
  // MESSAGES
  // ==============================================================

  Widget _buildMessages(
    ChatThreadState thread,
  ) {
    if (thread.messages.isEmpty) {
      return ListView(
        reverse: true,
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 180),
          _buildEmptyState(),
        ],
      );
    }

    final items =
        <_MessageListItem>[];

    String? lastDate;

    for (final message
        in thread.messages) {
      final date =
          DateTime.tryParse(
        message['createdAt']
                ?.toString() ??
            '',
      );

      final key =
          date == null
              ? ''
              : _dateKey(date);

      if (key != lastDate) {
        items.add(
          _MessageListItem.date(
            date,
          ),
        );

        lastDate = key;
      }

      items.add(
        _MessageListItem.message(
          message,
        ),
      );
    }

    return ListView.builder(
      reverse: true,
      controller:
          _scrollController,
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        12,
      ),
      itemCount: items.length,
      itemBuilder:
          (context, index) {
        final item =
            items[
                items.length -
                    1 -
                    index];

        if (item.isDate) {
          return _buildDateDivider(
            item.date!,
          );
        }

        return _buildMessageBubble(
          item.message!,
        );
      },
    );
  }

  // ==============================================================
  // DATE
  // ==============================================================

  Widget _buildDateDivider(
    DateTime date,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 14,
      ),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 6,
          ),
          decoration:
              BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            border: Border.all(
              color:
                  AppColors.borderColor,
            ),
          ),
          child: Text(
            _formatDate(date),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight:
                  FontWeight.w600,
              color:
                  AppColors.mutedColor,
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // MESSAGE
  // ==============================================================

 Widget _buildMessageBubble(
  Map<String, dynamic> message,
) {
  final mine = message['mine'] == true;

  final type = _messageType(message);

  final pending = message['pending'] == true;
  final failed = message['failed'] == true;

  Widget content;

  switch (type) {
    case 'image':
      content = _buildImageMessage(
        message,
        mine,
      );
      break;

    case 'voice':
      content = _buildVoiceMessage(
        message,
        mine,
      );
      break;

    default:
      content = _buildTextMessage(
        message,
        mine,
      );
  }

  return Padding(
    padding: const EdgeInsets.only(
      bottom: 8,
    ),
    child: Row(
      mainAxisAlignment: mine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment:
          CrossAxisAlignment.end,
      children: [
        if (mine && failed)
          Padding(
            padding: const EdgeInsets.only(
              right: 6,
            ),
            child: GestureDetector(
              onTap: () => _retryMessage(
                message,
              ),
              child: const Icon(
                Icons.refresh_rounded,
                size: 20,
                color: Colors.redAccent,
              ),
            ),
          ),

        // IMPORTANT:
        // Constrain the bubble, but DON'T force
        // it to take the full width.
        Flexible(
          child: GestureDetector(
            onTap: failed
                ? () => _retryMessage(message)
                : null,
            onLongPress: mine
                ? () => _showDeleteDialog(
                      message,
                    )
                : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width *
                        0.72,
              ),
              child: content,
            ),
          ),
        ),
      ],
    ),
  );
}
  // ==============================================================
  // TEXT
  // ==============================================================

  Widget _buildTextMessage(
  Map<String, dynamic> message,
  bool mine,
) {
  final pending =
      message['pending'] == true;

  final failed =
      message['failed'] == true;

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 13,
      vertical: 9,
    ),
    decoration: BoxDecoration(
      color: mine
          ? AppColors.primaryFillColor
          : Colors.white,
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: Radius.circular(
          mine ? 16 : 4,
        ),
        bottomRight: Radius.circular(
          mine ? 4 : 16,
        ),
      ),
      border: mine
          ? null
          : Border.all(
              color: AppColors.borderColor,
            ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          CrossAxisAlignment.end,
      children: [
        Text(
          message['body']?.toString() ?? '',
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.35,
            color: mine
                ? Colors.white
                : AppColors.textColor,
          ),
        ),

        const SizedBox(height: 4),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _messageTime(message),
              style: GoogleFonts.inter(
                fontSize: 9,
                color: mine
                    ? Colors.white.withValues(
                        alpha: .70,
                      )
                    : AppColors.mutedColor,
              ),
            ),

            if (mine) ...[
              const SizedBox(width: 4),

              _buildStatusIcon(
                pending: pending,
                failed: failed,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ],
    ),
  );
}
  // ==============================================================
  // IMAGE
  // ==============================================================

  Widget _buildImageMessage(
  Map<String, dynamic> message,
  bool mine,
) {
  final localPath = _localPath(message);
  final url = _attachmentUrl(message);

  final pending = message['pending'] == true;
  final failed = message['failed'] == true;

  return Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: mine
          ? AppColors.primaryFillColor
          : Colors.white,
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: Radius.circular(
          mine ? 16 : 4,
        ),
        bottomRight: Radius.circular(
          mine ? 4 : 16,
        ),
      ),
      border: mine
          ? null
          : Border.all(
              color: AppColors.borderColor,
            ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: pending
              ? null
              : () => _showImageViewer(
                    localPath,
                    url,
                  ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildImage(
              localPath,
              url,
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(
            right: 4,
            top: 4,
            bottom: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _messageTime(message),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: mine
                      ? Colors.white.withValues(alpha: .70)
                      : AppColors.mutedColor,
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 4),
                _buildStatusIcon(
                  pending: pending,
                  failed: failed,
                  color: Colors.white,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildImage(
    String localPath,
    String url,
  ) {
    if (localPath.isNotEmpty &&
        File(localPath).existsSync()) {
      return Image.file(
        File(localPath),
        width: 240,
        height: 190,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) =>
                _imageError(),
      );
    }

    if (url.isNotEmpty) {
      return Image.network(
        url,
        width: 240,
        height: 190,
        fit: BoxFit.cover,
        loadingBuilder:
            (
          context,
          child,
          progress,
        ) {
          if (progress == null) {
            return child;
          }

          return SizedBox(
            width: 240,
            height: 190,
            child: Center(
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors
                    .primaryFillColor,
              ),
            ),
          );
        },
        errorBuilder:
            (_, __, ___) =>
                _imageError(),
      );
    }

    return _imageError();
  }

  Widget _imageError() {
    return Container(
      width: 240,
      height: 190,
      color: const Color(
        0xFFF4F1F3,
      ),
      alignment:
          Alignment.center,
      child: Icon(
        Icons
            .image_not_supported_outlined,
        size: 38,
        color:
            AppColors.mutedColor,
      ),
    );
  }

  // ==============================================================
  // VOICE
  // ==============================================================

 Widget _buildVoiceMessage(
  Map<String, dynamic> message,
  bool mine,
) {
  final localPath = _localPath(message);
  final url = _attachmentUrl(message);

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 9,
    ),
    decoration: BoxDecoration(
      color: mine
          ? AppColors.primaryFillColor
          : Colors.white,
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: Radius.circular(
          mine ? 16 : 4,
        ),
        bottomRight: Radius.circular(
          mine ? 4 : 16,
        ),
      ),
      border: mine
          ? null
          : Border.all(
              color: AppColors.borderColor,
            ),
    ),
    child: _VoicePlayer(
      key: ValueKey(
        message['id']?.toString(),
      ),
      localPath: localPath,
      url: url,
      mine: mine,
      time: _messageTime(message),
      pending: message['pending'] == true,
      failed: message['failed'] == true,
    ),
  );
}
  // ==============================================================
  // COMPOSER
  // ==============================================================

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          12,
          8,
          12,
          10,
        ),
        color: Colors.white,
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration:
                  const BoxDecoration(
                color:
                    Color(0xFFF8F4F6),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed:
                    _pickImage,
                padding:
                    EdgeInsets.zero,
                icon: Icon(
                  Icons
                      .attach_file_rounded,
                  size: 21,
                  color: AppColors
                      .primaryFillColor,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Container(
                constraints:
                    const BoxConstraints(
                  minHeight: 44,
                  maxHeight: 120,
                ),
                decoration:
                    BoxDecoration(
                  color: const Color(
                    0xFFF8F4F6,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    22,
                  ),
                ),
                child: TextField(
                  controller:
                      _messageController,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization:
                      TextCapitalization
                          .sentences,
                  style:
                      GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors
                        .textColor,
                  ),
                  decoration:
                      InputDecoration(
                    border:
                        InputBorder.none,
                    hintText:
                        'Type a message...',
                    hintStyle:
                        GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors
                          .mutedColor,
                    ),
                    contentPadding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                  ),
                  onSubmitted: (_) {
                    _send();
                  },
                ),
              ),
            ),
            const SizedBox(width: 7),
            Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(
                color: _isRecording
                    ? Colors.redAccent
                    : const Color(
                        0xFFF8F4F6,
                      ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed:
                    _toggleRecording,
                padding:
                    EdgeInsets.zero,
                icon: Icon(
                  _isRecording
                      ? Icons.stop_rounded
                      : Icons
                          .mic_none_rounded,
                  size: 21,
                  color: _isRecording
                      ? Colors.white
                      : AppColors
                          .primaryFillColor,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Container(
              width: 42,
              height: 42,
              decoration:
                  const BoxDecoration(
                color: AppColors
                    .primaryFillColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _send,
                padding:
                    EdgeInsets.zero,
                icon: const Icon(
                  Icons
                      .arrow_upward_rounded,
                  size: 21,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // STATUS
  // ==============================================================

  Widget _buildStatusIcon({
    required bool pending,
    required bool failed,
    required Color color,
  }) {
    if (failed) {
      return const Icon(
        Icons.error_outline_rounded,
        size: 13,
        color: Colors.redAccent,
      );
    }

    if (pending) {
      return SizedBox(
        width: 11,
        height: 11,
        child:
            CircularProgressIndicator(
          strokeWidth: 1.5,
          color: color,
        ),
      );
    }

    return Icon(
      Icons.done_all_rounded,
      size: 13,
      color: color,
    );
  }

  // ==============================================================
  // RETRY
  // ==============================================================

  Future<void> _retryMessage(
    Map<String, dynamic> message,
  ) async {
    final id =
        message['id']?.toString();

    if (id == null ||
        !id.startsWith('local_')) {
      return;
    }

    final type =
        _messageType(message);

    if (type == 'image' ||
        type == 'voice') {
      await ref
          .read(chatProvider.notifier)
          .retryAttachment(
            conversationId:
                widget.conversationId,
            localId: id,
          );
    } else {
      await ref
          .read(chatProvider.notifier)
          .retryMessage(
            conversationId:
                widget.conversationId,
            localId: id,
          );
    }
  }

  // ==============================================================
  // DELETE
  // ==============================================================

  Future<void> _showDeleteDialog(
    Map<String, dynamic> message,
  ) async {
    final result =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsets.all(
              20,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete message',
                  style:
                      GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w700,
                    color: AppColors
                        .textColor,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  'This message will disappear for everyone in this chat. This cannot be undone.',
                  style:
                      GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors
                        .mutedColor,
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop(false);
                      },
                      child: Text(
                        'Cancel',
                        style:
                            GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w600,
                          color: AppColors
                              .mutedColor,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop(true);
                      },
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            AppColors
                                .primaryFillColor,
                        foregroundColor:
                            Colors.white,
                        elevation: 0,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                        ),
                      ),
                      child: Text(
                        'Delete',
                        style:
                            GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != true ||
        !mounted) {
      return;
    }

    final id =
        message['id']?.toString() ?? '';

    if (id.startsWith('local_')) {
      await ref
          .read(chatProvider.notifier)
          .removeLocalMessage(
            conversationId:
                widget.conversationId,
            localId: id,
          );

      return;
    }

    final messageId =
        int.tryParse(id);

    if (messageId == null) {
      return;
    }

    await ref
        .read(chatProvider.notifier)
        .deleteMessage(
          conversationId:
              widget.conversationId,
          messageId: messageId,
        );
  }

  // ==============================================================
  // IMAGE VIEWER
  // ==============================================================

  void _showImageViewer(
    String localPath,
    String url,
  ) {
    if (localPath.isEmpty &&
        url.isEmpty) {
      return;
    }

    showDialog(
      context: context,
      barrierColor:
          Colors.black87,
      builder: (_) {
        Widget image;

        if (localPath.isNotEmpty &&
            File(localPath).existsSync()) {
          image = Image.file(
            File(localPath),
            fit: BoxFit.contain,
          );
        } else {
          image = Image.network(
            url,
            fit: BoxFit.contain,
          );
        }

        return GestureDetector(
          onTap: () {
            Navigator.of(context)
                .pop();
          },
          child: Center(
            child: InteractiveViewer(
              child: image,
            ),
          ),
        );
      },
    );
  }

  // ==============================================================
  // ATTACHMENT RESOLUTION
  // ==============================================================

  String _attachmentUrl(
    Map<String, dynamic> message,
  ) {
    final candidates = <dynamic>[
      message['attachmentUrl'],
      message['fileUrl'],
      message['imageUrl'],
      message['audioUrl'],
      message['mediaUrl'],
      message['url'],
      message['filePath'],
      message['path'],
      message['attachment'],
      message['file'],
      message['media'],
    ];

    for (final candidate in candidates) {
      final result =
          _findUrl(candidate);

      if (result.isNotEmpty) {
        return _resolveUrl(result);
      }
    }

    return '';
  }

  String _findUrl(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is String) {
      final text = value.trim();

      if (_looksLikeAttachment(text)) {
        return text;
      }

      return '';
    }

    if (value is Map) {
      final map =
          Map<String, dynamic>.from(
        value,
      );

      final keys = [
        'url',
        'secureUrl',
        'fileUrl',
        'downloadUrl',
        'attachmentUrl',
        'imageUrl',
        'audioUrl',
        'mediaUrl',
        'path',
        'filePath',
        'src',
      ];

      for (final key in keys) {
        final result =
            _findUrl(map[key]);

        if (result.isNotEmpty) {
          return result;
        }
      }

      // Some APIs nest the attachment.
      for (final value in map.values) {
        final result =
            _findUrl(value);

        if (result.isNotEmpty) {
          return result;
        }
      }
    }

    return '';
  }

  String _resolveUrl(String value) {
    if (value.startsWith('http://') ||
        value.startsWith('https://')) {
      return value;
    }

    if (value.startsWith('//')) {
      return 'https:$value';
    }

    if (value.startsWith('/')) {
      return '$_fileBaseUrl$value';
    }

    return '$_fileBaseUrl/$value';
  }

  bool _looksLikeAttachment(
    String value,
  ) {
    final lower =
        value.toLowerCase();

    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.webm') ||
        lower.contains('/uploads/') ||
        lower.contains('/attachments/') ||
        lower.contains('/media/');
  }

  String _localPath(
    Map<String, dynamic> message,
  ) {
    final candidates = [
      message['localPath'],
      message['filePath'],
      message['attachmentPath'],
      message['audioPath'],
      message['imagePath'],
    ];

    for (final candidate
        in candidates) {
      final value =
          candidate?.toString().trim() ??
              '';

      if (value.isNotEmpty) {
        return value;
      }
    }

    final attachment =
        message['attachment'];

    if (attachment is Map) {
      final path =
          attachment['localPath']
                  ?.toString() ??
              '';

      if (path.isNotEmpty) {
        return path;
      }
    }

    return '';
  }

  // ==============================================================
  // TYPE
  // ==============================================================

  String _messageType(
    Map<String, dynamic> message,
  ) {
    final values = [
      message['type'],
      message['messageType'],
      message['attachmentType'],
      message['mediaType'],
    ];

    for (final value in values) {
      final type =
          value?.toString()
              .trim()
              .toLowerCase();

      if (type == 'image') {
        return 'image';
      }

      if (type == 'voice' ||
          type == 'audio') {
        return 'voice';
      }

      if (type == 'text') {
        return 'text';
      }
    }

    final mimeValues = [
      message['mimeType'],
      message['contentType'],
      message['attachmentMimeType'],
    ];

    for (final value in mimeValues) {
      final mime =
          value?.toString()
              .toLowerCase() ??
          '';

      if (mime.startsWith('image/')) {
        return 'image';
      }

      if (mime.startsWith('audio/')) {
        return 'voice';
      }
    }

    final attachment =
        message['attachment'];

    if (attachment is Map) {
      final mime =
          attachment['mimeType']
                  ?.toString()
                  .toLowerCase() ??
              '';

      if (mime.startsWith('image/')) {
        return 'image';
      }

      if (mime.startsWith('audio/')) {
        return 'voice';
      }
    }

    final url =
        _attachmentUrl(message)
            .toLowerCase();

    if (_isImageUrl(url)) {
      return 'image';
    }

    if (_isAudioUrl(url)) {
      return 'voice';
    }

    final local =
        _localPath(message)
            .toLowerCase();

    if (_isImageUrl(local)) {
      return 'image';
    }

    if (_isAudioUrl(local)) {
      return 'voice';
    }

    return 'text';
  }

  bool _isImageUrl(String value) {
    return value.endsWith('.jpg') ||
        value.endsWith('.jpeg') ||
        value.endsWith('.png') ||
        value.endsWith('.webp') ||
        value.endsWith('.gif');
  }

  bool _isAudioUrl(String value) {
    return value.endsWith('.m4a') ||
        value.endsWith('.mp3') ||
        value.endsWith('.wav') ||
        value.endsWith('.aac') ||
        value.endsWith('.ogg') ||
        value.endsWith('.webm');
  }

  // ==============================================================
  // TIME
  // ==============================================================

  String _messageTime(
    Map<String, dynamic> message,
  ) {
    final date =
        DateTime.tryParse(
      message['createdAt']
              ?.toString() ??
          '',
    );

    if (date == null) {
      return '';
    }

    return _formatTime(date);
  }

  String _formatTime(
    DateTime date,
  ) {
    final local = date.toLocal();

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
            ? local.hour - 12
            : local.hour;

    final minute =
        local.minute
            .toString()
            .padLeft(2, '0');

    final period =
        local.hour >= 12
            ? 'PM'
            : 'AM';

    return '$hour:$minute $period';
  }

  String _dateKey(
    DateTime date,
  ) {
    final local = date.toLocal();

    return '${local.year}-'
        '${local.month}-'
        '${local.day}';
  }

  String _formatDate(
    DateTime date,
  ) {
    final local =
        date.toLocal();

    final now =
        DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final messageDay = DateTime(
      local.year,
      local.month,
      local.day,
    );

    final difference =
        today
            .difference(messageDay)
            .inDays;

    if (difference == 0) {
      return 'Today';
    }

    if (difference == 1) {
      return 'Yesterday';
    }

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 12,
            ),
          ),
        ),
      );
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration:
              BoxDecoration(
            color: AppColors
                .primaryFillColor
                .withValues(alpha: .10),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons
                .chat_bubble_outline_rounded,
            color:
                AppColors.primaryFillColor,
            size: 28,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Say hello',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight:
                FontWeight.w700,
            color:
                AppColors.textColor,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'No messages here yet — send the first one.',
          textAlign:
              TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color:
                AppColors.mutedColor,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// Message list item
// ================================================================

class _MessageListItem {
  final Map<String, dynamic>? message;
  final DateTime? date;

  const _MessageListItem.message(
    this.message,
  ) : date = null;

  const _MessageListItem.date(
    this.date,
  ) : message = null;

  bool get isDate =>
      message == null;
}

// ================================================================
// Voice Player
// ================================================================

class _VoicePlayer
    extends StatefulWidget {
  final String localPath;
  final String url;
  final bool mine;
  final String time;
  final bool pending;
  final bool failed;

  const _VoicePlayer({
    super.key,
    required this.localPath,
    required this.url,
    required this.mine,
    required this.time,
    required this.pending,
    required this.failed,
  });

  @override
  State<_VoicePlayer> createState() =>
      _VoicePlayerState();
}

class _VoicePlayerState
    extends State<_VoicePlayer> {
  final AudioPlayer _player =
      AudioPlayer();

  bool _loading = false;
  bool _loaded = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    if (widget.pending ||
        widget.failed) {
      return;
    }

    if (widget.localPath.isEmpty &&
        widget.url.isEmpty) {
      return;
    }

    try {
      if (_player.playing) {
        await _player.pause();
        return;
      }

      if (_player.processingState ==
          ProcessingState.completed) {
        await _player.seek(
          Duration.zero,
        );
      }

      if (!_loaded) {
        setState(() {
          _loading = true;
        });

        if (widget.localPath.isNotEmpty &&
            File(widget.localPath)
                .existsSync()) {
          await _player.setFilePath(
            widget.localPath,
          );
        } else if (widget.url.isNotEmpty) {
          await _player.setUrl(
            widget.url,
          );
        } else {
          if (mounted) {
            setState(() {
              _loading = false;
            });
          }

          return;
        }

        _loaded = true;

        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      }

      await _player.play();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Audio could not be played.',
              style:
                  GoogleFonts.inter(
                fontSize: 12,
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final foreground =
        widget.mine
            ? Colors.white
            : AppColors.textColor;

    return Row(
      children: [
        GestureDetector(
          onTap: _playPause,
          child: Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(
              color: widget.mine
                  ? Colors.white
                      .withValues(
                      alpha: .15,
                    )
                  : AppColors
                      .primaryFillColor
                      .withValues(
                      alpha: .10,
                    ),
              shape: BoxShape.circle,
            ),
            child:
                StreamBuilder<
                    PlayerState>(
              stream:
                  _player
                      .playerStateStream,
              builder:
                  (context, snapshot) {
                if (_loading) {
                  return Padding(
                    padding:
                        const EdgeInsets
                            .all(12),
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color:
                          foreground,
                    ),
                  );
                }

                final playing =
                    snapshot.data
                            ?.playing ==
                        true;

                return Icon(
                  playing
                      ? Icons
                          .pause_rounded
                      : Icons
                          .play_arrow_rounded,
                  size: 25,
                  color: foreground,
                );
              },
            ),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              StreamBuilder<
                  Duration?>(
                stream:
                    _player
                        .durationStream,
                builder:
                    (context, durationSnapshot) {
                  final duration =
                      durationSnapshot
                              .data ??
                          Duration.zero;

                  return StreamBuilder<
                      Duration>(
                    stream: _player
                        .positionStream,
                    builder:
                        (
                      context,
                      positionSnapshot,
                    ) {
                      final position =
                          positionSnapshot
                                  .data ??
                              Duration.zero;

                      final total =
                          duration
                              .inMilliseconds
                              .toDouble();

                      final current =
                          position
                              .inMilliseconds
                              .toDouble();

                      final progress =
                          total <= 0
                              ? 0.0
                              : (current /
                                      total)
                                  .clamp(
                                  0.0,
                                  1.0,
                                );

                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              5,
                            ),
                            child:
                                LinearProgressIndicator(
                              value:
                                  progress,
                              minHeight: 4,
                              backgroundColor:
                                  foreground
                                      .withValues(
                                alpha: .20,
                              ),
                              color:
                                  foreground
                                      .withValues(
                                alpha: .75,
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Row(
                            children: [
                              Text(
                                _durationText(
                                  position,
                                ),
                                style:
                                    GoogleFonts.inter(
                                  fontSize:
                                      9,
                                  color:
                                      foreground.withValues(
                                    alpha:
                                        .70,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                widget.time,
                                style:
                                    GoogleFonts.inter(
                                  fontSize:
                                      9,
                                  color:
                                      foreground.withValues(
                                    alpha:
                                        .70,
                                  ),
                                ),
                              ),
                              if (widget.mine) ...[
                                const SizedBox(
                                  width: 4,
                                ),
                                if (widget.failed)
                                  const Icon(
                                    Icons
                                        .error_outline_rounded,
                                    size:
                                        13,
                                    color:
                                        Colors.redAccent,
                                  )
                                else if (widget.pending)
                                  SizedBox(
                                    width:
                                        10,
                                    height:
                                        10,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          1.4,
                                      color:
                                          foreground,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons
                                        .done_all_rounded,
                                    size:
                                        13,
                                    color:
                                        foreground,
                                  ),
                              ],
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _durationText(
    Duration duration,
  ) {
    final minutes =
        duration.inMinutes
            .toString()
            .padLeft(2, '0');

    final seconds =
        (duration.inSeconds % 60)
            .toString()
            .padLeft(2, '0');

    return '$minutes:$seconds';
  }
}