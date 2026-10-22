import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/task/presentation/task_ui.dart';
import 'package:workforce/features/task/providers/task_record_provider.dart';

/// How I'm doing: the employee's own task report from GET /tasks/performance
/// — completion, on time, points, right first time, carried work, the trend,
/// reviewer scores, time and pace, and breakdowns. Every rate is shown as a
/// dash when there was nothing to measure, never as 0%.
class TaskPerformanceScreen extends ConsumerStatefulWidget {
  const TaskPerformanceScreen({super.key});

  @override
  ConsumerState<TaskPerformanceScreen> createState() =>
      _TaskPerformanceScreenState();
}

class _TaskPerformanceScreenState extends ConsumerState<TaskPerformanceScreen> {
  String _period = 'month';
  DateTime _from = DateTime.now().subtract(const Duration(days: 29));
  DateTime _to = DateTime.now();

  TaskPeriodQuery get _query => (
        period: _period,
        from: _period == 'custom' ? apiDateKey(_from) : null,
        to: _period == 'custom' ? apiDateKey(_to) : null,
      );

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final report = ref.watch(taskPerformanceProvider(query));

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(title: ref.tr('taskx.perfTitle')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(taskPerformanceProvider(query));
          await ref.read(taskPerformanceProvider(query).future).catchError(
                (_) => <String, dynamic>{},
              );
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            FeatureHeading(
              title: ref.tr('taskx.perfTitle'),
              subtitle: ref.tr('taskx.perfSubtitle'),
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
              }),
            ),
            const SizedBox(height: 16),
            ...report.when(
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
                  onRetry: () => ref.invalidate(taskPerformanceProvider(query)),
                ),
              ],
              data: _report,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _report(Map<String, dynamic> data) {
    final totals = asMap(data['totals']);
    final perf = asMap(data['performance']);
    final review = asMap(data['review']);
    final carry = asMap(data['carryForward']);
    final streak = asMap(data['streak']);
    final trend = asMap(data['trend']);

    if ((toInt(totals['assigned']) ?? 0) == 0) {
      return [EmptyNote(ref.tr('taskx.perfEmpty'), icon: Icons.insights)];
    }

    final completionRate = toNum(perf['completionRate']);
    final cancelled = toInt(totals['cancelled']) ?? 0;
    final overdue = toInt(totals['overdue']) ?? 0;
    final withDeadline = toInt(perf['completedWithDeadline']) ?? 0;
    final reviewed = toInt(review['tasksReviewed']) ?? 0;
    final rolloverDays = toInt(carry['rolloverDays']) ?? 0;
    final openCarried = toInt(carry['openCarried']) ?? 0;
    final current = toInt(streak['current']) ?? 0;
    final best = toInt(streak['best']) ?? 0;

    String days(int n) => fill(ref.tr('taskx.nDays'), {'n': n});

    return [
      // Headline: what was asked, and how much of it is done.
      _AccentCard(
        accent: AppColors.saffronDeep,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  pctLabel(completionRate),
                  style: GoogleFonts.inter(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor,
                  ),
                ),
                const Spacer(),
                Text(
                  fill(ref.tr('taskx.ofAssigned'), {
                    'done': toInt(totals['completed']) ?? 0,
                    'total': toInt(totals['countable']) ?? 0,
                  }),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.mutedColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ((completionRate ?? 0) / 100).clamp(0, 1).toDouble(),
                minHeight: 8,
                backgroundColor: AppColors.saffronTint,
                color: AppColors.saffronDeep,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ref.tr('taskx.completionHint'),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            ),
            if (cancelled > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  fill(ref.tr('taskx.cancelledExcluded'), {'n': cancelled}),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.mutedColor,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.25,
        children: [
          _StatCard(
            accent: AppColors.indiaGreen,
            icon: Icons.check_circle_outline,
            label: ref.tr('taskx.onTime'),
            value: pctLabel(perf['onTimeRate']),
            note: withDeadline > 0
                ? fill(ref.tr('taskx.onTimeNote'), {
                    'ok': toInt(perf['completedOnTime']) ?? 0,
                    'total': withDeadline,
                  })
                : ref.tr('taskx.noDeadlines'),
          ),
          _StatCard(
            accent: const Color(0xFF7B4BC8),
            icon: Icons.track_changes,
            label: ref.tr('taskx.points'),
            value: '${toNum(perf['pointsEarned']) ?? 0}',
            note: fill(ref.tr('taskx.pointsNote'), {
              'total': toNum(perf['pointsAssigned']) ?? 0,
            }),
          ),
          _StatCard(
            accent: AppColors.navy,
            icon: Icons.verified_outlined,
            label: ref.tr('taskx.firstPass'),
            value: pctLabel(review['firstPassRate']),
            note: reviewed > 0
                ? fill(ref.tr('taskx.firstPassNote'), {
                    'ok': toInt(review['firstPass']) ?? 0,
                    'total': reviewed,
                  })
                : ref.tr('taskx.noReviewsYet'),
          ),
          _StatCard(
            accent: openCarried > 0
                ? AppColors.saffron
                : AppColors.borderColor,
            icon: Icons.event_repeat,
            label: ref.tr('taskx.carried'),
            value: '$openCarried',
            note: rolloverDays > 0
                ? fill(ref.tr('taskx.carriedNote'), {'days': rolloverDays})
                : ref.tr('taskx.carriedNone'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _Panel(
        title: ref.tr('taskx.trendTitle'),
        hint: ref.tr('taskx.trendHint'),
        child: _TrendChart(points: asMapList(trend['points'])),
      ),
      const SizedBox(height: 12),
      _Panel(
        title: ref.tr('taskx.carryTitle'),
        hint: ref.tr('taskx.carryHint'),
        child: Column(
          children: [
            InfoRow(label: ref.tr('taskx.carryStillOpen'), value: '$openCarried'),
            InfoRow(
              label: ref.tr('taskx.carryFinishedLate'),
              value: '${toInt(carry['completedAfterCarry']) ?? 0}',
            ),
            InfoRow(
              label: ref.tr('taskx.carrySlipDays'),
              value: '$rolloverDays',
            ),
            InfoRow(
              label: ref.tr('taskx.carryWorst'),
              value: (toInt(carry['worstSlipDays']) ?? 0) > 0
                  ? days(toInt(carry['worstSlipDays'])!)
                  : '—',
            ),
            InfoRow(
              label: ref.tr('taskx.carryRate'),
              value: pctLabel(carry['carryRate']),
            ),
            if (overdue > 0) ...[
              const SizedBox(height: 6),
              ErrorBanner(fill(ref.tr('taskx.overdueNow'), {'n': overdue})),
            ],
          ],
        ),
      ),
      if ((toInt(review['decisions']) ?? 0) > 0) ...[
        const SizedBox(height: 12),
        _reviewPanel(review, perf),
      ],
      const SizedBox(height: 12),
      _Panel(
        title: ref.tr('taskx.effortTitle'),
        hint: ref.tr('taskx.effortHint'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoRow(
              label: ref.tr('taskx.timeRecorded'),
              value: minutesLabel(perf['minutesWorked']) ?? '—',
            ),
            InfoRow(
              label: ref.tr('taskx.avgTurnaround'),
              value: perf['avgTurnaroundHours'] == null
                  ? '—'
                  : fill(ref.tr('taskx.nHours'), {
                      'n': toNum(perf['avgTurnaroundHours']),
                    }),
            ),
            InfoRow(
              label: ref.tr('taskx.againstEstimate'),
              value: pctLabel(perf['estimateUsedPercent']),
            ),
            InfoRow(
              label: ref.tr('taskx.avgAttempts'),
              value: perf['avgAttempts'] == null
                  ? '—'
                  : '${toNum(perf['avgAttempts'])}',
            ),
            InfoRow(
              label: ref.tr('taskx.streak'),
              value: current > 0 ? days(current) : '—',
            ),
            InfoRow(
              label: ref.tr('taskx.bestStreak'),
              value: best > 0 ? days(best) : '—',
            ),
            if (current >= 3) ...[
              const SizedBox(height: 6),
              StatusChip(
                label: fill(ref.tr('taskx.streakPraise'), {'n': current}),
                tone: ChipTone.success,
              ),
            ],
          ],
        ),
      ),
      ..._breakdown(
        ref.tr('taskx.byPriority'),
        asMapList(data['byPriority']),
        (key) => key == null
            ? ref.tr('taskx.uncategorised')
            : taskPriorityLabel(ref, key),
      ),
      ..._breakdown(
        ref.tr('taskx.byCategory'),
        asMapList(data['byCategory']),
        (key) => key ?? ref.tr('taskx.uncategorised'),
      ),
      ..._breakdown(
        ref.tr('taskx.byStatus'),
        asMapList(data['byStatus']),
        (key) => taskStatusLabel(ref, key ?? 'pending'),
      ),
      if (asMapList(data['blockers']).isNotEmpty) ...[
        const SizedBox(height: 12),
        _Panel(
          title: ref.tr('taskx.blockersTitle'),
          hint: ref.tr('taskx.blockersHint'),
          child: Column(
            children: [
              for (final row in asMapList(data['blockers']))
                InfoRow(
                  label: taskBlockReasonLabel(
                    ref,
                    row['reasonCode']?.toString() ?? 'other',
                  ),
                  value: '${toInt(row['count']) ?? 0}',
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      Text(
        _footnote(asMap(data['range'])),
        style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedColor),
      ),
    ];
  }

  String _footnote(Map<String, dynamic> range) {
    final to = formatApiDate(range['to']);

    if (range['from'] == null) {
      return fill(ref.tr('taskx.footnoteOverall'), {'to': to});
    }

    return fill(ref.tr('taskx.footnote'), {
      'from': formatApiDate(range['from']),
      'to': to,
    });
  }

  Widget _reviewPanel(Map<String, dynamic> review, Map<String, dynamic> perf) {
    final scores = asMap(review['scores']);
    final overall = toNum(review['overallScore']);
    final rework = toInt(perf['completedAfterRework']) ?? 0;

    Widget tally(String label, int value, Color color) {
      return Expanded(
        child: Column(
          children: [
            Text(
              '$value',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedColor),
            ),
          ],
        ),
      );
    }

    return _Panel(
      title: ref.tr('taskx.reviewTitle'),
      hint: ref.tr('taskx.reviewHint'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              tally(
                ref.tr('taskx.decision_approved'),
                toInt(review['approved']) ?? 0,
                AppColors.indiaGreen,
              ),
              tally(
                ref.tr('taskx.decision_changes_requested'),
                toInt(review['sentBack']) ?? 0,
                AppColors.saffronText,
              ),
              tally(
                ref.tr('taskx.decision_rejected'),
                toInt(review['rejected']) ?? 0,
                const Color(0xFFB3261E),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (overall == null)
            Text(
              ref.tr('taskx.noScores'),
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    ref.tr('taskx.qualityScore'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  fill(ref.tr('taskx.outOfFive'), {'n': overall}),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final key in const [
              'correctness',
              'quality',
              'completeness',
              'timeliness',
              'communication',
            ])
              if (toNum(scores[key]) != null)
                _Meter(
                  label: ref.tr('taskx.score_$key'),
                  value: toNum(scores[key])!.toDouble(),
                  max: 5,
                ),
          ],
          if (rework > 0) ...[
            const SizedBox(height: 8),
            Text(
              fill(ref.tr('taskx.reworkNote'), {'n': rework}),
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedColor),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _breakdown(
    String title,
    List<Map<String, dynamic>> rows,
    String Function(String? key) labelOf,
  ) {
    if (rows.isEmpty) return const [];

    return [
      const SizedBox(height: 12),
      _Panel(
        title: title,
        child: Column(
          children: [
            for (final row in rows)
              _Meter(
                label: labelOf(row['key']?.toString()),
                value: (toInt(row['completed']) ?? 0).toDouble(),
                max: math.max(1, toInt(row['total']) ?? 0).toDouble(),
                caption: fill(ref.tr('taskx.doneOfTotal'), {
                  'done': toInt(row['completed']) ?? 0,
                  'total': toInt(row['total']) ?? 0,
                }),
              ),
          ],
        ),
      ),
    ];
  }
}

// ============================================================================
// PIECES
// ============================================================================

class _AccentCard extends StatelessWidget {
  final Color accent;
  final Widget child;

  const _AccentCard({required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 5, color: accent),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String label;
  final String value;
  final String note;

  const _StatCard({
    required this.accent,
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return _AccentCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.mutedColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.mutedColor),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String? hint;
  final Widget child;

  const _Panel({required this.title, this.hint, required this.child});

  @override
  Widget build(BuildContext context) {
    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: GoogleFonts.inter(
                fontSize: 11,
                height: 1.35,
                color: AppColors.mutedColor,
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final String? caption;

  const _Meter({
    required this.label,
    required this.value,
    required this.max,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: GoogleFonts.inter(fontSize: 12)),
              ),
              Text(
                caption ?? value.toStringAsFixed(1),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: max <= 0 ? 0 : (value / max).clamp(0, 1).toDouble(),
              minHeight: 6,
              backgroundColor: AppColors.saffronTint,
              color: AppColors.saffronDeep,
            ),
          ),
        ],
      ),
    );
  }
}

/// Paired bars per bucket: pale = what it was carrying, solid = finished.
class _TrendChart extends ConsumerWidget {
  final List<Map<String, dynamic>> points;

  const _TrendChart({required this.points});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (points.isEmpty ||
        points.every(
          (p) => (toInt(p['assigned']) ?? 0) == 0 &&
              (toInt(p['completed']) ?? 0) == 0,
        )) {
      return Text(
        ref.tr('taskx.noTrend'),
        style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
      );
    }

    final peak = points.fold<int>(1, (m, p) {
      return math.max(
        m,
        math.max(toInt(p['assigned']) ?? 0, toInt(p['completed']) ?? 0),
      );
    });

    const height = 120.0;
    final format = DateFormat('d MMM');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height + 22,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            reverse: true,
            itemCount: points.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final point = points[points.length - 1 - index];
              final owed = toInt(point['assigned']) ?? 0;
              final done = toInt(point['completed']) ?? 0;
              final date = parseApiDate(point['date']);

              return Tooltip(
                message: fill(ref.tr('taskx.trendTooltip'), {
                  'date': date == null ? '' : format.format(date),
                  'owed': owed,
                  'done': done,
                }),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _bar(owed / peak * height, AppColors.saffronLight),
                        const SizedBox(width: 2),
                        _bar(done / peak * height, AppColors.saffronDeep),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date == null ? '' : format.format(date),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: AppColors.mutedColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _legend(AppColors.saffronLight, ref.tr('taskx.legendOwed')),
            const SizedBox(width: 14),
            _legend(AppColors.saffronDeep, ref.tr('taskx.legendDone')),
          ],
        ),
      ],
    );
  }

  Widget _bar(double h, Color color) {
    return Container(
      width: 9,
      height: math.max(2, h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 11)),
      ],
    );
  }
}
