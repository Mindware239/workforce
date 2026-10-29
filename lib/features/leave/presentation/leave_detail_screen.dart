import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/leave/providers/leave_provider.dart';

/// One leave request, as the web's leave detail dialog shows it to the
/// employee: the details, the reason (and voice note), the balance, the
/// approval ladder with who has it now, the comments, and — while it can
/// still be withdrawn — the withdraw button. GET /api/leaves/:id.
class LeaveDetailScreen extends ConsumerStatefulWidget {
  final int leaveId;

  const LeaveDetailScreen({super.key, required this.leaveId});

  @override
  ConsumerState<LeaveDetailScreen> createState() => _LeaveDetailScreenState();
}

class _LeaveDetailScreenState extends ConsumerState<LeaveDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _posting = false;
  bool _cancelling = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _withdraw() async {
    final confirmed = await confirmAction(
      context,
      title: ref.tr('leavex.withdrawTitle'),
      message: ref.tr('leavex.withdrawMessage'),
      confirmLabel: ref.tr('leavex.withdraw'),
      cancelLabel: ref.tr('common.cancel'),
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    setState(() => _cancelling = true);

    final error = await ref
        .read(leaveProvider.notifier)
        .cancelLeave(widget.leaveId);

    if (!mounted) return;

    setState(() => _cancelling = false);

    showFeatureSnack(context, error ?? ref.tr('leavex.withdrawn'));

    if (error == null) ref.invalidate(leaveDetailProvider(widget.leaveId));
  }

  Future<void> _postComment() async {
    final note = _commentController.text.trim();

    if (note.isEmpty) return;

    setState(() => _posting = true);

    final error = await ref
        .read(leaveProvider.notifier)
        .addComment(widget.leaveId, note);

    if (!mounted) return;

    setState(() => _posting = false);

    if (error != null) {
      showFeatureSnack(context, error);
      return;
    }

    _commentController.clear();
    FocusScope.of(context).unfocus();
    showFeatureSnack(context, ref.tr('leavex.commentAdded'));
    ref.invalidate(leaveDetailProvider(widget.leaveId));
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(leaveDetailProvider(widget.leaveId));

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(title: ref.tr('leavex.requestTitle')),
      body: SafeArea(
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: LoadErrorView(
              message: cleanErrorMessage(error),
              retryLabel: ref.tr('common.retry'),
              onRetry: () =>
                  ref.invalidate(leaveDetailProvider(widget.leaveId)),
            ),
          ),
          data: (data) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(leaveDetailProvider(widget.leaveId));
              await ref.read(leaveDetailProvider(widget.leaveId).future);
            },
            child: _buildBody(data),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody(Map<String, dynamic> data) {
    final leave = asMap(data['leave']);
    final approvals = asMapList(data['approvals']);
    final comments = asMapList(data['events'])
        .where((e) => e['event']?.toString() == 'comment.added')
        .toList();
    final balance = asMap(data['balance']);
    final permissions = asMap(data['permissions']);
    final workflow = asMap(data['workflow']);

    final status = leave['status']?.toString() ?? 'pending';
    final type = leave['leave_type']?.toString();
    final totalLevels = toInt(leave['totalLevels']) ?? 1;
    final currentLevel = toInt(leave['current_level']);
    final hasVoiceNote =
        leave['hasVoiceNote'] == true || leave['voice_note_path'] == true;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _categoryLabel(leave['leave_category']?.toString()),
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
            ),
            StatusChip(label: _statusLabel(status), tone: _statusTone(status)),
          ],
        ),

        if (status == 'pending' && currentLevel != null) ...[
          const SizedBox(height: 4),
          Text(
            [
              fill(ref.tr('leavex.levelOf'), {
                'level': currentLevel,
                'total': totalLevels,
              }),
              if ((workflow['name']?.toString() ?? '').isNotEmpty)
                workflow['name'].toString(),
            ].join(' · '),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
          ),
        ],

        const SizedBox(height: 16),

        SectionTitle(ref.tr('leavex.leaveDetails')),
        const SizedBox(height: 8),
        FeatureCard(
          child: Column(
            children: [
              InfoRow(
                label: ref.tr('leavex.duration'),
                value: type == 'half_day'
                    ? '${ref.tr('leave.halfDay')}'
                          '${leave['half_day_session'] == null ? '' : ' (${leave['half_day_session'] == 'SECOND' ? ref.tr('leavex.secondHalf') : ref.tr('leavex.firstHalf')})'}'
                    : type == 'partial'
                    ? ref.tr('leavex.permission')
                    : ref.tr('leave.fullDay'),
              ),
              InfoRow(
                label: ref.tr('leave.startDate'),
                value: formatApiDate(leave['start_date']),
              ),
              if (leave['end_date'] != null &&
                  leave['end_date'] != leave['start_date'])
                InfoRow(
                  label: ref.tr('leave.endDate'),
                  value: formatApiDate(leave['end_date']),
                ),
              if (type == 'partial' && leave['start_time'] != null)
                InfoRow(
                  label: ref.tr('leavex.hours'),
                  value:
                      '${_hm(leave['start_time'])} – ${_hm(leave['end_time'])}',
                ),
              if (type != 'partial')
                InfoRow(
                  label: ref.tr('leavex.totalDays'),
                  value: _trimNum(leave['total_days']),
                ),
              InfoRow(
                label: ref.tr('leavex.submitted'),
                value: formatApiDate(
                  leave['submitted_at'] ?? leave['created_at'],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        SectionTitle(ref.tr('leave.reason')),
        const SizedBox(height: 8),
        FeatureCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                leave['reason']?.toString() ?? '-',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textColor,
                ),
              ),
              if (hasVoiceNote) ...[
                const SizedBox(height: 10),
                _LeaveVoiceNotePlayer(leaveId: widget.leaveId),
              ],
            ],
          ),
        ),

        if ((leave['admin_remarks']?.toString().trim() ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionTitle(ref.tr('leavex.remarks')),
          const SizedBox(height: 8),
          FeatureCard(
            child: Text(
              leave['admin_remarks'].toString(),
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textColor),
            ),
          ),
        ],

        if (balance.isNotEmpty && balance['total'] != null) ...[
          const SizedBox(height: 16),
          SectionTitle(ref.tr('leavex.leaveBalance')),
          const SizedBox(height: 8),
          _BalanceStrip(
            total: toNum(balance['total']) ?? 0,
            used: toNum(balance['used']) ?? 0,
            pending: toNum(balance['pending']) ?? 0,
            remaining: toNum(balance['remaining']) ?? 0,
            labels: (
              used: ref.tr('leavex.balUsed'),
              pending: ref.tr('leavex.balPending'),
              remaining: ref.tr('leavex.balRemaining'),
              of: ref.tr('leavex.balOf'),
            ),
          ),
        ],

        const SizedBox(height: 16),

        SectionTitle(ref.tr('leavex.approvalTimeline')),
        const SizedBox(height: 8),
        if (approvals.isEmpty)
          EmptyNote(ref.tr('leavex.noApprovals'), icon: Icons.timeline_rounded)
        else
          FeatureCard(
            child: Column(
              children: [
                for (var i = 0; i < approvals.length; i++)
                  _approvalRow(approvals[i], isLast: i == approvals.length - 1),
              ],
            ),
          ),

        const SizedBox(height: 16),

        SectionTitle(ref.tr('leavex.comments')),
        const SizedBox(height: 8),
        if (comments.isEmpty)
          Text(
            ref.tr('leavex.noComments'),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
          )
        else
          ...comments.map(
            (c) => FeatureCard(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c['actorName'] ?? '-'} · ${formatApiDate(c['createdAt'])}',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c['note']?.toString() ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (permissions['canComment'] == true) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _commentController,
            minLines: 1,
            maxLines: 4,
            maxLength: 2000,
            decoration: featureInputDecoration(ref.tr('leavex.addComment')),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _posting ? null : _postComment,
              child: _posting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(ref.tr('leavex.postComment')),
            ),
          ),
        ],

        if (permissions['canCancel'] == true) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _cancelling ? null : _withdraw,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB3261E),
                side: const BorderSide(color: Color(0xFFF5C2C0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _cancelling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.undo_rounded, size: 18),
              label: Text(ref.tr('leavex.withdraw')),
            ),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _approvalRow(Map<String, dynamic> a, {required bool isLast}) {
    final status = a['status']?.toString() ?? 'waiting';
    final level = toInt(a['level']);
    final label = a['stepLabel']?.toString() ?? '';

    final who = status == 'pending' || status == 'waiting'
        ? (a['assignedToName'] ?? '').toString()
        : [
            a['decidedByName']?.toString(),
            if (a['decidedAt'] != null) formatApiDate(a['decidedAt']),
          ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    final comment = a['comment']?.toString().trim() ?? '';

    final (IconData icon, Color color) = switch (status) {
      'approved' => (Icons.check_circle_rounded, AppColors.indiaGreen),
      'rejected' => (Icons.cancel_rounded, const Color(0xFFB3261E)),
      'changes_requested' => (Icons.edit_note_rounded, AppColors.saffronText),
      'pending' => (Icons.hourglass_top_rounded, AppColors.saffronText),
      'skipped' || 'cancelled' || 'overridden' => (
        Icons.remove_circle_outline_rounded,
        AppColors.mutedColor,
      ),
      _ => (Icons.radio_button_unchecked_rounded, AppColors.mutedColor),
    };

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level == null
                      ? label
                      : fill(ref.tr('leavex.levelStep'), {
                          'level': level,
                          'label': label,
                        }),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    _approvalStatusLabel(status),
                    if (who.isNotEmpty) who,
                  ].join(' · '),
                  style: GoogleFonts.inter(fontSize: 11.5, color: color),
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    comment,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.mutedColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LABELS
  // ============================================================

  String _hm(dynamic value) {
    final text = value?.toString() ?? '';

    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  String _trimNum(dynamic value) {
    final n = toNum(value);

    if (n == null) return '-';

    return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
  }

  String _categoryLabel(String? category) {
    switch (category) {
      case 'sick':
        return ref.tr('leave.sickLeave');
      case 'earned':
        return ref.tr('leave.earnedLeave');
      case 'unpaid':
        return ref.tr('leavex.unpaidLeave');
      case 'comp_off':
        return ref.tr('leavex.compOff');
      default:
        return ref.tr('leave.casualLeave');
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return ref.tr('leave.approved');
      case 'rejected':
        return ref.tr('leave.rejected');
      case 'cancelled':
        return ref.tr('leavex.statusCancelled');
      case 'changes_requested':
        return ref.tr('leavex.changesRequested');
      default:
        return ref.tr('leave.pending');
    }
  }

  ChipTone _statusTone(String status) {
    switch (status) {
      case 'approved':
        return ChipTone.success;
      case 'rejected':
        return ChipTone.danger;
      case 'cancelled':
        return ChipTone.neutral;
      default:
        return ChipTone.warning;
    }
  }

  String _approvalStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return ref.tr('leave.approved');
      case 'rejected':
        return ref.tr('leave.rejected');
      case 'changes_requested':
        return ref.tr('leavex.changesRequested');
      case 'pending':
        return ref.tr('leavex.withThem');
      case 'skipped':
        return ref.tr('leavex.skipped');
      case 'overridden':
        return ref.tr('leavex.overridden');
      case 'cancelled':
        return ref.tr('leavex.statusCancelled');
      default:
        return ref.tr('leavex.waiting');
    }
  }
}

