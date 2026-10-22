import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/network/network_providers.dart';
import 'package:workforce/core/network/stored_file.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/styles/tricolour_strip.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';

import '../data/notification_repository.dart';
import '../providers/notification_provider.dart';

/// The notification feed, as the web employee screen shows it: grouped into
/// today and earlier, opening an unread item marks it read, messages from
/// people show their photo / voice note and can be replied to with text or a
/// voice note (POST /notifications/:id/reply). A filter row narrows the feed
/// to unread items or one category.
class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

/// `all`, `unread`, or a category name.
const String _filterAll = 'all';
const String _filterUnread = 'unread';

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  bool _markingAllAsRead = false;
  String _filter = _filterAll;
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(notificationProvider.notifier).fetchNotifications();
    });
  }

  Future<void> _markAll() async {
    setState(() => _markingAllAsRead = true);

    final success =
        await ref.read(notificationProvider.notifier).markAllAsRead();

    if (!mounted) return;

    setState(() => _markingAllAsRead = false);

    showFeatureSnack(
      context,
      success
          ? ref.tr('notifx.allMarked')
          : (ref.read(notificationProvider).message ??
              ref.tr('notification.loadError')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.appBarColor,
        surfaceTintColor: AppColors.appBarColor,
        foregroundColor: AppColors.onAppBarColor,
        bottom: const TricolourStrip(),
        title: Text(
          ref.tr('notification.title'),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.onAppBarColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: notificationState.unreadCount == 0 || _markingAllAsRead
                ? null
                : _markAll,
            style: TextButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: _markingAllAsRead
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onAppBarColor,
                    ),
                  )
                : Text(
                    ref.tr('notification.markAllAsRead'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: notificationState.unreadCount == 0
                          ? AppColors.onAppBarMutedColor
                          : AppColors.onAppBarColor,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(notificationState)),
    );
  }

  Widget _buildBody(NotificationState state) {
    if (state.status == NotificationStatus.loading &&
        state.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == NotificationStatus.error &&
        state.notifications.isEmpty) {
      return _buildError(state.message);
    }

    if (state.notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: () =>
            ref.read(notificationProvider.notifier).fetchNotifications(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 60),
            EmptyNote(
              ref.tr('notification.noNotifications'),
              icon: Icons.notifications_none_rounded,
            ),
          ],
        ),
      );
    }

    final categories = <String>{
      for (final n in state.notifications)
        if ((n['category']?.toString() ?? '').isNotEmpty)
          n['category'].toString(),
    }.toList()
      ..sort();

    final filter = (_filter == _filterAll ||
            _filter == _filterUnread ||
            categories.contains(_filter))
        ? _filter
        : _filterAll;

    final visible = state.notifications.where((n) {
      if (filter == _filterAll) return true;
      if (filter == _filterUnread) return n['readAt'] == null;

      return n['category']?.toString() == filter;
    }).toList();

    return RefreshIndicator(
      onRefresh: () {
        return ref.read(notificationProvider.notifier).fetchNotifications();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            state.unreadCount > 0
                ? fill(ref.tr('notifx.unreadCount'), {
                    'count': state.unreadCount,
                  })
                : ref.tr('notification.allCaughtUp'),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.mutedColor,
            ),
          ),
          const SizedBox(height: 10),
          _buildFilters(categories, state.unreadCount, filter),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            EmptyNote(
              ref.tr('notifx.noneInFilter'),
              icon: Icons.filter_alt_off_outlined,
            )
          else
            ..._buildNotificationGroups(visible),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFilters(List<String> categories, int unread, String current) {
    final options = <(String, String)>[
      (_filterAll, ref.tr('notifx.filterAll')),
      (
        _filterUnread,
        unread > 0
            ? '${ref.tr('notifx.filterUnread')} ($unread)'
            : ref.tr('notifx.filterUnread'),
      ),
      for (final category in categories) (category, _categoryLabel(category)),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (value, label) = options[index];
          final selected = current == value;

          return ChoiceChip(
            label: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.white : AppColors.textColor,
              ),
            ),
            selected: selected,
            showCheckmark: false,
            selectedColor: AppColors.primaryFillColor,
            backgroundColor: AppColors.white,
            side: BorderSide(
              color: selected
                  ? AppColors.primaryFillColor
                  : AppColors.borderColor,
            ),
            onSelected: (_) => setState(() => _filter = value),
          );
        },
      ),
    );
  }

  String _categoryLabel(String category) {
    final key = 'notifx.cat_$category';
    final translated = ref.tr(key);

    if (translated != key) return translated;

    final words = category.replaceAll('_', ' ');

    return words.isEmpty
        ? category
        : '${words[0].toUpperCase()}${words.substring(1)}';
  }

  List<Widget> _buildNotificationGroups(
    List<Map<String, dynamic>> notifications,
  ) {
    final now = DateTime.now();

    final today = <Map<String, dynamic>>[];
    final earlier = <Map<String, dynamic>>[];

    for (final notification in notifications) {
      final createdAt = DateTime.tryParse(
        notification['createdAt']?.toString() ?? '',
      );

      if (createdAt == null) {
        earlier.add(notification);
        continue;
      }

      final localDate = createdAt.toLocal();

      final isToday = localDate.year == now.year &&
          localDate.month == now.month &&
          localDate.day == now.day;

      if (isToday) {
        today.add(notification);
      } else {
        earlier.add(notification);
      }
    }

    final widgets = <Widget>[];

    if (today.isNotEmpty) {
      widgets.add(_buildSectionTitle(ref.tr('notification.today')));
      widgets.add(const SizedBox(height: 8));
      widgets.addAll(today.map((n) => _buildItem(n, isToday: true)));
    }

    if (earlier.isNotEmpty) {
      widgets.add(const SizedBox(height: 20));
      widgets.add(_buildSectionTitle(ref.tr('notification.earlier')));
      widgets.add(const SizedBox(height: 5));
      widgets.addAll(earlier.map((n) => _buildItem(n, isToday: false)));
    }

    return widgets;
  }

  Widget _buildItem(Map<String, dynamic> notification, {required bool isToday}) {
    final id = toInt(notification['id']) ?? 0;
    final isMessage = notification['category']?.toString() == 'message';
    final senderName = notification['senderName']?.toString();

    final title = isMessage
        ? fill(ref.tr('notifx.messageFrom'), {
            'name': (senderName == null || senderName.isEmpty)
                ? ref.tr('notifx.someone')
                : senderName,
          })
        : (notification['title']?.toString() ??
            ref.tr('notification.notification'));

    final replyToBody = notification['replyToBody']?.toString();
    final replyQuote = notification['replyToId'] == null
        ? null
        : (replyToBody != null && replyToBody.isNotEmpty)
            ? (replyToBody.length > 70
                ? '${replyToBody.substring(0, 70)}…'
                : replyToBody)
            : (notification['replyToAudioPath'] != null
                ? ref.tr('notifx.voiceNote')
                : '');

    return _NotificationItem(
      key: ValueKey('notification-$id'),
      icon: _getNotificationIcon(notification['category']),
      title: title,
      body: notification['body']?.toString(),
      time: isToday
          ? _formatTime(notification['createdAt'])
          : _formatDateTime(notification['createdAt']),
      unread: notification['readAt'] == null,
      expanded: _expanded.contains(id),
      replyQuote: replyQuote == null
          ? null
          : fill(ref.tr('notifx.replyingTo'), {'text': replyQuote}),
      imagePath: notification['imagePath']?.toString(),
      audioPath: notification['audioPath']?.toString(),
      replyLabel: isMessage && notification['senderId'] != null
          ? ref.tr('notifx.reply')
          : null,
      onReply: () => _openReply(id, title),
      onTap: () async {
        setState(() {
          if (!_expanded.remove(id)) _expanded.add(id);
        });

        if (notification['readAt'] == null) {
          await ref.read(notificationProvider.notifier).markAsRead(id);
        }
      },
    );
  }

  Future<void> _openReply(int id, String title) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => _ReplySheet(notificationId: id, title: title),
    );

    if (sent == true && mounted) {
      showFeatureSnack(context, ref.tr('notifx.replySent'));
      ref
          .read(notificationProvider.notifier)
          .fetchNotifications(showLoading: false);
    }
  }

  IconData _getNotificationIcon(dynamic category) {
    switch (category?.toString()) {
      case 'attendance':
        return Icons.fingerprint_rounded;
      case 'leave':
      case 'comp_off':
        return Icons.fact_check_outlined;
      case 'task':
        return Icons.assignment_outlined;
      case 'message':
        return Icons.chat_bubble_outline;
      case 'salary':
      case 'finance':
        return Icons.receipt_long_outlined;
      case 'schedule':
        return Icons.calendar_month_outlined;
      case 'assets':
        return Icons.laptop_mac_outlined;
      case 'operations':
      case 'production':
        return Icons.precision_manufacturing_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  String _formatTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) return '';

    return DateFormat('hh:mm a').format(date.toLocal());
  }

  String _formatDateTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) return '';

    final localDate = date.toLocal();
    final month = _localizedMonth(localDate.month);

    return '$month ${localDate.day}, ${DateFormat('hh:mm a').format(localDate)}';
  }

  String _localizedMonth(int month) {
    const monthKeys = <String>[
      'notification.jan',
      'notification.feb',
      'notification.mar',
      'notification.apr',
      'notification.may',
      'notification.jun',
      'notification.jul',
      'notification.aug',
      'notification.sep',
      'notification.oct',
      'notification.nov',
      'notification.dec',
    ];

    if (month < 1 || month > monthKeys.length) {
      return '';
    }

    return ref.tr(monthKeys[month - 1]);
  }

  Widget _buildError(String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              message ?? ref.tr('notification.loadError'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.mutedColor,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                ref.read(notificationProvider.notifier).fetchNotifications();
              },
              child: Text(ref.tr('notification.tryAgain')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: .5,
          color: AppColors.mutedColor,
        ),
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String time;
  final bool unread;
  final bool expanded;
  final String? replyQuote;
  final String? imagePath;
  final String? audioPath;
  final String? replyLabel;
  final VoidCallback? onReply;
  final VoidCallback? onTap;

  const _NotificationItem({
    super.key,
    required this.icon,
    required this.title,
    required this.time,
    this.body,
    this.unread = false,
    this.expanded = false,
    this.replyQuote,
    this.imagePath,
    this.audioPath,
    this.replyLabel,
    this.onReply,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    final hasAudio = audioPath != null && audioPath!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: unread ? AppColors.saffronTint : null,
          border: const Border(
            bottom: BorderSide(color: AppColors.borderColor, width: .7),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 12,
              child: unread
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryFillColor,
                        ),
                      ),
                    )
                  : null,
            ),
            Container(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: AppColors.primaryFillColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: expanded ? null : 1,
                    overflow: expanded ? null : TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                      color: AppColors.textColor,
                    ),
                  ),
                  if (body != null && body!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      body!,
                      maxLines: expanded ? null : 2,
                      overflow: expanded ? null : TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.35,
                        color: expanded
                            ? AppColors.textColor
                            : AppColors.mutedColor,
                      ),
                    ),
                  ],
                  if (replyQuote != null && replyQuote!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.only(left: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: AppColors.borderColor,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        replyQuote!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.mutedColor,
                        ),
                      ),
                    ),
                  ],
                  if (hasImage) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _openImage(context, imagePath!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: StoredFileImage(
                          path: imagePath!,
                          height: expanded ? 220 : 120,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ],
                  if (hasAudio) ...[
                    const SizedBox(height: 8),
                    _StoredAudioPlayer(path: audioPath!),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          time,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.mutedColor,
                          ),
                        ),
                      ),
                      if (replyLabel != null)
                        TextButton.icon(
                          onPressed: onReply,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.reply_rounded, size: 16),
                          label: Text(
                            replyLabel!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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

  void _openImage(BuildContext context, String path) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              child: StoredFileImage(path: path, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// VOICE NOTE PLAYER
// ============================================================================

/// Plays a voice note from `/api/files`. The bytes come through the
/// authenticated client, are written to a temp file once, then played.
class _StoredAudioPlayer extends ConsumerStatefulWidget {
  final String path;

  const _StoredAudioPlayer({required this.path});

  @override
  ConsumerState<_StoredAudioPlayer> createState() => _StoredAudioPlayerState();
}

class _StoredAudioPlayerState extends ConsumerState<_StoredAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _loaded = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_player.playing &&
        _player.processingState != ProcessingState.completed) {
      await _player.pause();
      return;
    }

    if (!_loaded) {
      setState(() {
        _loading = true;
        _error = null;
      });

      try {
        final bytes =
            await fetchStoredFile(ref.read(apiClientProvider), widget.path);
        final dir = await getTemporaryDirectory();
        final name = widget.path.split('/').last;
        final file = File('${dir.path}/notif_$name');

        await file.writeAsBytes(bytes, flush: true);
        await _player.setFilePath(file.path);

        _loaded = true;
      } catch (e) {
        if (mounted) setState(() => _error = cleanErrorMessage(e));
        return;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }

    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }

    unawaited(_player.play());
  }

  String _fmt(Duration? d) {
    if (d == null) return '0:00';

    final s = d.inSeconds;

    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: StreamBuilder<PlayerState>(
        stream: _player.playerStateStream,
        builder: (context, snapshot) {
          final playing = snapshot.data?.playing ?? false;
          final completed =
              snapshot.data?.processingState == ProcessingState.completed;

          return Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _loading ? null : _toggle,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        playing && !completed
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: AppColors.primaryFillColor,
                      ),
              ),
              Expanded(
                child: _error != null
                    ? Text(
                        _error!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFFB3261E),
                        ),
                      )
                    : StreamBuilder<Duration>(
                        stream: _player.positionStream,
                        builder: (context, position) {
                          final total = _player.duration;
                          final value =
                              (total == null || total.inMilliseconds == 0)
                                  ? 0.0
                                  : (position.data?.inMilliseconds ?? 0) /
                                      total.inMilliseconds;

                          return Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: value.clamp(0.0, 1.0),
                                  minHeight: 3,
                                  backgroundColor: AppColors.borderColor,
                                  color: AppColors.primaryFillColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _fmt(total),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.mutedColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// REPLY SHEET
// ============================================================================

class _ReplySheet extends ConsumerStatefulWidget {
  final int notificationId;
  final String title;

  const _ReplySheet({required this.notificationId, required this.title});

  @override
  ConsumerState<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends ConsumerState<_ReplySheet> {
  final _text = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();

  bool _recording = false;
  bool _sending = false;
  String? _audioPath;
  String? _error;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();

      _timer?.cancel();

      if (!mounted) return;

      setState(() {
        _recording = false;
        _audioPath = path;
      });

      return;
    }

    if (!await _recorder.hasPermission()) {
      if (!mounted) return;

      setState(() => _error = ref.tr('notifx.micPermission'));
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/reply_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed += const Duration(seconds: 1));
      }
    });

    if (!mounted) return;

    setState(() {
      _recording = true;
      _audioPath = null;
      _elapsed = Duration.zero;
      _error = null;
    });
  }

  Future<void> _send() async {
    if (_recording) {
      setState(() => _error = ref.tr('notifx.finishRecording'));
      return;
    }

    if (_text.text.trim().isEmpty && _audioPath == null) {
      setState(() => _error = ref.tr('notifx.replyEmpty'));
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await ref.read(notificationRepositoryProvider).reply(
            widget.notificationId,
            message: _text.text,
            audioFilePath: _audioPath,
          );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _sending = false;
        _error = cleanErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _elapsed.inSeconds;
    final elapsed =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _text,
            maxLength: 2000,
            minLines: 2,
            maxLines: 5,
            decoration: featureInputDecoration(
              ref.tr('notifx.reply'),
              hint: ref.tr('notifx.replyPlaceholder'),
            ),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _sending ? null : _toggleRecording,
                icon: Icon(
                  _recording ? Icons.stop_rounded : Icons.mic_none_rounded,
                  color: _recording ? const Color(0xFFB3261E) : null,
                ),
                label: Text(
                  _recording
                      ? '${ref.tr('notifx.stopRecording')} $elapsed'
                      : ref.tr('notifx.recordVoice'),
                ),
              ),
              if (_audioPath != null && !_recording) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AppColors.indiaGreen,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${ref.tr('notifx.voiceNote')} $elapsed',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _audioPath = null),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _sending ? null : _send,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(ref.tr('notifx.sendReply')),
          ),
        ],
      ),
    );
  }
}
