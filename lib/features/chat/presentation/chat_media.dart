import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/network/network_providers.dart';
import 'package:workforce/core/network/stored_file.dart';
import 'package:workforce/core/styles/app_colors.dart';

/// Chat attachments (photos, videos, voice notes, documents) are served by
/// the signed-in `GET /api/files/chat/<user>/<file>` endpoint, which only
/// answers people in the conversation. Everything here reads them with the
/// bearer token, as the web's StoredImage / StoredVideo do.

/// Absolute URL of a stored chat attachment, for players that stream
/// (video_player, just_audio) and so need a URL plus headers.
String chatFileUrl(WidgetRef ref, String path) {
  final base = ref
      .read(apiClientProvider)
      .dio
      .options
      .baseUrl
      .replaceFirst(RegExp(r'/+$'), '');

  return '$base${storedFileEndpoint(path)}';
}

Future<Map<String, String>> chatAuthHeaders(WidgetRef ref) async {
  final token = await ref.read(secureStorageProvider).getToken();

  if (token == null || token.isEmpty) return const {};

  return {'Authorization': 'Bearer $token'};
}

/// `12.3 MB` / `850 KB`, or null when the size is unknown.
String? chatFileSizeLabel(dynamic size) {
  final bytes = size is num ? size : num.tryParse(size?.toString() ?? '');

  if (bytes == null || bytes <= 0) return null;

  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';

  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Saves an attachment to the phone's Download folder and says where.
Future<void> downloadChatAttachment(
  BuildContext context,
  WidgetRef ref, {
  required String path,
  String? name,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final savedText = ref.tr('chatx.savedTo');
  final failedText = ref.tr('chatx.couldNotDownload');

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(ref.tr('chatx.downloading'))));

  try {
    final fileName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : path.split('/').last;

    final savedPath = await saveStoredFile(
      ref.read(apiClientProvider),
      path: path,
      fileName: fileName,
    );

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(savedText.replaceAll('{path}', savedPath))),
      );
  } catch (e) {
    final message = cleanErrorMessage(e);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message == 'Something went wrong.' ? failedText : message,
          ),
        ),
      );
  }
}

// ============================================================================
// PHOTO VIEWER
// ============================================================================

/// A photo opened from the thread: full screen, pinch to zoom, with a way to
/// save it.
class ChatImageViewerScreen extends ConsumerWidget {
  final String localPath;
  final String? storedPath;
  final String? name;

  const ChatImageViewerScreen({
    super.key,
    this.localPath = '',
    this.storedPath,
    this.name,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget image;

    if (localPath.isNotEmpty && File(localPath).existsSync()) {
      image = Image.file(File(localPath), fit: BoxFit.contain);
    } else if (storedPath != null && storedPath!.isNotEmpty) {
      image = StoredFileImage(
        path: storedPath!,
        fit: BoxFit.contain,
        fallback: const Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 48,
        ),
      );
    } else {
      image = const Icon(
        Icons.broken_image_outlined,
        color: Colors.white54,
        size: 48,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          name ?? ref.tr('chatx.photo'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 15, color: Colors.white),
        ),
        actions: [
          if (storedPath != null && storedPath!.isNotEmpty)
            IconButton(
              tooltip: ref.tr('chatx.download'),
              icon: const Icon(Icons.download_rounded),
              onPressed: () => downloadChatAttachment(
                context,
                ref,
                path: storedPath!,
                name: name,
              ),
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: SizedBox.expand(child: Center(child: image)),
        ),
      ),
    );
  }
}

// ============================================================================
// VIDEO PLAYER
// ============================================================================

/// Plays one chat video full screen. Nothing is fetched until it is opened;
/// the server answers byte ranges, so the player streams and seeks.
class ChatVideoPlayerScreen extends ConsumerStatefulWidget {
  final String localPath;
  final String? storedPath;
  final String? name;

  const ChatVideoPlayerScreen({
    super.key,
    this.localPath = '',
    this.storedPath,
    this.name,
  });

  @override
  ConsumerState<ChatVideoPlayerScreen> createState() =>
      _ChatVideoPlayerScreenState();
}