// ============================================================================
// BALANCE STRIP
// ============================================================================

class _BalanceStrip extends StatelessWidget {
  final num total;
  final num used;
  final num pending;
  final num remaining;
  final ({String used, String pending, String remaining, String of}) labels;

  const _BalanceStrip({
    required this.total,
    required this.used,
    required this.pending,
    required this.remaining,
    required this.labels,
  });

  String _n(num value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  @override
  Widget build(BuildContext context) {
    final safeTotal = total <= 0 ? 1 : total;
    final usedFlex = ((used / safeTotal) * 1000).round().clamp(0, 1000);
    final pendingFlex = ((pending / safeTotal) * 1000).round().clamp(0, 1000);
    final restFlex = (1000 - usedFlex - pendingFlex).clamp(0, 1000);

    Widget legend(Color color, String label, num value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: AppColors.borderColor),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$label ${_n(value)}',
            style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textColor),
          ),
        ],
      );
    }

    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (usedFlex > 0)
                    Expanded(
                      flex: usedFlex,
                      child: Container(color: AppColors.indiaGreen),
                    ),
                  if (pendingFlex > 0)
                    Expanded(
                      flex: pendingFlex,
                      child: Container(color: AppColors.saffron),
                    ),
                  if (restFlex > 0)
                    Expanded(
                      flex: restFlex,
                      child: Container(color: const Color(0xFFF1F1F3)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              legend(AppColors.indiaGreen, labels.used, used),
              legend(AppColors.saffron, labels.pending, pending),
              legend(const Color(0xFFF1F1F3), labels.remaining, remaining),
              Text(
                fill(labels.of, {'total': _n(total)}),
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppColors.mutedColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// VOICE NOTE PLAYER
// ============================================================================

/// Plays the request's recorded reason. The API never returns a path, only
/// the bytes from GET /leaves/:id/voice-note, so they are written to a temp
/// file for the player.
class _LeaveVoiceNotePlayer extends ConsumerStatefulWidget {
  final int leaveId;

  const _LeaveVoiceNotePlayer({required this.leaveId});

  @override
  ConsumerState<_LeaveVoiceNotePlayer> createState() =>
      _LeaveVoiceNotePlayerState();
}

class _LeaveVoiceNotePlayerState extends ConsumerState<_LeaveVoiceNotePlayer> {
  final AudioPlayer _player = AudioPlayer();
  String? _localPath;
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _player.stop();
        _player.seek(Duration.zero);
      }

      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_player.playing) {
        await _player.pause();
        return;
      }

      if (_localPath == null) {
        setState(() => _loading = true);

        final bytes = await ref
            .read(leaveRepositoryProvider)
            .getVoiceNote(widget.leaveId);

        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/leave_${widget.leaveId}_note.m4a');

        await file.writeAsBytes(bytes, flush: true);

        _localPath = file.path;

        await _player.setFilePath(file.path);

        if (mounted) setState(() => _loading = false);
      }

      await _player.play();
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
      showFeatureSnack(context, cleanErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: _loading ? null : _toggle,
          icon: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _player.playing
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: AppColors.primaryFillColor,
                  size: 32,
                ),
        ),
        Text(
          ref.tr('leavex.voiceNote'),
          style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textColor),
        ),
      ],
    );
  }
}
