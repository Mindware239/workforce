import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/task/presentation/task_ui.dart';
import 'package:workforce/features/task/providers/task_record_provider.dart';

/// My record: every task I have been given and how it turned out — on time
/// or late against its first deadline, how many days it moved, how many
/// tries it took and what the reviewer said. GET /tasks/history.
class TaskHistoryScreen extends ConsumerStatefulWidget {
  const TaskHistoryScreen({super.key});

  @override
  ConsumerState<TaskHistoryScreen> createState() => _TaskHistoryScreenState();
}

const List<String> _outcomes = [
  '',
  'completed',
  'on_time',
  'late',
  'carried',
  'rework',
  'open',
  'closed',
];

class _TaskHistoryScreenState extends ConsumerState<TaskHistoryScreen> {
  String _period = 'overall';
  DateTime _from = DateTime.now().subtract(const Duration(days: 89));
  DateTime _to = DateTime.now();
  String _outcome = '';
  int _page = 1;

  TaskHistoryQuery get _query => (
        period: _period,
        from: _period == 'custom' ? apiDateKey(_from) : null,
        to: _period == 'custom' ? apiDateKey(_to) : null,
        outcome: _outcome.isEmpty ? null : _outcome,
        page: _page,
      );

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final history = ref.watch(taskHistoryProvider(query));

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(title: ref.tr('taskx.historyTitle')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(taskHistoryProvider(query));
          await ref.read(taskHistoryProvider(query).future).catchError(
                (_) => <String, dynamic>{},
              );
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            FeatureHeading(
              title: ref.tr('taskx.historyTitle'),
              subtitle: ref.tr('taskx.historySubtitle'),
            ),
            const SizedBox(height: 14),
            TaskPeriodPicker(
              period: _period,
              from: _from,
              to: _to,
              onChanged: (period, from, to) => setState(() {
                _period = period;
                _from = from;
                _to = to;
                _page = 1;
              }),
            ),
            const SizedBox(height: 10),
            TaskChoiceStrip(
              values: _outcomes,
              selected: _outcome,
              labelOf: (value) => value.isEmpty
                  ? ref.tr('tasks.all')
                  : ref.tr('taskx.outcome_$value'),
              onSelected: (value) => setState(() {
                _outcome = value;
                _page = 1;
              }),
            ),
            const SizedBox(height: 14),
            ...history.when(
              loading: () => [
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (error, _) => [
                LoadErrorView(
                  message: cleanErrorMessage(error),
                  retryLabel: ref.tr('common.retry'),
                  onRetry: () => ref.invalidate(taskHistoryProvider(query)),
                ),
              ],
              data: (data) => _list(data),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _list(Map<String, dynamic> data) {
    final items = asMapList(data['items']);
    final total = toInt(data['total']) ?? 0;
    final lastPage = (total / taskHistoryPageSize).ceil().clamp(1, 1 << 30);

    if (items.isEmpty) {
      return [
        EmptyNote(ref.tr('taskx.historyEmpty'), icon: Icons.history),
      ];
    }

    return [
      Text(
        fill(ref.tr('taskx.taskCount'), {'n': total}),
        style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
      ),
      const SizedBox(height: 8),
      for (final item in items) _HistoryRow(item: item),
      if (lastPage > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: _page <= 1 ? null : () => setState(() => _page--),
                child: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  fill(ref.tr('taskx.pageOf'), {
                    'page': _page,
                    'total': lastPage,
                  }),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedColor,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: _page >= lastPage
                    ? null
                    : () => setState(() => _page++),
                child: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
    ];
  }
}

class _HistoryRow extends ConsumerWidget {
  final Map<String, dynamic> item;

  const _HistoryRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = toInt(item['id']);
    final status = item['status']?.toString() ?? 'pending';
    final priority = item['priority']?.toString() ?? 'medium';
    final onTime = item['onTime'];
    final rollover = toInt(item['rolloverCount']) ?? 0;
    final revision = toInt(item['revision']) ?? 1;
    final points = toInt(item['weightPoints']) ?? 1;
    final decision = item['lastDecision']?.toString();
    final comment = item['lastComment']?.toString() ?? '';
    final score = toNum(item['averageScore']);
    final category = item['category']?.toString() ?? '';

    final accent = onTime == true
        ? AppColors.indiaGreen
        : onTime == false
        ? const Color(0xFFB3261E)
        : status == 'completed'
        ? AppColors.navy
        : AppColors.borderColor;

    final meta = [
      fill(ref.tr('taskx.owedOn'), {'date': formatApiDate(item['anchorDate'])}),
      if (item['completedAt'] != null)
        fill(ref.tr('taskx.finishedOn'), {
          'date': formatApiDate(item['completedAt']),
        }),
      if (category.isNotEmpty) category,
      ?minutesLabel(item['totalActiveMinutes']),
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: id == null
            ? null
            : () => context.push(AppRoutes.taskDetailPath(id)),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item['title']?.toString() ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textColor,
                              ),
                            ),
                          ),
                          if (points > 1)
                            Text(
                              fill(ref.tr('taskx.pointsN'), {'n': points}),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.mutedColor,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          StatusChip(
                            label: taskStatusLabel(ref, status),
                            tone: taskStatusTone(status),
                          ),
                          if (onTime == true)
                            StatusChip(
                              label: ref.tr('taskx.onTime'),
                              tone: ChipTone.success,
                            ),
                          if (onTime == false)
                            StatusChip(
                              label: ref.tr('taskx.late'),
                              tone: ChipTone.danger,
                            ),
                          if (rollover > 0)
                            StatusChip(
                              label: fill(ref.tr('taskx.movedTimes'), {
                                'n': rollover,
                              }),
                              tone: ChipTone.warning,
                            ),
                          if (revision > 1)
                            StatusChip(
                              label: fill(ref.tr('taskx.attemptN'), {
                                'n': revision,
                              }),
                              tone: ChipTone.neutral,
                            ),
                          if (priority == 'high' || priority == 'urgent')
                            StatusChip(
                              label: taskPriorityLabel(ref, priority),
                              tone: taskPriorityTone(priority),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        meta,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.mutedColor,
                        ),
                      ),
                      if (decision != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          [
                            ref.tr('taskx.decision_$decision'),
                            if ((item['reviewerName']?.toString() ?? '')
                                .isNotEmpty)
                              item['reviewerName'].toString(),
                            if (score != null)
                              fill(ref.tr('taskx.outOfFive'), {
                                'n': score.toStringAsFixed(1),
                              }),
                          ].join(' · '),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: decision == 'approved'
                                ? AppColors.indiaGreen
                                : decision == 'rejected'
                                ? const Color(0xFFB3261E)
                                : AppColors.saffronText,
                          ),
                        ),
                      ],
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 4),
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
                            comment,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.mutedColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
