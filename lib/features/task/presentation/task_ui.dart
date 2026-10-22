import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';

/// Labels, tones and small widgets shared by the task list, the task detail,
/// the history and the performance screens. Mirrors the web's
/// components/tasks/task-status.ts so both apps speak about the lifecycle the
/// same way.

/// Every lifecycle status, as the server sends it.
const List<String> taskStatuses = [
  'pending',
  'accepted',
  'in_progress',
  'paused',
  'blocked',
  'submitted',
  'changes_requested',
  'rejected',
  'completed',
  'cancelled',
];

/// Still the employee's to finish. Work waiting on a reviewer is not here.
const List<String> openTaskStatuses = [
  'pending',
  'accepted',
  'in_progress',
  'paused',
  'blocked',
  'changes_requested',
];

const List<String> terminalTaskStatuses = ['completed', 'cancelled', 'rejected'];

/// The reasons the server accepts for "I'm stuck" (BLOCK_REASONS).
const List<String> taskBlockReasons = [
  'insufficient_time',
  'blocked_by_person',
  'dependency_incomplete',
  'waiting_for_client',
  'waiting_for_approval',
  'requirement_unclear',
  'priority_changed',
  'higher_priority_work',
  'technical_issue',
  'access_issue',
  'employee_absent',
  'unexpected_urgent_work',
  'incorrect_estimate',
  'task_too_large',
  'other',
];

/// The periods the performance and history reports accept.
const List<String> taskPeriods = [
  'overall',
  'week',
  'month',
  'quarter',
  'year',
  'custom',
];

String taskStatusLabel(WidgetRef ref, String status) {
  if (!taskStatuses.contains(status)) return ref.tr('taskx.st_pending');

  return ref.tr('taskx.st_$status');
}

ChipTone taskStatusTone(String status) {
  switch (status) {
    case 'accepted':
    case 'in_progress':
      return ChipTone.info;
    case 'blocked':
    case 'submitted':
    case 'changes_requested':
      return ChipTone.warning;
    case 'rejected':
      return ChipTone.danger;
    case 'completed':
      return ChipTone.success;
    default:
      return ChipTone.neutral;
  }
}

String taskPriorityLabel(WidgetRef ref, String priority) {
  switch (priority.toLowerCase()) {
    case 'high':
      return ref.tr('tasks.priorityHigh');
    case 'urgent':
      return ref.tr('tasks.priorityUrgent');
    case 'low':
      return ref.tr('tasks.priorityLow');
    default:
      return ref.tr('tasks.priorityMedium');
  }
}

ChipTone taskPriorityTone(String priority) {
  switch (priority.toLowerCase()) {
    case 'urgent':
      return ChipTone.danger;
    case 'high':
      return ChipTone.warning;
    case 'medium':
      return ChipTone.info;
    default:
      return ChipTone.neutral;
  }
}

String taskBlockReasonLabel(WidgetRef ref, String code) {
  if (!taskBlockReasons.contains(code)) return code;

  return ref.tr('taskx.block_$code');
}

String taskPeriodLabel(WidgetRef ref, String period) {
  return ref.tr('taskx.period_$period');
}

/// Past its time and still somebody's to finish (submitted is not late).
bool isTaskOverdue(Map<String, dynamic> task) {
  final status = task['status']?.toString() ?? '';
  final due = task['dueDate']?.toString();

  if (due == null || due.isEmpty || !openTaskStatuses.contains(status)) {
    return false;
  }

  final day = due.length >= 10 ? due.substring(0, 10) : due;
  final time = task['dueTime']?.toString();
  final deadline = DateTime.tryParse(
    '${day}T${time == null || time.isEmpty ? '23:59:59' : time}',
  );

  return deadline != null && deadline.isBefore(DateTime.now());
}

/// "2h 15m", or null when nothing was recorded.
String? minutesLabel(dynamic minutes) {
  final m = toInt(minutes) ?? 0;

  if (m <= 0) return null;

  final hours = m ~/ 60;

  return hours > 0 ? '${hours}h ${m % 60}m' : '${m}m';
}

/// "—" for a rate with nothing behind it, never a 0% that reads as failure.
String pctLabel(dynamic value) {
  final n = toNum(value);

  if (n == null) return '—';

  return '${n % 1 == 0 ? n.toInt() : n.toStringAsFixed(1)}%';
}

String formatTaskDateTime(dynamic value, {String fallback = '-'}) {
  final date = parseApiDate(value);

  if (date == null) return fallback;

  return DateFormat('dd MMM yyyy, h:mm a').format(date);
}

/// A horizontal strip of choice chips in the app's pill style.
class TaskChoiceStrip extends StatelessWidget {
  final List<String> values;
  final String selected;
  final String Function(String value) labelOf;
  final ValueChanged<String> onSelected;

  const TaskChoiceStrip({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final value in values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: value == selected ? null : () => onSelected(value),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: value == selected
                        ? AppColors.primaryFillColor
                        : Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: value == selected
                          ? AppColors.primaryFillColor
                          : AppColors.borderColor,
                    ),
                  ),
                  child: Text(
                    labelOf(value),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: value == selected
                          ? Colors.white
                          : AppColors.mutedColor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Period chips plus, for `custom`, two date pickers.
class TaskPeriodPicker extends ConsumerWidget {
  final String period;
  final DateTime from;
  final DateTime to;
  final void Function(String period, DateTime from, DateTime to) onChanged;

  const TaskPeriodPicker({
    super.key,
    required this.period,
    required this.from,
    required this.to,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context, bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? from : to,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );

    if (picked == null) return;

    if (isFrom) {
      onChanged(period, picked, picked.isAfter(to) ? picked : to);
    } else {
      onChanged(period, picked.isBefore(from) ? picked : from, picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = DateFormat('dd MMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskChoiceStrip(
          values: taskPeriods,
          selected: period,
          labelOf: (value) => taskPeriodLabel(ref, value),
          onSelected: (value) => onChanged(value, from, to),
        ),
        if (period == 'custom') ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(context, true),
                  icon: const Icon(Icons.event, size: 16),
                  label: Text(
                    '${ref.tr('taskx.from')}: ${format.format(from)}',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(context, false),
                  icon: const Icon(Icons.event, size: 16),
                  label: Text(
                    '${ref.tr('taskx.to')}: ${format.format(to)}',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
