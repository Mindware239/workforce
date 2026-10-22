import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/reviews/data/review_repository.dart';
import 'package:workforce/features/reviews/presentation/review_ui.dart';
import 'package:workforce/features/reviews/providers/review_provider.dart';

/// One review, for the employee or their manager. What can be edited comes
/// from the server's `permissions`; the screen only decides how to show it.
///
/// Employee: goals (add/edit/delete while draft, weights must total 100,
/// submit), the self review (rate each goal 1–5 + comment, overall comment,
/// submit locks it), then the result once finalized, and acknowledge.
/// Manager: approve / reopen goals, and the manager review (ratings, overall
/// rating, strengths, improvements, recommendation).
class ReviewDetailScreen extends ConsumerWidget {
  final int reviewId;

  const ReviewDetailScreen({super.key, required this.reviewId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reviewDetailProvider(reviewId));
    final notifier = ref.read(reviewDetailProvider(reviewId).notifier);
    final view = state.view;

    Widget body;

    if (view == null && state.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (view == null) {
      body = ListView(
        children: [
          LoadErrorView(
            message: state.loadError ?? ref.tr('reviews.couldNotLoad'),
            retryLabel: ref.tr('common.retry'),
            onRetry: notifier.load,
          ),
        ],
      );
    } else {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _HeaderCard(view: view),
          const SizedBox(height: 12),
          _GoalsCard(reviewId: reviewId, view: view, busy: state.busy),
          const SizedBox(height: 12),
          _SelfSection(reviewId: reviewId, view: view, busy: state.busy),
          if (!view.isEmployee) ...[
            const SizedBox(height: 12),
            _ManagerSection(reviewId: reviewId, view: view, busy: state.busy),
          ],
          const SizedBox(height: 12),
          _ResultSection(reviewId: reviewId, view: view, busy: state.busy),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(
        title: view?.review['cycleName']?.toString() ?? ref.tr('reviews.title'),
      ),
      body: SafeArea(
        child: RefreshIndicator(onRefresh: notifier.load, child: body),
      ),
    );
  }
}

/// Shows the error of a write, if any.
void _report(BuildContext context, String? failure, String success) {
  if (!context.mounted) return;

  showFeatureSnack(context, failure ?? success);
}

Widget _busySpinner() => const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );

// ============================================================================
// HEADER
// ============================================================================

class _HeaderCard extends ConsumerWidget {
  final ReviewView view;

  const _HeaderCard({required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = view.review;
    final stage = r['stage']?.toString();
    final stageIndex = reviewStages.indexOf(stage ?? '');

    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!view.isEmployee) ...[
            Text(
              r['fullName']?.toString() ?? '-',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textColor,
              ),
            ),
            Text(
              [r['employeeCode'], r['designation'], r['department']]
                  .where((v) => v != null && v.toString().isNotEmpty)
                  .join(' · '),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                r['cycleName']?.toString() ?? '-',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor,
                ),
              ),
              ReviewStageChip(stage: stage),
              if (r['cycleStatus'] == 'closed')
                StatusChip(
                  label: ref.tr('reviews.cycleClosed'),
                  tone: ChipTone.neutral,
                ),
            ],
          ),
          const SizedBox(height: 6),
          InfoRow(
            label: ref.tr('reviews.period'),
            value: '${formatApiDate(r['periodStart'])} – '
                '${formatApiDate(r['periodEnd'])}',
          ),
          InfoRow(
            label: ref.tr('reviews.manager'),
            value: r['managerName']?.toString() ?? ref.tr('reviews.noManager'),
          ),
          InfoRow(
            label: ref.tr('reviews.selfDue'),
            value: formatApiDate(r['selfReviewDue']),
          ),
          InfoRow(
            label: ref.tr('reviews.managerDue'),
            value: formatApiDate(r['managerReviewDue']),
          ),
          const SizedBox(height: 8),
          // Progress through the stages.
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < reviewStages.length; i++)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: i <= stageIndex
                        ? AppColors.indiaGreenLight
                        : const Color(0xFFF1F1F3),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        i <= stageIndex
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 12,
                        color: i <= stageIndex
                            ? AppColors.indiaGreen
                            : AppColors.mutedColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ref.tr('reviews.stage_${reviewStages[i]}'),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: i <= stageIndex
                              ? AppColors.indiaGreen
                              : AppColors.mutedColor,
                        ),
                      ),
                    ],
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
// GOALS
// ============================================================================

