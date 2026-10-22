import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/task/data/task_repository.dart';
import 'package:workforce/features/task/presentation/task_screen.dart';
import 'package:workforce/features/task/presentation/task_ui.dart';
import 'package:workforce/features/task/providers/task_record_provider.dart';

/// One task in full, as the web's task-detail-dialog shows it: the brief,
/// checklist, files and proof of work, progress, the lifecycle actions the
/// server says this person may take, the reviews, the timeline, the work
/// sessions and the notes.
class TaskDetailScreen extends ConsumerStatefulWidget {
  final int taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  bool _busy = false;
  double? _progressDraft;

  int get _id => widget.taskId;

  TaskRepository get _repo => ref.read(taskRepositoryProvider);

  void _refresh() {
    ref.invalidate(taskDetailProvider(_id));
    ref.invalidate(taskCommentsProvider(_id));
  }

  Future<bool> _run(
    Future<void> Function() action, {
    String? successKey,
  }) async {
    if (_busy) return false;

    setState(() => _busy = true);

    final error = await ref.read(taskActionsProvider).run(action);

    if (!mounted) return false;

    setState(() => _busy = false);

    if (error != null) {
      showFeatureSnack(context, error);
      return false;
    }

    if (successKey != null) showFeatureSnack(context, ref.tr(successKey));

    _refresh();

    return true;
  }

  // ==========================================================================
  // ACTIONS
  // ==========================================================================

  Future<void> _lifecycle(String action, {String? successKey}) {
    return _run(
      () => _repo.runLifecycleAction(_id, action),
      successKey: successKey ?? 'taskx.updated',
    );
  }

  Future<void> _openSubmit(bool evidenceRequired, int proofCount) async {
    final controller = TextEditingController();

    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          ref.tr('taskx.submitForReview'),
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (evidenceRequired && proofCount == 0) ...[
              Text(
                ref.tr('taskx.proofNeeded'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.saffronText,
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 2000,
              decoration: featureInputDecoration(ref.tr('taskx.submitNote')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(ref.tr('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(ref.tr('taskx.send')),
          ),
        ],
      ),
    );

    controller.dispose();

    if (note == null) return;

    await _run(
      () => _repo.runLifecycleAction(
        _id,
        'submit',
        data: {if (note.isNotEmpty) 'note': note},
      ),
      successKey: 'taskx.submittedToast',
    );
  }

  Future<void> _openBlock() async {
    final controller = TextEditingController();
    String reason = 'waiting_for_client';

    final result = await showDialog<({String code, String note})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            ref.tr('taskx.markBlocked'),
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  isExpanded: true,
                  decoration: featureInputDecoration(
                    ref.tr('taskx.blockReason'),
                  ),
                  items: [
                    for (final code in taskBlockReasons)
                      DropdownMenuItem(
                        value: code,
                        child: Text(
                          taskBlockReasonLabel(ref, code),
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => reason = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: featureInputDecoration(
                    ref.tr('taskx.blockNote'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(ref.tr('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(
                (code: reason, note: controller.text.trim()),
              ),
              child: Text(ref.tr('taskx.markBlocked')),
            ),
          ],
        ),
      ),
    );

    controller.dispose();

    if (result == null) return;

    if (result.code == 'other' && result.note.length < 3) {
      if (mounted) showFeatureSnack(context, ref.tr('taskx.noteRequired'));
      return;
    }

    await _run(
      () => _repo.runLifecycleAction(
        _id,
        'block',
        data: {
          'reasonCode': result.code,
          if (result.note.isNotEmpty) 'note': result.note,
        },
      ),
      successKey: 'taskx.updated',
    );
  }

  Future<void> _addProof() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(ref.tr('taskx.takePhoto')),
              onTap: () => Navigator.of(context).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(ref.tr('taskx.chooseGallery')),
              onTap: () => Navigator.of(context).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(ref.tr('taskx.chooseFiles')),
              onTap: () => Navigator.of(context).pop('file'),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    final files = <({String path, String name})>[];

    try {
      if (choice == 'file') {
        final picked = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'jpg', 'jpeg', 'png', 'webp', 'pdf', 'doc', 'docx', //
            'xls', 'xlsx', 'txt', 'csv',
          ],
        );

        for (final file in picked.take(10)) {
          if (file.path != null && file.path!.isNotEmpty) {
            files.add((path: file.path!, name: file.name));
          }
        }
      } else {
        // imageQuality re-encodes as JPEG (the server refuses HEIC).
        final image = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 2000,
          maxHeight: 2000,
        );

        if (image != null) files.add((path: image.path, name: image.name));
      }
    } catch (e) {
      if (mounted) showFeatureSnack(context, ref.tr('taskx.couldNotPick'));
      return;
    }