class _ChatVideoPlayerScreenState extends ConsumerState<ChatVideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final VideoPlayerController controller;

      if (widget.localPath.isNotEmpty && File(widget.localPath).existsSync()) {
        controller = VideoPlayerController.file(File(widget.localPath));
      } else if (widget.storedPath != null && widget.storedPath!.isNotEmpty) {
        controller = await _streamOrDownload(widget.storedPath!);
      } else {
        throw Exception('No video');
      }

      if (!controller.value.isInitialized) await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      controller.addListener(_onTick);

      setState(() => _controller = controller);

      await controller.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Streams with the bearer header. If the native player cannot (Android
  /// refuses plain-http streams unless cleartext is allowed, as on a dev
  /// server), the file is fetched through the API client and played locally.
  Future<VideoPlayerController> _streamOrDownload(String path) async {
    final streaming = VideoPlayerController.networkUrl(
      Uri.parse(chatFileUrl(ref, path)),
      httpHeaders: await chatAuthHeaders(ref),
    );

    try {
      await streaming.initialize();
      return streaming;
    } catch (_) {
      await streaming.dispose();
    }

    final bytes = await fetchStoredFile(ref.read(apiClientProvider), path);
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'chat_video_${path.hashCode.abs()}.${path.split('.').last}',
    );

    await file.writeAsBytes(bytes, flush: true);

    return VideoPlayerController.file(file);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  String _time(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');

    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final storedPath = widget.storedPath;

    Widget body;

    if (_failed) {
      body = Text(
        ref.tr('chatx.couldNotLoadVideo'),
        style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
      );
    } else if (controller == null || !controller.value.isInitialized) {
      body = const CircularProgressIndicator(color: Colors.white);
    } else {
      final value = controller.value;

      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: GestureDetector(
              onTap: () =>
                  value.isPlaying ? controller.pause() : controller.play(),
              child: AspectRatio(
                aspectRatio: value.aspectRatio <= 0 ? 16 / 9 : value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(controller),
                    if (!value.isPlaying)
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () =>
                      value.isPlaying ? controller.pause() : controller.play(),
                  icon: Icon(
                    value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: AppColors.primaryFillColor,
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_time(value.position)} / ${_time(value.duration)}',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.name ?? ref.tr('chatx.video'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 15, color: Colors.white),
        ),
        actions: [
          if (storedPath != null && storedPath.isNotEmpty)
            IconButton(
              tooltip: ref.tr('chatx.download'),
              icon: const Icon(Icons.download_rounded),
              onPressed: () => downloadChatAttachment(
                context,
                ref,
                path: storedPath,
                name: widget.name,
              ),
            ),
        ],
      ),
      body: SafeArea(child: Center(child: body)),
    );
  }
}

// ============================================================================
// BUBBLE TILES
// ============================================================================

/// A video in the thread: a dark tile with a play button, its size, and a
/// download button. Tapping opens [ChatVideoPlayerScreen].
class ChatVideoTile extends ConsumerWidget {
  final String localPath;
  final String? storedPath;
  final String? name;
  final dynamic size;
  final bool mine;
  final bool pending;

  const ChatVideoTile({
    super.key,
    required this.localPath,
    required this.storedPath,
    required this.name,
    required this.size,
    required this.mine,
    required this.pending,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSource = localPath.isNotEmpty ||
        (storedPath != null && storedPath!.isNotEmpty);
    final label = [ref.tr('chatx.video'), chatFileSizeLabel(size)]
        .whereType<String>()
        .join(' · ');

    return GestureDetector(
      onTap: !hasSource
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatVideoPlayerScreen(
                    localPath: localPath,
                    storedPath: storedPath,
                    name: name,
                  ),
                ),
              ),
      child: Container(
        width: 240,
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  pending ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 44,
              bottom: 10,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
              ),
            ),
            if (storedPath != null && storedPath!.isNotEmpty)
              Positioned(
                right: 2,
                bottom: 0,
                child: IconButton(
                  tooltip: ref.tr('chatx.download'),
                  icon: const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => downloadChatAttachment(
                    context,
                    ref,
                    path: storedPath!,
                    name: name,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A document in the thread: its name and size; tapping saves it.
class ChatDocumentTile extends ConsumerWidget {
  final String? storedPath;
  final String? name;
  final dynamic size;
  final bool mine;

  const ChatDocumentTile({
    super.key,
    required this.storedPath,
    required this.name,
    required this.size,
    required this.mine,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foreground = mine ? Colors.white : AppColors.textColor;
    final canDownload = storedPath != null && storedPath!.isNotEmpty;
    final detail = [ref.tr('chatx.document'), chatFileSizeLabel(size)]
        .whereType<String>()
        .join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: canDownload
          ? () => downloadChatAttachment(
                context,
                ref,
                path: storedPath!,
                name: name,
              )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: mine
                    ? Colors.white.withValues(alpha: .18)
                    : AppColors.primaryFillColor.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.insert_drive_file_outlined,
                color: foreground,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (name == null || name!.isEmpty)
                        ? ref.tr('chatx.document')
                        : name!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: foreground.withValues(alpha: .7),
                    ),
                  ),
                ],
              ),
            ),
            if (canDownload) ...[
              const SizedBox(width: 6),
              Icon(Icons.download_rounded, color: foreground, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
