import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/floor/providers/floor_provider.dart';
import 'package:workforce/features/operations/presentation/ops_ui.dart';
import 'package:workforce/features/operations/providers/entitlements_provider.dart';

/// The production floor, for the person doing the work: the steps assigned
/// to me, each with its order, target and progress. Start the clock, record
/// what came off the machine, or hand the rest over when the shift ends.
/// Mirrors the web page /employee/floor.
class FloorScreen extends ConsumerStatefulWidget {
  const FloorScreen({super.key});

  @override
  ConsumerState<FloorScreen> createState() => _FloorScreenState();
}

const _closedStatuses = ['completed', 'cancelled', 'rejected'];

/// Work-order states in which output may be recorded.
const _outputStatuses = [
  'IN_PROGRESS',
  'PAUSED',
  'HANDOVER_PENDING',
  'ASSIGNED',
  'READY',
];

String _statusKey(String? status) {
  switch (status) {
    case 'in_progress':
      return 'floor.statusRunning';
    case 'paused':
      return 'floor.statusPaused';
    case 'blocked':
      return 'floor.statusBlocked';
    case 'submitted':
    case 'completed':
      return 'floor.statusDone';
    case 'cancelled':
    case 'rejected':
      return 'floor.statusCancelled';
    default:
      return 'floor.statusPending';
  }
}

class _FloorScreenState extends ConsumerState<FloorScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(_load);
  }

  Future<void> _load() async {
    final features = await ref
        .read(entitlementsProvider.future)
        .then<Map<String, bool>?>((v) => v)
        .catchError((_) => null);

    // Locked on the plan: the web does not even ask.
    if (features != null && features[productionFeature] != true) return;

    if (!mounted) return;

    await ref.read(floorProvider.notifier).load();
  }

  Future<void> _refresh() async {
    ref.invalidate(entitlementsProvider);

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final entitlements = ref.watch(entitlementsProvider);
    final locked = featureLocked(entitlements, productionFeature);
    final state = ref.watch(floorProvider);

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              FeatureHeading(
                title: ref.tr('floor.title'),
                subtitle: ref.tr('floor.subtitle'),
              ),
              const SizedBox(height: 16),
              if (locked)
                FeatureLockedPanel(featureName: ref.tr('floor.featureName'))
              else
                ..._buildBody(state),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody(FloorState state) {
    if (!state.loaded || (state.isLoading && state.tasks.isEmpty)) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (state.error != null) {
      return [
        NoteBanner(ref.tr('floor.unavailable')),
        const SizedBox(height: 8),
        Text(
          state.error!,
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedColor),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(ref.tr('common.retry')),
          ),
        ),
      ];
    }

    if (state.tasks.isEmpty) {
      return [
        EmptyNote(
          '${ref.tr('floor.nothingAssigned')}\n'
          '${ref.tr('floor.nothingAssignedHint')}',
          icon: Icons.precision_manufacturing_outlined,
        ),
      ];
    }

    return state.tasks
        .map((task) => _FloorTaskCard(task: task, busy: state.busyTaskId))
        .toList();
  }
}

class _FloorTaskCard extends ConsumerWidget {
  final Map<String, dynamic> task;
  final int? busy;