class _GoalsCard extends ConsumerWidget {
  final int reviewId;
  final ReviewView view;
  final String? busy;

  const _GoalsCard({
    required this.reviewId,
    required this.view,
    required this.busy,
  });

  Future<void> _editGoal(
    BuildContext context,
    WidgetRef ref, [
    Map<String, dynamic>? goal,
  ]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GoalForm(reviewId: reviewId, goal: goal),
    );

    if (saved == true && context.mounted) {
      showFeatureSnack(context, ref.tr('reviews.goalSaved'));
    }
  }

  Future<void> _removeGoal(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> goal,
  ) async {
    final goalId = toInt(goal['id']);

    if (goalId == null) return;

    final confirmed = await confirmAction(
      context,
      title: ref.tr('reviews.removeGoal'),
      message: fill(ref.tr('reviews.removeGoalConfirm'), {
        'goal': goal['title'],
      }),
      confirmLabel: ref.tr('common.delete'),
      cancelLabel: ref.tr('common.cancel'),
      destructive: true,
    );

    if (!confirmed || !context.mounted) return;

    final failure = await ref
        .read(reviewDetailProvider(reviewId).notifier)
        .removeGoal(goalId);

    if (context.mounted) _report(context, failure, ref.tr('reviews.goalRemoved'));
  }

  Future<void> _submitGoals(BuildContext context, WidgetRef ref) async {
    if (view.goals.isEmpty || !view.weightsBalanced) {
      showFeatureSnack(context, ref.tr('reviews.weightsMustBe100'));
      return;
    }

    final confirmed = await confirmAction(
      context,
      title: ref.tr('reviews.submitGoals'),
      message: ref.tr('reviews.submitGoalsMessage'),
      confirmLabel: ref.tr('reviews.submit'),
      cancelLabel: ref.tr('common.cancel'),
    );

    if (!confirmed || !context.mounted) return;

    final failure = await ref
        .read(reviewDetailProvider(reviewId).notifier)
        .submitGoals();

    if (context.mounted) {
      _report(context, failure, ref.tr('reviews.goalsSubmittedToast'));
    }
  }

  Future<void> _approveGoals(BuildContext context, WidgetRef ref) async {
    if (view.goals.isEmpty || !view.weightsBalanced) {
      showFeatureSnack(context, ref.tr('reviews.weightsMustBe100'));
      return;
    }

    final failure = await ref
        .read(reviewDetailProvider(reviewId).notifier)
        .approveGoals();

    if (context.mounted) {
      _report(context, failure, ref.tr('reviews.goalsApprovedToast'));
    }
  }

  Future<void> _reopenGoals(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmAction(
      context,
      title: ref.tr('reviews.reopenGoals'),
      message: ref.tr('reviews.reopenGoalsMessage'),
      confirmLabel: ref.tr('reviews.reopenGoals'),
      cancelLabel: ref.tr('common.cancel'),
    );

    if (!confirmed || !context.mounted) return;

    final failure = await ref
        .read(reviewDetailProvider(reviewId).notifier)
        .reopenGoals();

    if (context.mounted) {
      _report(context, failure, ref.tr('reviews.goalsReopenedToast'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = view.can('canEditGoals');
    final goalsStatus = view.review['goalsStatus']?.toString() ?? 'draft';
    final total = view.weightTotal;

    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            ref.tr('reviews.goalsTitle'),
            trailing: StatusChip(
              label: fill(ref.tr('reviews.weightTotal'), {
                'total': total % 1 == 0 ? total.toInt() : total,
              }),
              tone: view.weightsBalanced ? ChipTone.success : ChipTone.warning,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ref.tr('reviews.goalsStatus_$goalsStatus'),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
          ),
          const SizedBox(height: 10),
          if (view.goals.isEmpty)
            Text(
              ref.tr('reviews.noGoals'),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.mutedColor,
              ),
            ),
          for (final goal in view.goals)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySurfaceTintColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal['title']?.toString() ?? '-',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textColor,
                          ),
                        ),
                        if ((goal['description']?.toString() ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              goal['description'].toString(),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.mutedColor,
                              ),
                            ),
                          ),
                        if ((goal['target']?.toString() ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              fill(ref.tr('reviews.targetLabel'), {
                                'target': goal['target'],
                              }),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  StatusChip(
                    label: fill(ref.tr('reviews.weightOf'), {
                      'weight': _weightText(goal['weight']),
                    }),
                    tone: ChipTone.info,
                  ),
                  if (canEdit) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: ref.tr('reviews.editGoal'),
                      onPressed: busy != null
                          ? null
                          : () => _editGoal(context, ref, goal),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppColors.navy,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: ref.tr('reviews.removeGoal'),
                      onPressed: busy != null
                          ? null
                          : () => _removeGoal(context, ref, goal),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Color(0xFFB3261E),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (canEdit && !view.weightsBalanced && view.goals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                ref.tr('reviews.weightsMustBe100'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.saffronText,
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canEdit && view.goals.length < 20)
                OutlinedButton.icon(
                  onPressed:
                      busy != null ? null : () => _editGoal(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(ref.tr('reviews.addGoal')),
                ),
              if (view.can('canSubmitGoals'))
                ElevatedButton.icon(
                  onPressed: busy != null
                      ? null
                      : () => _submitGoals(context, ref),
                  icon: busy == 'submitGoals'
                      ? _busySpinner()
                      : const Icon(Icons.send_outlined, size: 18),
                  label: Text(ref.tr('reviews.submitGoals')),
                ),
              if (view.can('canApproveGoals'))
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.indiaGreen,
                  ),
                  onPressed: busy != null
                      ? null
                      : () => _approveGoals(context, ref),
                  icon: busy == 'approveGoals'
                      ? _busySpinner()
                      : const Icon(Icons.check, size: 18),
                  label: Text(ref.tr('reviews.approveGoals')),
                ),
              if (view.can('canReopenGoals'))
                OutlinedButton.icon(
                  onPressed: busy != null
                      ? null
                      : () => _reopenGoals(context, ref),
                  icon: busy == 'reopenGoals'
                      ? _busySpinner()
                      : const Icon(Icons.lock_open_outlined, size: 18),
                  label: Text(ref.tr('reviews.reopenGoals')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _weightText(dynamic weight) {
  final value = toNum(weight);

  if (value == null) return '-';

  return value % 1 == 0 ? value.toInt().toString() : value.toString();
}

class _GoalForm extends ConsumerStatefulWidget {
  final int reviewId;
  final Map<String, dynamic>? goal;

  const _GoalForm({required this.reviewId, this.goal});

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _target;
  late final TextEditingController _weight;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final goal = widget.goal;

    _title = TextEditingController(text: goal?['title']?.toString() ?? '');
    _description =
        TextEditingController(text: goal?['description']?.toString() ?? '');
    _target = TextEditingController(text: goal?['target']?.toString() ?? '');
    _weight = TextEditingController(
      text: goal == null ? '' : _weightText(goal['weight']),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _target.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final weight = num.tryParse(_weight.text.trim());

    if (title.isEmpty) {
      setState(() => _error = ref.tr('reviews.errGoalTitle'));
      return;
    }

    if (weight == null || weight <= 0 || weight > 100) {
      setState(() => _error = ref.tr('reviews.errGoalWeight'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = <String, dynamic>{
      'title': title,
      'description':
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      'target': _target.text.trim().isEmpty ? null : _target.text.trim(),
      'weight': weight,
    };

    final notifier = ref.read(reviewDetailProvider(widget.reviewId).notifier);
    final goalId = toInt(widget.goal?['id']);

    final failure = goalId == null
        ? await notifier.addGoal(payload)
        : await notifier.updateGoal(goalId, payload);

    if (!mounted) return;

    if (failure == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.goal == null
                  ? ref.tr('reviews.addGoal')
                  : ref.tr('reviews.editGoal'),
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textColor,
              ),
            ),
            const SizedBox(height: 14),
            if (_error != null) ...[
              ErrorBanner(_error!),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _title,
              maxLength: 200,
              decoration: featureInputDecoration(ref.tr('reviews.goalTitle')),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              maxLength: 4000,
              decoration:
                  featureInputDecoration(ref.tr('reviews.goalDescription')),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _target,
                    maxLength: 500,
                    decoration:
                        featureInputDecoration(ref.tr('reviews.goalTarget')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _weight,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d{0,3}\.?\d{0,2}'),
                      ),
                    ],
                    decoration: featureInputDecoration(
                      ref.tr('reviews.goalWeight'),
                    ).copyWith(suffixText: '%'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? _busySpinner()
                    : Text(ref.tr('reviews.saveGoal')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GOAL RATING ROWS (self + manager forms)
// ============================================================================

class _RatingEntry {
  int? rating;
  final TextEditingController comment;

  _RatingEntry(this.rating, String? comment)
      : comment = TextEditingController(text: comment ?? '');
}

class _GoalRatingTile extends ConsumerWidget {
  final Map<String, dynamic> goal;
  final _RatingEntry entry;
  final ValueChanged<int> onRated;

  /// The employee's submitted rating, shown to the manager.
  final bool showEmployeeSide;

  const _GoalRatingTile({
    required this.goal,
    required this.entry,
    required this.onRated,
    this.showEmployeeSide = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selfRating = toInt(goal['selfRating']);
    final selfComment = goal['selfComment']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal['title']?.toString() ?? '-',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),
              ),
              StatusChip(
                label: fill(ref.tr('reviews.weightOf'), {
                  'weight': _weightText(goal['weight']),
                }),
                tone: ChipTone.info,
              ),
            ],
          ),
          if ((goal['target']?.toString() ?? '').isNotEmpty)
            Text(
              fill(ref.tr('reviews.targetLabel'), {'target': goal['target']}),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            ),
          if (showEmployeeSide && selfRating != null) ...[
            const SizedBox(height: 8),
            Text(
              ref.tr('reviews.employeeSaid'),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedColor,
              ),
            ),
            RatingPicker(value: selfRating, size: 18),
            if (selfComment != null && selfComment.isNotEmpty)
              Text(
                selfComment,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textColor,
                ),
              ),
          ],
          const SizedBox(height: 8),
          RatingPicker(value: entry.rating, onChanged: onRated),
          const SizedBox(height: 8),
          TextField(
            controller: entry.comment,
            minLines: 1,
            maxLines: 4,
            maxLength: 4000,
            decoration: featureInputDecoration(
              ref.tr('reviews.comment'),
              hint: ref.tr('reviews.commentPlaceholder'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A read-only goal with one side's rating and comment.
class _RatedGoalRow extends ConsumerWidget {
  final Map<String, dynamic> goal;
  final String ratingKey;
  final String commentKey;

  const _RatedGoalRow({
    required this.goal,
    required this.ratingKey,
    required this.commentKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comment = goal[commentKey]?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal['title']?.toString() ?? '-',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),
              ),
              StatusChip(
                label: fill(ref.tr('reviews.weightOf'), {
                  'weight': _weightText(goal['weight']),
                }),
                tone: ChipTone.info,
              ),
            ],
          ),
          RatingPicker(value: toInt(goal[ratingKey]), size: 18),
          if (comment != null && comment.isNotEmpty)
            Text(
              comment,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textColor),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// SELF REVIEW
// ============================================================================

class _SelfSection extends ConsumerWidget {
  final int reviewId;
  final ReviewView view;
  final String? busy;

  const _SelfSection({
    required this.reviewId,
    required this.view,
    required this.busy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = view.review;

    if (view.can('canSelfReview')) {
      return _SelfReviewForm(
        // Rebuild the form when the review is reloaded from a different state.
        key: ValueKey('self-$reviewId-${r['goalsApprovedAt']}'),
        reviewId: reviewId,
        view: view,
        busy: busy,
      );
    }

    final submittedAt = r['selfSubmittedAt'];

    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            ref.tr('reviews.selfTitle'),
            trailing: submittedAt == null
                ? null
                : StatusChip(
                    label: fill(ref.tr('reviews.submittedOn'), {
                      'date': formatApiDate(submittedAt),
                    }),
                    tone: ChipTone.success,
                  ),
          ),
          const SizedBox(height: 6),
          if (submittedAt == null)
            Text(
              view.isEmployee
                  ? ref.tr(
                      r['goalsStatus'] == 'approved'
                          ? 'reviews.selfClosed'
                          : 'reviews.selfAfterGoals',
                    )
                  : ref.tr('reviews.selfPending'),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            )
          else ...[
            for (final goal in view.goals)
              _RatedGoalRow(
                goal: goal,
                ratingKey: 'selfRating',
                commentKey: 'selfComment',
              ),
            TextBlock(
              label: ref.tr('reviews.overallComments'),
              text: r['selfOverallComments']?.toString(),
            ),
            const SizedBox(height: 8),
            Text(
              fill(ref.tr('reviews.selfScore'), {
                'score': formatScore(r['selfScore']),
              }),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelfReviewForm extends ConsumerStatefulWidget {
  final int reviewId;
  final ReviewView view;
  final String? busy;

  const _SelfReviewForm({
    super.key,
    required this.reviewId,
    required this.view,
    required this.busy,
  });

  @override
  ConsumerState<_SelfReviewForm> createState() => _SelfReviewFormState();
}

class _SelfReviewFormState extends ConsumerState<_SelfReviewForm> {
  final Map<int, _RatingEntry> _entries = {};
  late final TextEditingController _overall;

  @override
  void initState() {
    super.initState();

    for (final goal in widget.view.goals) {
      final id = toInt(goal['id']);

      if (id == null) continue;

      _entries[id] = _RatingEntry(
        toInt(goal['selfRating']),
        goal['selfComment']?.toString(),
      );
    }

    _overall = TextEditingController(
      text: widget.view.review['selfOverallComments']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    for (final entry in _entries.values) {
      entry.comment.dispose();
    }

    _overall.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _payload() => _entries.entries
      .map(
        (e) => {
          'id': e.key,
          'rating': e.value.rating,
          'comment': e.value.comment.text.trim().isEmpty
              ? null
              : e.value.comment.text.trim(),
        },
      )
      .toList();

  Future<void> _save({required bool submit}) async {
    if (submit) {
      if (_entries.values.any((e) => e.rating == null)) {
        showFeatureSnack(context, ref.tr('reviews.rateEveryGoal'));
        return;
      }

      final confirmed = await confirmAction(
        context,
        title: ref.tr('reviews.submitSelfTitle'),
        message: ref.tr('reviews.submitLockMessage'),
        confirmLabel: ref.tr('reviews.submit'),
        cancelLabel: ref.tr('common.cancel'),
      );

      if (!confirmed || !mounted) return;
    }

    final failure = await ref
        .read(reviewDetailProvider(widget.reviewId).notifier)
        .saveSelf(
          submit: submit,
          goals: _payload(),
          overallComments: _overall.text.trim(),
        );

    if (!mounted) return;

    _report(
      context,
      failure,
      submit ? ref.tr('reviews.selfSubmittedToast') : ref.tr('reviews.draftSaved'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.busy;

    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(ref.tr('reviews.selfTitle')),
          const SizedBox(height: 4),
          Text(
            ref.tr('reviews.selfHint'),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
          ),
          const SizedBox(height: 10),
          for (final goal in widget.view.goals)
            if (_entries[toInt(goal['id'])] != null)
              _GoalRatingTile(
                goal: goal,
                entry: _entries[toInt(goal['id'])]!,
                onRated: (n) =>
                    setState(() => _entries[toInt(goal['id'])]!.rating = n),
              ),
          TextField(
            controller: _overall,
            minLines: 3,
            maxLines: 6,
            maxLength: 8000,
            decoration:
                featureInputDecoration(ref.tr('reviews.overallComments')),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy != null ? null : () => _save(submit: false),
                  child: busy == 'saveSelf'
                      ? _busySpinner()
                      : Text(ref.tr('reviews.saveDraft')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy != null ? null : () => _save(submit: true),
                  child: busy == 'submitSelf'
                      ? _busySpinner()
                      : Text(ref.tr('reviews.submitSelf')),
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
// MANAGER REVIEW
// ============================================================================

class _ManagerSection extends ConsumerWidget {
  final int reviewId;
  final ReviewView view;
  final String? busy;

  const _ManagerSection({
    required this.reviewId,
    required this.view,
    required this.busy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = view.review;

    if (view.can('canManagerReview')) {
      return _ManagerReviewForm(
        key: ValueKey('manager-$reviewId-${r['goalsApprovedAt']}'),
        reviewId: reviewId,
        view: view,
        busy: busy,
      );
    }

    final submittedAt = r['managerSubmittedAt'];

    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(ref.tr('reviews.managerTitle')),
          const SizedBox(height: 6),
          if (submittedAt == null)
            Text(
              ref.tr('reviews.managerPending'),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            )
          else ...[
            Text(
              fill(ref.tr('reviews.submittedBy'), {
                'name': r['managerSubmittedByName'] ?? '—',
                'date': formatApiDate(submittedAt),
              }),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            ),
            for (final goal in view.goals)
              _RatedGoalRow(
                goal: goal,
                ratingKey: 'managerRating',
                commentKey: 'managerComment',
              ),
            const SizedBox(height: 6),
            Text(
              ref.tr('reviews.overallRating'),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedColor,
              ),
            ),
            RatingPicker(value: toInt(r['managerOverallRating']), size: 20),
            TextBlock(
              label: ref.tr('reviews.strengths'),
              text: r['managerStrengths']?.toString(),
            ),
            TextBlock(
              label: ref.tr('reviews.improvements'),
              text: r['managerImprovements']?.toString(),
            ),
            if (r['recommendation'] != null)
              TextBlock(
                label: ref.tr('reviews.recommendation'),
                text: [
                  ref.tr('reviews.rec_${r['recommendation']}'),
                  if (r['incrementPercent'] != null)
                    fill(ref.tr('reviews.incrementOf'), {
                      'percent': r['incrementPercent'],
                    }),
                ].join(' · '),
              ),
          ],
        ],
      ),
    );
  }
}

class _ManagerReviewForm extends ConsumerStatefulWidget {
  final int reviewId;
  final ReviewView view;
  final String? busy;

  const _ManagerReviewForm({
    super.key,
    required this.reviewId,
    required this.view,
    required this.busy,
  });

  @override
  ConsumerState<_ManagerReviewForm> createState() =>
      _ManagerReviewFormState();
}

class _ManagerReviewFormState extends ConsumerState<_ManagerReviewForm> {
  final Map<int, _RatingEntry> _entries = {};
  late final TextEditingController _strengths;
  late final TextEditingController _improvements;
  late final TextEditingController _increment;
  int? _overall;
  String _recommendation = 'none';

  @override
  void initState() {
    super.initState();

    final r = widget.view.review;

    for (final goal in widget.view.goals) {
      final id = toInt(goal['id']);

      if (id == null) continue;

      _entries[id] = _RatingEntry(
        toInt(goal['managerRating']),
        goal['managerComment']?.toString(),
      );
    }

    _overall = toInt(r['managerOverallRating']);
    _strengths =
        TextEditingController(text: r['managerStrengths']?.toString() ?? '');
    _improvements =
        TextEditingController(text: r['managerImprovements']?.toString() ?? '');
    _increment = TextEditingController(
      text: r['incrementPercent']?.toString() ?? '',
    );

    final recommendation = r['recommendation']?.toString();

    if (ReviewRepository.recommendations.contains(recommendation)) {
      _recommendation = recommendation!;
    }
  }

  @override
  void dispose() {
    for (final entry in _entries.values) {
      entry.comment.dispose();
    }

    _strengths.dispose();
    _improvements.dispose();
    _increment.dispose();
    super.dispose();
  }

  /// Weighted average of the manager ratings, as the server works it out.
  double? get _preview {
    double total = 0;
    double weight = 0;

    for (final goal in widget.view.goals) {
      final rating = _entries[toInt(goal['id'])]?.rating;
      final w = toNum(goal['weight']);

      if (rating == null || w == null) continue;

      total += w * rating;
      weight += w;
    }

    return weight == 0 ? null : total / weight;
  }

  Future<void> _save({required bool submit}) async {
    final increment = num.tryParse(_increment.text.trim());

    if (_recommendation == 'increment' &&
        _increment.text.trim().isNotEmpty &&
        (increment == null || increment <= 0 || increment > 100)) {
      showFeatureSnack(context, ref.tr('reviews.errIncrement'));
      return;
    }

    if (submit) {
      String? error;

      if (_entries.values.any((e) => e.rating == null)) {
        error = ref.tr('reviews.rateEveryGoal');
      } else if (_overall == null) {
        error = ref.tr('reviews.errOverall');
      } else if (_recommendation == 'increment' && increment == null) {
        error = ref.tr('reviews.errIncrement');
      }

      if (error != null) {
        showFeatureSnack(context, error);
        return;
      }

      final confirmed = await confirmAction(
        context,
        title: ref.tr('reviews.submitManagerTitle'),
        message: ref.tr('reviews.submitLockMessage'),
        confirmLabel: ref.tr('reviews.submit'),
        cancelLabel: ref.tr('common.cancel'),
      );

      if (!confirmed || !mounted) return;
    }

    final failure = await ref
        .read(reviewDetailProvider(widget.reviewId).notifier)
        .saveManager(
          submit: submit,
          goals: _entries.entries
              .map(
                (e) => {
                  'id': e.key,
                  'rating': e.value.rating,
                  'comment': e.value.comment.text.trim().isEmpty
                      ? null
                      : e.value.comment.text.trim(),
                },
              )
              .toList(),
          overallRating: _overall,
          strengths: _strengths.text.trim(),
          improvements: _improvements.text.trim(),
          recommendation: _recommendation,
          incrementPercent: increment,
        );

    if (!mounted) return;

    _report(
      context,
      failure,
      submit
          ? ref.tr('reviews.managerSubmittedToast')
          : ref.tr('reviews.draftSaved'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.busy;
    final r = widget.view.review;
    final preview = _preview;

    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(ref.tr('reviews.managerTitle')),
          const SizedBox(height: 4),
          Text(
            r['selfSubmittedAt'] != null
                ? ref.tr('reviews.managerHint')
                : ref.tr('reviews.managerHintNoSelf'),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
          ),
          const SizedBox(height: 10),
          for (final goal in widget.view.goals)
            if (_entries[toInt(goal['id'])] != null)
              _GoalRatingTile(
                goal: goal,
                entry: _entries[toInt(goal['id'])]!,
                showEmployeeSide: r['selfSubmittedAt'] != null,
                onRated: (n) =>
                    setState(() => _entries[toInt(goal['id'])]!.rating = n),
              ),
          Text(
            ref.tr('reviews.overallRating'),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textColor,
            ),
          ),
          RatingPicker(
            value: _overall,
            onChanged: (n) => setState(() => _overall = n),
          ),
          const SizedBox(height: 4),
          Text(
            fill(ref.tr('reviews.weightedPreview'), {
              'score': preview == null ? '-' : preview.toStringAsFixed(2),
            }),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _strengths,
            minLines: 2,
            maxLines: 5,
            maxLength: 8000,
            decoration: featureInputDecoration(ref.tr('reviews.strengths')),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _improvements,
            minLines: 2,
            maxLines: 5,
            maxLength: 8000,
            decoration: featureInputDecoration(ref.tr('reviews.improvements')),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _recommendation,
            isExpanded: true,
            decoration:
                featureInputDecoration(ref.tr('reviews.recommendation')),
            items: ReviewRepository.recommendations
                .map(
                  (rec) => DropdownMenuItem(
                    value: rec,
                    child: Text(ref.tr('reviews.rec_$rec')),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _recommendation = value);
            },
          ),
          if (_recommendation == 'increment') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _increment,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d{0,3}\.?\d{0,2}'),
                ),
              ],
              decoration: featureInputDecoration(
                ref.tr('reviews.incrementPercent'),
              ).copyWith(suffixText: '%'),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            ref.tr('reviews.recommendationPrivate'),
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedColor),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy != null ? null : () => _save(submit: false),
                  child: busy == 'saveManager'
                      ? _busySpinner()
                      : Text(ref.tr('reviews.saveDraft')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy != null ? null : () => _save(submit: true),
                  child: busy == 'submitManager'
                      ? _busySpinner()
                      : Text(
                          ref.tr('reviews.submitManager'),
                          overflow: TextOverflow.ellipsis,
                        ),
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
// RESULT
// ============================================================================

class _ResultSection extends ConsumerStatefulWidget {
  final int reviewId;
  final ReviewView view;
  final String? busy;

  const _ResultSection({
    required this.reviewId,
    required this.view,
    required this.busy,
  });

  @override
  ConsumerState<_ResultSection> createState() => _ResultSectionState();
}

class _ResultSectionState extends ConsumerState<_ResultSection> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _acknowledge() async {
    final failure = await ref
        .read(reviewDetailProvider(widget.reviewId).notifier)
        .acknowledge(_comment.text);

    if (!mounted) return;

    _report(context, failure, ref.tr('reviews.acknowledgedToast'));
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final r = view.review;
    final finalizedAt = r['finalizedAt'];

    if (finalizedAt == null) {
      // The employee only sees the manager's side once it is finalized.
      return FeatureCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(ref.tr('reviews.resultTitle')),
            const SizedBox(height: 6),
            Text(
              ref.tr('reviews.notFinalizedYet'),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            ),
          ],
        ),
      );
    }

    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(ref.tr('reviews.resultTitle')),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.saffronGradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.tr('reviews.finalScore').toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .5,
                          color: AppColors.white,
                        ),
                      ),
                      Text(
                        '${formatScore(r['finalScore'])} / 5',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.workspace_premium_outlined,
                  color: AppColors.white,
                  size: 40,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            ref.tr('reviews.overallRating'),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedColor,
            ),
          ),
          RatingPicker(value: toInt(r['managerOverallRating']), size: 20),
          if (view.isEmployee)
            for (final goal in view.goals)
              _RatedGoalRow(
                goal: goal,
                ratingKey: 'managerRating',
                commentKey: 'managerComment',
              ),
          if (view.isEmployee) ...[
            TextBlock(
              label: ref.tr('reviews.strengths'),
              text: r['managerStrengths']?.toString(),
            ),
            TextBlock(
              label: ref.tr('reviews.improvements'),
              text: r['managerImprovements']?.toString(),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            fill(ref.tr('reviews.finalizedOn'), {
              'date': formatApiDate(finalizedAt),
              'name': r['finalizedByName'] ?? '—',
            }),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
          ),
          if (r['acknowledgedAt'] != null) ...[
            const SizedBox(height: 6),
            StatusChip(
              label: fill(ref.tr('reviews.acknowledgedOn'), {
                'date': formatApiDate(r['acknowledgedAt']),
              }),
              tone: ChipTone.success,
            ),
            TextBlock(
              label: ref.tr('reviews.ackComment'),
              text: r['acknowledgementComment']?.toString(),
            ),
          ],
          if (view.can('canAcknowledge')) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _comment,
              minLines: 2,
              maxLines: 4,
              maxLength: 4000,
              decoration: featureInputDecoration(ref.tr('reviews.ackComment')),
            ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: widget.busy != null ? null : _acknowledge,
                icon: widget.busy == 'acknowledge'
                    ? _busySpinner()
                    : const Icon(Icons.verified_outlined, size: 18),
                label: Text(ref.tr('reviews.acknowledge')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