    if (files.isEmpty || !mounted) return;

    final captionController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          ref.tr('taskx.addProof'),
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              files.map((f) => f.name).join('\n'),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: captionController,
              maxLength: 200,
              decoration: featureInputDecoration(ref.tr('taskx.caption')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(ref.tr('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(ref.tr('taskx.upload')),
          ),
        ],
      ),
    );

    final caption = captionController.text.trim();
    captionController.dispose();

    if (confirmed != true) return;

    await _run(
      () => _repo.uploadAttachments(_id, files: files, caption: caption),
      successKey: 'taskx.proofAdded',
    );
  }

  Future<void> _download(Map<String, dynamic> file) async {
    final attachmentId = toInt(file['id']);

    if (attachmentId == null) return;

    final name = file['originalName']?.toString() ?? 'task-file-$attachmentId';

    try {
      final path = await _repo.saveAttachment(_id, attachmentId, name);

      if (mounted) {
        showFeatureSnack(context, fill(ref.tr('taskx.savedTo'), {'path': path}));
      }
    } catch (e) {
      if (mounted) showFeatureSnack(context, cleanErrorMessage(e));
    }
  }

  Future<void> _removeFile(Map<String, dynamic> file) async {
    final attachmentId = toInt(file['id']);

    if (attachmentId == null) return;

    final ok = await confirmAction(
      context,
      title: ref.tr('taskx.removeFile'),
      message: file['originalName']?.toString() ?? '',
      confirmLabel: ref.tr('common.delete'),
      cancelLabel: ref.tr('common.cancel'),
      destructive: true,
    );

    if (!ok) return;

    await _run(() => _repo.removeAttachment(_id, attachmentId));
  }

  void _previewImage(Map<String, dynamic> file) {
    final attachmentId = toInt(file['id']);

    if (attachmentId == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(
                child: _AttachmentImage(
                  taskId: _id,
                  attachmentId: attachmentId,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _download(file),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(ref.tr('taskx.download')),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(ref.tr('common.close')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(taskDetailProvider(_id));

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(title: ref.tr('taskx.detailTitle')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LoadErrorView(
              message: cleanErrorMessage(error),
              retryLabel: ref.tr('common.retry'),
              onRetry: _refresh,
            ),
          ],
        ),
        data: (data) => Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                _refresh();
                await ref.read(taskDetailProvider(_id).future);
              },
              child: _buildBody(data),
            ),
            if (_busy)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> data) {
    final task = asMap(data['task']);
    final perms = asMap(data['permissions']);
    final checklist = asMapList(data['checklist']);
    final attachments = asMapList(data['attachments']);
    final reviews = asMapList(data['reviews']);
    final events = asMapList(data['events']);
    final sessions = asMapList(data['sessions']);

    final status = task['status']?.toString() ?? 'pending';
    final isOpen = !terminalTaskStatuses.contains(status);
    final isAssignee = perms['isAssignee'] == true;
    final canUpload = isOpen && isAssignee;
    final canTick = isOpen &&
        status != 'submitted' &&
        (isAssignee ||
            perms['isManager'] == true ||
            perms['isReviewer'] == true);
    final proofs = attachments.where((f) => f['kind'] == 'proof').toList();
    final handouts = attachments.where((f) => f['kind'] != 'proof').toList();
    final evidenceRequired = task['evidenceRequired'] == true;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _header(task, status),
        const SizedBox(height: 14),
        _actions(perms, status, evidenceRequired, proofs.length),
        if (status == 'blocked') ...[
          const SizedBox(height: 12),
          _blockedBanner(task),
        ],
        if (status == 'changes_requested' && reviews.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sentBackBanner(reviews.last),
        ],
        const SizedBox(height: 16),
        _details(task),
        if ((task['description']?.toString() ?? '').isNotEmpty ||
            (task['voiceNotePath']?.toString() ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionTitle(ref.tr('taskx.description')),
          const SizedBox(height: 8),
          if ((task['description']?.toString() ?? '').isNotEmpty)
            Text(
              task['description'].toString(),
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textColor,
              ),
            ),
          if ((task['voiceNotePath']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            TaskVoiceNotePlayer(audioUrl: task['voiceNotePath'].toString()),
          ],
        ],
        if ((task['acceptanceCriteria']?.toString() ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionTitle(ref.tr('taskx.acceptanceCriteria')),
          const SizedBox(height: 8),
          FeatureCard(
            child: Text(
              task['acceptanceCriteria'].toString(),
              style: GoogleFonts.inter(fontSize: 13, height: 1.45),
            ),
          ),
        ],
        if (checklist.isNotEmpty) ...[
          const SizedBox(height: 16),
          _checklist(checklist, canTick),
        ],
        const SizedBox(height: 16),
        _files(handouts, proofs, canUpload, evidenceRequired),
        const SizedBox(height: 16),
        _progress(task, perms['canSetProgress'] == true),
        if (reviews.isNotEmpty) ...[
          const SizedBox(height: 16),
          _reviews(reviews),
        ],
        const SizedBox(height: 16),
        _timeline(events),
        if (sessions.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sessions(sessions),
        ],
        const SizedBox(height: 16),
        _notes(),
      ],
    );
  }

  Widget _header(Map<String, dynamic> task, String status) {
    final priority = task['priority']?.toString() ?? 'medium';
    final revision = toInt(task['revision']) ?? 1;
    final points = toInt(task['weightPoints']) ?? 1;
    final rollover = toInt(task['rolloverCount']) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task['title']?.toString() ?? ref.tr('tasks.task'),
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            StatusChip(
              label: taskStatusLabel(ref, status),
              tone: taskStatusTone(status),
            ),
            StatusChip(
              label: taskPriorityLabel(ref, priority),
              tone: taskPriorityTone(priority),
            ),
            if (isTaskOverdue(task))
              StatusChip(label: ref.tr('taskx.late'), tone: ChipTone.danger),
            if (rollover > 0)
              StatusChip(
                label: fill(ref.tr('taskx.movedTimes'), {'n': rollover}),
                tone: ChipTone.warning,
              ),
            if (revision > 1)
              StatusChip(
                label: fill(ref.tr('taskx.attemptN'), {'n': revision}),
                tone: ChipTone.neutral,
              ),
            if (points > 1)
              StatusChip(
                label: fill(ref.tr('taskx.pointsN'), {'n': points}),
                tone: ChipTone.primary,
              ),
          ],
        ),
      ],
    );
  }

  Widget _actions(
    Map<String, dynamic> perms,
    String status,
    bool evidenceRequired,
    int proofCount,
  ) {
    final buttons = <Widget>[];

    void primary(String label, IconData icon, VoidCallback onTap) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: _busy ? null : onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
        ),
      );
    }

    void secondary(String label, IconData icon, VoidCallback onTap) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _busy ? null : onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
        ),
      );
    }

    if (perms['canAccept'] == true) {
      primary(ref.tr('taskx.accept'), Icons.check, () => _lifecycle('accept'));
    }

    if (perms['canStart'] == true) {
      final label = status == 'paused'
          ? ref.tr('taskx.resume')
          : status == 'changes_requested'
          ? ref.tr('taskx.startAgain')
          : ref.tr('tasks.start');

      primary(
        label,
        Icons.play_arrow_rounded,
        () => _lifecycle('start', successKey: 'tasks.startedSuccessfully'),
      );
    }

    if (perms['canUnblock'] == true) {
      primary(
        ref.tr('taskx.resume'),
        Icons.play_arrow_rounded,
        () => _lifecycle('unblock'),
      );
    }

    if (perms['canSubmit'] == true) {
      primary(
        ref.tr('taskx.submitForReview'),
        Icons.send_rounded,
        () => _openSubmit(evidenceRequired, proofCount),
      );
    }

    if (perms['canPause'] == true) {
      secondary(ref.tr('taskx.pause'), Icons.pause, () => _lifecycle('pause'));
    }

    if (perms['canBlock'] == true) {
      secondary(
        ref.tr('taskx.markBlocked'),
        Icons.report_problem_outlined,
        _openBlock,
      );
    }

    if (buttons.isEmpty) {
      if (status == 'submitted') {
        return FeatureCard(
          child: Text(
            ref.tr('taskx.waitingHint'),
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedColor),
          ),
        );
      }

      return const SizedBox.shrink();
    }

    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  Widget _blockedBanner(Map<String, dynamic> task) {
    final code = task['blockedReasonCode']?.toString();
    final note = task['blockedNote']?.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.saffronTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.saffronLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            code == null ? ref.tr('taskx.st_blocked') : taskBlockReasonLabel(ref, code),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.saffronText,
            ),
          ),
          if (task['blockedAt'] != null)
            Text(
              fill(ref.tr('taskx.stuckSince'), {
                'when': formatTaskDateTime(task['blockedAt']),
              }),
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedColor),
            ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(note, style: GoogleFonts.inter(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _sentBackBanner(Map<String, dynamic> review) {
    final comment = review['comment']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.saffronTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.saffronLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ref.tr('taskx.whatToFix'),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.saffronText,
            ),
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(comment, style: GoogleFonts.inter(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _details(Map<String, dynamic> task) {
    final dueDate = task['dueDate'];
    final dueTime = task['dueTime']?.toString();
    final worked = minutesLabel(task['totalActiveMinutes']);
    final estimate = minutesLabel(task['estimatedMinutes']);
    final original = task['originalDueDate'];

    return FeatureCard(
      child: Column(
        children: [
          InfoRow(
            label: ref.tr('taskx.dueDate'),
            value: dueDate == null
                ? ref.tr('taskx.noDueDate')
                : '${formatApiDate(dueDate)}'
                      '${dueTime != null && dueTime.length >= 5 ? ' ${dueTime.substring(0, 5)}' : ''}',
          ),
          if (original != null && original.toString() != dueDate.toString())
            InfoRow(
              label: ref.tr('taskx.firstDue'),
              value: formatApiDate(original),
            ),
          if ((task['assignedByName']?.toString() ?? '').isNotEmpty)
            InfoRow(
              label: ref.tr('tasks.assignedBy'),
              value: task['assignedByName'].toString(),
            ),
          if ((task['reviewerName']?.toString() ?? '').isNotEmpty)
            InfoRow(
              label: ref.tr('taskx.reviewer'),
              value: task['reviewerName'].toString(),
            ),
          if ((task['category']?.toString() ?? '').isNotEmpty)
            InfoRow(
              label: ref.tr('taskx.category'),
              value: task['category'].toString(),
            ),
          if (estimate != null)
            InfoRow(label: ref.tr('taskx.estimate'), value: estimate),
          InfoRow(label: ref.tr('taskx.timeWorked'), value: worked ?? '—'),
          if (task['submittedAt'] != null)
            InfoRow(
              label: ref.tr('taskx.submittedAt'),
              value: formatTaskDateTime(task['submittedAt']),
            ),
          if (task['completedAt'] != null)
            InfoRow(
              label: ref.tr('taskx.completedAt'),
              value: formatTaskDateTime(task['completedAt']),
            ),
        ],
      ),
    );
  }

  Widget _checklist(List<Map<String, dynamic>> items, bool canTick) {
    final done = items.where((i) => i['isDone'] == true).length;
    final openRequired = items
        .where((i) => i['isRequired'] == true && i['isDone'] != true)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          ref.tr('taskx.checklist'),
          trailing: Text(
            fill(ref.tr('taskx.checklistProgress'), {
              'done': done,
              'total': items.length,
            }),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
          ),
        ),
        const SizedBox(height: 6),
        FeatureCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final item in items)
                CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: item['isDone'] == true,
                  onChanged: !canTick || _busy
                      ? null
                      : (value) {
                          final itemId = toInt(item['id']);

                          if (itemId == null) return;

                          _run(
                            () => _repo.tickChecklist(
                              _id,
                              itemId,
                              value ?? false,
                            ),
                          );
                        },
                  title: Text(
                    item['text']?.toString() ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      decoration: item['isDone'] == true
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: item['isRequired'] == true ||
                          (item['doneByName']?.toString() ?? '').isNotEmpty
                      ? Text(
                          [
                            if (item['isRequired'] == true)
                              ref.tr('taskx.required'),
                            if ((item['doneByName']?.toString() ?? '')
                                .isNotEmpty)
                              fill(ref.tr('taskx.tickedBy'), {
                                'name': item['doneByName'],
                              }),
                          ].join(' · '),
                          style: GoogleFonts.inter(fontSize: 11),
                        )
                      : null,
                ),
            ],
          ),
        ),
        if (openRequired > 0) ...[
          const SizedBox(height: 6),
          Text(
            fill(ref.tr('taskx.requiredOpen'), {'n': openRequired}),
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.saffronText),
          ),
        ],
      ],
    );
  }

  Widget _files(
    List<Map<String, dynamic>> handouts,
    List<Map<String, dynamic>> proofs,
    bool canUpload,
    bool evidenceRequired,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          ref.tr('taskx.files'),
          trailing: canUpload
              ? TextButton.icon(
                  onPressed: _busy ? null : _addProof,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: Text(ref.tr('taskx.addProof')),
                )
              : null,
        ),
        const SizedBox(height: 6),
        if (handouts.isEmpty && proofs.isEmpty)
          Text(
            ref.tr('taskx.noFiles'),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
          ),
        if (handouts.isNotEmpty) ...[
          _fileGroupLabel(ref.tr('taskx.kindAttachment')),
          for (final file in handouts) _fileTile(file, removable: false),
        ],
        if (proofs.isNotEmpty) ...[
          _fileGroupLabel(ref.tr('taskx.kindProof')),
          for (final file in proofs) _fileTile(file, removable: canUpload),
        ],
        if (evidenceRequired && proofs.isEmpty && canUpload) ...[
          const SizedBox(height: 6),
          Text(
            ref.tr('taskx.proofNeeded'),
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.saffronText),
          ),
        ],
      ],
    );
  }

  Widget _fileGroupLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.mutedColor,
        ),
      ),
    );
  }

  Widget _fileTile(Map<String, dynamic> file, {required bool removable}) {
    final attachmentId = toInt(file['id']);
    final isImage = file['isImage'] == true;
    final name = file['originalName']?.toString() ?? '';
    final caption = file['caption']?.toString() ?? '';
    final meta = [
      file['uploadedByName']?.toString() ?? '',
      _sizeLabel(toInt(file['sizeBytes'])),
    ].where((part) => part.isNotEmpty).join(' · ');

    return FeatureCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      onTap: isImage ? () => _previewImage(file) : () => _download(file),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: isImage && attachmentId != null
                  ? _AttachmentImage(taskId: _id, attachmentId: attachmentId)
                  : Container(
                      color: AppColors.saffronTint,
                      child: const Icon(
                        Icons.insert_drive_file_outlined,
                        color: AppColors.saffronText,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.mutedColor,
                    ),
                  ),
                if (caption.isNotEmpty)
                  Text(
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: ref.tr('taskx.download'),
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _download(file),
          ),
          if (removable)
            IconButton(
              tooltip: ref.tr('taskx.removeFile'),
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _busy ? null : () => _removeFile(file),
            ),
        ],
      ),
    );
  }

  Widget _progress(Map<String, dynamic> task, bool editable) {
    final current = (toNum(task['progressPercent']) ?? 0)
        .clamp(0, 100)
        .toDouble();
    final value = _progressDraft ?? current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          ref.tr('taskx.progress'),
          trailing: Text(
            fill(ref.tr('taskx.progressValue'), {'n': value.round()}),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.saffronText,
            ),
          ),
        ),
        if (editable)
          Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${value.round()}%',
            onChanged: _busy
                ? null
                : (next) => setState(() => _progressDraft = next),
            onChangeEnd: (next) async {
              await _run(() => _repo.setProgress(_id, next.round()));

              if (mounted) setState(() => _progressDraft = null);
            },
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 8,
                backgroundColor: AppColors.saffronTint,
                color: AppColors.saffronDeep,
              ),
            ),
          ),
        Text(
          ref.tr('taskx.progressHint'),
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedColor),
        ),
      ],
    );
  }

  Widget _reviews(List<Map<String, dynamic>> reviews) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(ref.tr('taskx.reviewHistory')),
        const SizedBox(height: 6),
        for (final review in reviews)
          FeatureCard(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusChip(
                      label: _decisionLabel(review['decision']?.toString()),
                      tone: _decisionTone(review['decision']?.toString()),
                    ),
                    Text(
                      fill(ref.tr('taskx.attemptN'), {
                        'n': toInt(review['revision']) ?? 1,
                      }),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.mutedColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    review['reviewerName']?.toString() ?? '',
                    formatTaskDateTime(review['decidedAt'], fallback: ''),
                  ].where((part) => part.isNotEmpty).join(' · '),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.mutedColor,
                  ),
                ),
                if ((review['comment']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    review['comment'].toString(),
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  String _decisionLabel(String? decision) {
    switch (decision) {
      case 'approved':
      case 'changes_requested':
      case 'rejected':
        return ref.tr('taskx.decision_$decision');
      default:
        return decision ?? '-';
    }
  }

  ChipTone _decisionTone(String? decision) {
    switch (decision) {
      case 'approved':
        return ChipTone.success;
      case 'rejected':
        return ChipTone.danger;
      default:
        return ChipTone.warning;
    }
  }

  static const _knownEvents = {
    'assigned', 'accept', 'start', 'pause', 'block', 'unblock', 'submit', //
    'approve', 'request_changes', 'reject', 'cancel', 'reopen', 'reassigned',
    'progress', 'rolled_over', 'comment_added', 'proof_added',
    'attachment_added',
  };

  Widget _timeline(List<Map<String, dynamic>> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(ref.tr('taskx.timeline')),
        const SizedBox(height: 6),
        if (events.isEmpty)
          Text(
            ref.tr('taskx.noHistory'),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
          )
        else
          for (var i = 0; i < events.length; i++)
            _timelineRow(events[i], last: i == events.length - 1),
      ],
    );
  }

  Widget _timelineRow(Map<String, dynamic> event, {required bool last}) {
    final key = (event['event']?.toString() ?? '')
        .replaceFirst(RegExp(r'^task\.'), '')
        .replaceAll('.', '_');
    final label = _knownEvents.contains(key)
        ? ref.tr('taskx.event_$key')
        : ref.tr('taskx.event_fallback');
    final note = event['note']?.toString() ?? '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 3),
                decoration: const BoxDecoration(
                  color: AppColors.saffron,
                  shape: BoxShape.circle,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 1.5, color: AppColors.borderColor),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    [
                      event['actorName']?.toString() ?? '',
                      formatTaskDateTime(event['createdAt'], fallback: ''),
                    ].where((part) => part.isNotEmpty).join(' · '),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.mutedColor,
                    ),
                  ),
                  if (note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(note, style: GoogleFonts.inter(fontSize: 12)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessions(List<Map<String, dynamic>> sessions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(ref.tr('taskx.workSessions')),
        const SizedBox(height: 6),
        FeatureCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final session in sessions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    [
                      formatTaskDateTime(session['startedAt'], fallback: ''),
                      minutesLabel(session['activeMinutes']) ??
                          (session['endedAt'] == null
                              ? ref.tr('taskx.running')
                              : ''),
                    ].where((part) => part.isNotEmpty).join(' · '),
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _notes() {
    final comments = ref.watch(taskCommentsProvider(_id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(ref.tr('tasks.notes')),
        const SizedBox(height: 6),
        comments.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, _) => ErrorBanner(cleanErrorMessage(error)),
          data: (list) => list.isEmpty
              ? Text(
                  ref.tr('tasks.noNotes'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedColor,
                  ),
                )
              : Column(
                  children: [
                    for (final comment in list)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              comment['userName']?.toString() ??
                                  ref.tr('tasks.user'),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              comment['body']?.toString() ?? '',
                              style: GoogleFonts.inter(fontSize: 13),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              formatTaskDateTime(comment['createdAt']),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 6),
        _AddNoteField(
          enabled: !_busy,
          onSend: (body) => _run(
            () => _repo.addTaskComment(taskId: _id, body: body),
          ),
        ),
      ],
    );
  }

  static String _sizeLabel(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// An image attachment fetched with the auth header.
class _AttachmentImage extends ConsumerWidget {
  final int taskId;
  final int attachmentId;
  final BoxFit fit;

  const _AttachmentImage({
    required this.taskId,
    required this.attachmentId,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(
      taskAttachmentBytesProvider((taskId: taskId, attachmentId: attachmentId)),
    );

    return bytes.when(
      data: (data) => Image.memory(
        data,
        fit: fit,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.mutedColor),
        ),
      ),
      loading: () => const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => const Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.mutedColor),
      ),
    );
  }
}

class _AddNoteField extends ConsumerStatefulWidget {
  final bool enabled;
  final Future<bool> Function(String body) onSend;

  const _AddNoteField({required this.enabled, required this.onSend});

  @override
  ConsumerState<_AddNoteField> createState() => _AddNoteFieldState();
}

class _AddNoteFieldState extends ConsumerState<_AddNoteField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();

    if (body.isEmpty) return;

    final ok = await widget.onSend(body);

    if (ok && mounted) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 4,
            maxLength: 2000,
            decoration: featureInputDecoration(ref.tr('tasks.addNote')),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: IconButton.filled(
            onPressed: widget.enabled ? _send : null,
            icon: const Icon(Icons.send_rounded),
          ),
        ),
      ],
    );
  }
}