  const _FloorTaskCard({required this.task, required this.busy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskId = toInt(task['taskId']) ?? 0;
    final status = task['status']?.toString();
    final running = status == 'in_progress';
    final closed = _closedStatuses.contains(status);
    final waitingHandover = task['openHandoverId'] != null;
    final unit = task['unitCode']?.toString();
    final completed = toNum(task['completedQuantity']) ?? 0;
    final target = toNum(task['targetQuantity']);
    final pct = target != null && target > 0
        ? ((completed / target) * 100).round().clamp(0, 100)
        : (toNum(task['progressPercent']) ?? 0).round().clamp(0, 100);
    final canOutput =
        _outputStatuses.contains(task['workOrderStatus']?.toString());
    final isBusy = busy == taskId;

    final tone = running
        ? ChipTone.success
        : status == 'paused'
            ? ChipTone.warning
            : closed
                ? ChipTone.neutral
                : ChipTone.info;

    final sequence = toInt(task['sequenceNumber']);
    final stepName = task['stepName']?.toString() ?? task['title']?.toString();
    final workCenter = task['workCenterName']?.toString();

    return FeatureCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OpsCaption(
                      '${task['workOrderNumber'] ?? ''}'
                      '${workCenter != null && workCenter.isNotEmpty ? ' · $workCenter' : ''}',
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sequence != null && sequence > 0 ? '$sequence. ' : ''}'
                      '${stepName ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textColor,
                      ),
                    ),
                    Text(
                      '${task['productName'] ?? ''} · ${task['variantName'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(label: ref.tr(_statusKey(status)), tone: tone),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatQty(completed),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textColor,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '/ ${formatQty(target ?? task['requiredQuantity'], unit)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedColor,
                  ),
                ),
              ),
              Text(
                fill(ref.tr('floor.timeOnTask'), {
                  'time': formatMinutes(task['totalActiveMinutes']),
                }),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.mutedColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F1F3),
              color: AppColors.saffronDeep,
            ),
          ),
          if (waitingHandover) ...[
            const SizedBox(height: 12),
            NoteBanner(
              ref.tr('floor.handoverWaiting'),
              tone: NoteTone.warning,
            ),
          ],
          if (!closed && !waitingHandover) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: running
                      ? OutlinedButton.icon(
                          onPressed: isBusy
                              ? null
                              : () => _clock(context, ref, taskId, false),
                          icon: isBusy
                              ? const ButtonSpinner(
                                  color: AppColors.saffronText,
                                )
                              : const Icon(Icons.pause, size: 18),
                          label: Text(ref.tr('floor.pause')),
                        )
                      : ElevatedButton.icon(
                          onPressed: isBusy
                              ? null
                              : () => _clock(context, ref, taskId, true),
                          icon: isBusy
                              ? const ButtonSpinner()
                              : const Icon(Icons.play_arrow, size: 18),
                          label: Text(
                            ref.tr(
                              status == 'paused'
                                  ? 'floor.resume'
                                  : 'floor.start',
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: running
                      ? ElevatedButton.icon(
                          onPressed: canOutput
                              ? () => _openOutput(context, ref, task)
                              : null,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(ref.tr('floor.output')),
                        )
                      : OutlinedButton.icon(
                          onPressed: canOutput
                              ? () => _openOutput(context, ref, task)
                              : null,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(ref.tr('floor.output')),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _openHandover(context, ref, task),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text(ref.tr('floor.handOver')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _clock(
    BuildContext context,
    WidgetRef ref,
    int taskId,
    bool start,
  ) async {
    final notifier = ref.read(floorProvider.notifier);
    final error =
        start ? await notifier.start(taskId) : await notifier.pause(taskId);

    if (!context.mounted) return;

    showFeatureSnack(
      context,
      error ?? ref.tr(start ? 'floor.started' : 'floor.paused'),
    );
  }

  Future<void> _openOutput(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> task,
  ) async {
    final done = await showOpsSheet<bool>(
      context,
      title: ref.tr('floor.recordOutputTitle'),
      description:
          '${task['workOrderNumber'] ?? ''} · ${task['stepName'] ?? task['title'] ?? ''}',
      builder: (_) => _OutputForm(task: task),
    );

    if (done == true && context.mounted) {
      showFeatureSnack(context, ref.tr('floor.outputRecorded'));
    }
  }

  Future<void> _openHandover(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> task,
  ) async {
    final completed = toNum(task['completedQuantity']) ?? 0;
    final target = toNum(task['targetQuantity']);
    final remaining =
        target == null ? null : (target - completed).clamp(0, double.infinity);

    final done = await showOpsSheet<bool>(
      context,
      title: ref.tr('floor.handOverTitle'),
      description: fill(ref.tr('floor.handOverHint'), {
        'qty': remaining == null
            ? '—'
            : formatQty(remaining, task['unitCode']?.toString()),
      }),
      builder: (_) => _HandoverForm(task: task),
    );

    if (done == true && context.mounted) {
      showFeatureSnack(context, ref.tr('floor.handoverSent'));
    }
  }
}

// ============================================================================
// RECORD OUTPUT
// ============================================================================

class _OutputForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> task;

  const _OutputForm({required this.task});

  @override
  ConsumerState<_OutputForm> createState() => _OutputFormState();
}

class _OutputFormState extends ConsumerState<_OutputForm> {
  final _good = TextEditingController();
  final _rejected = TextEditingController();
  final _waste = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _good.dispose();
    _rejected.dispose();
    _waste.dispose();
    _notes.dispose();
    super.dispose();
  }

  num _n(TextEditingController c) => parseQty(c.text) ?? 0;

  num get _total => _n(_good) + _n(_rejected) + _n(_waste);

  Future<void> _save() async {
    final notes = _notes.text.trim();

    final error = await ref.read(floorProvider.notifier).recordOutput(
          workOrderId: toInt(widget.task['workOrderId']) ?? 0,
          workOrderStatus: widget.task['workOrderStatus']?.toString() ?? '',
          good: _n(_good),
          rejected: _n(_rejected),
          waste: _n(_waste),
          notes: notes.isEmpty ? null : notes,
        );

    if (!mounted) return;

    if (error != null) {
      showFeatureSnack(context, error);
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(floorProvider.select((s) => s.isSaving));
    final unit = (widget.task['unitCode']?.toString() ?? '').toLowerCase();
    const keyboard = TextInputType.numberWithOptions(decimal: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _good,
          autofocus: true,
          keyboardType: keyboard,
          onChanged: (_) => setState(() {}),
          decoration: featureInputDecoration(
            fill(ref.tr('floor.goodQty'), {'unit': unit}),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _rejected,
                keyboardType: keyboard,
                onChanged: (_) => setState(() {}),
                decoration: featureInputDecoration(ref.tr('floor.rejectedQty')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _waste,
                keyboardType: keyboard,
                onChanged: (_) => setState(() {}),
                decoration: featureInputDecoration(ref.tr('floor.wasteQty')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 3,
          decoration: featureInputDecoration(ref.tr('floor.notes')),
        ),
        if (widget.task['requiresQc'] == true) ...[
          const SizedBox(height: 10),
          Text(
            ref.tr('floor.qcNote'),
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedColor),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(context).pop(),
              child: Text(ref.tr('common.cancel')),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: saving || !(_total > 0) ? null : _save,
              child: saving
                  ? const ButtonSpinner()
                  : Text(ref.tr('floor.save')),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// HAND OVER
// ============================================================================

class _HandoverForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> task;

  const _HandoverForm({required this.task});

  @override
  ConsumerState<_HandoverForm> createState() => _HandoverFormState();
}

class _HandoverFormState extends ConsumerState<_HandoverForm> {
  final _reason = TextEditingController();
  int? _suggested;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final error = await ref.read(floorProvider.notifier).requestHandover(
          taskId: toInt(widget.task['taskId']) ?? 0,
          reason: _reason.text.trim(),
          suggestedUserId: _suggested,
        );

    if (!mounted) return;

    if (error != null) {
      showFeatureSnack(context, error);
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(floorProvider.select((s) => s.isSaving));
    final colleagues =
        ref.watch(floorColleaguesProvider).valueOrNull ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _reason,
          autofocus: true,
          minLines: 3,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: featureInputDecoration(
            ref.tr('floor.handoverReason'),
            hint: ref.tr('floor.handoverReasonPlaceholder'),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          initialValue: _suggested,
          isExpanded: true,
          decoration: featureInputDecoration(ref.tr('floor.suggestColleague')),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(ref.tr('floor.letManagerDecide')),
            ),
            for (final user in colleagues)
              if (toInt(user['id']) != null)
                DropdownMenuItem<int?>(
                  value: toInt(user['id']),
                  child: Text(
                    user['fullName']?.toString() ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
          ],
          onChanged: (value) => setState(() => _suggested = value),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.precision_manufacturing_outlined,
              size: 14,
              color: AppColors.mutedColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                ref.tr('floor.handoverNote'),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.mutedColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(context).pop(),
              child: Text(ref.tr('common.cancel')),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: saving || _reason.text.trim().length < 3 ? null : _send,
              child: saving
                  ? const ButtonSpinner()
                  : Text(ref.tr('floor.sendHandover')),
            ),
          ],
        ),
      ],
    );
  }
}
