import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/reviews/presentation/review_ui.dart';
import 'package:workforce/features/reviews/providers/review_provider.dart';

/// Performance reviews: my reviews and — for anyone who is somebody's
/// reporting manager — a "My team" tab with the reviews waiting on them.
/// The tab only appears when /api/reviews/team returns something.
class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  bool _teamTab = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(reviewListProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewListProvider);
    final hasTeam = state.team.isNotEmpty;
    final showTeam = _teamTab && hasTeam;
    final rows = showTeam ? state.team : state.mine;

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(reviewListProvider.notifier).load(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              FeatureHeading(
                title: ref.tr('reviews.title'),
                subtitle: ref.tr('reviews.employeeSubtitle'),
              ),
              if (hasTeam) ...[
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.saffronLight,
                    selectedForegroundColor: AppColors.saffronText,
                  ),
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(ref.tr('reviews.tabMine')),
                      icon: const Icon(Icons.person_outline, size: 18),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(
                        state.teamWaiting > 0
                            ? '${ref.tr('reviews.tabTeam')} (${state.teamWaiting})'
                            : ref.tr('reviews.tabTeam'),
                      ),
                      icon: const Icon(Icons.groups_outlined, size: 18),
                    ),
                  ],
                  selected: {showTeam},
                  onSelectionChanged: (value) =>
                      setState(() => _teamTab = value.first),
                ),
              ],
              const SizedBox(height: 16),
              ..._buildRows(state, rows, showTeam),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRows(
    ReviewListState state,
    List<Map<String, dynamic>> rows,
    bool team,
  ) {
    if (state.isLoading && !state.loaded) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (state.error != null && !state.loaded) {
      return [
        LoadErrorView(
          message: state.error!,
          retryLabel: ref.tr('common.retry'),
          onRetry: () => ref.read(reviewListProvider.notifier).load(),
        ),
      ];
    }

    if (rows.isEmpty) {
      return [
        EmptyNote(
          '${ref.tr('reviews.noReviews')}\n${ref.tr('reviews.noReviewsHint')}',
          icon: Icons.insights_outlined,
        ),
      ];
    }

    return rows.map((r) => _ReviewCard(review: r, team: team)).toList();
  }
}

class _ReviewCard extends ConsumerWidget {
  final Map<String, dynamic> review;
  final bool team;

  const _ReviewCard({required this.review, required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = toInt(review['id']);
    final stage = review['stage']?.toString();
    final finalScore = review['finalScore'];

    return FeatureCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: id == null
          ? null
          : () => context.push(AppRoutes.reviewDetailPath(id)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      (team ? review['fullName'] : review['cycleName'])
                              ?.toString() ??
                          '-',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor,
                      ),
                    ),
                    ReviewStageChip(stage: stage),
                    if (team && ReviewListState.needsManager(review))
                      StatusChip(
                        label: ref.tr('reviews.needsYou'),
                        tone: ChipTone.warning,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  team
                      ? review['cycleName']?.toString() ?? ''
                      : '${formatApiDate(review['periodStart'])} – '
                          '${formatApiDate(review['periodEnd'])}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedColor,
                  ),
                ),
                if (!team && finalScore != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      fill(ref.tr('reviews.scoreLine'), {
                        'score': formatScore(finalScore),
                      }),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor,
                      ),
                    ),
                  ),
                if (!team &&
                    stage == 'goal_setting' &&
                    review['cycleStatus'] == 'active')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      ref.tr('reviews.setGoalsNudge'),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.saffronText,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.mutedColor),
        ],
      ),
    );
  }
}
