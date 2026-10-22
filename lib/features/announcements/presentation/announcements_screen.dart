import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/announcements/providers/announcement_provider.dart';

/// Workspace announcements: pinned notices first, in full, with
/// action-required ones marked; then the rest, newest first, twenty at a time.
/// Tapping one opens it in full in a bottom sheet.
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(announcementProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(announcementProvider);

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(announcementProvider.notifier).load(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              FeatureHeading(
                title: ref.tr('announcement.title'),
                subtitle: ref.tr('announcement.subtitle'),
              ),
              const SizedBox(height: 16),
              ..._buildBody(state),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody(AnnouncementState state) {
    if (state.isLoading && state.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (state.error != null && state.isEmpty) {
      return [
        LoadErrorView(
          message: state.error!,
          retryLabel: ref.tr('common.retry'),
          onRetry: () => ref.read(announcementProvider.notifier).load(),
        ),
      ];
    }

    if (state.isEmpty) {
      return [
        EmptyNote(
          ref.tr('announcement.empty'),
          icon: Icons.campaign_outlined,
        ),
      ];
    }

    return [
      if (state.error != null) ...[
        ErrorBanner(state.error!),
        const SizedBox(height: 12),
      ],
      if (state.pinned.isNotEmpty) ...[
        _SectionLabel(ref.tr('announcement.pinned')),
        const SizedBox(height: 8),
        for (final item in state.pinned)
          _AnnouncementCard(announcement: item, pinned: true),
        const SizedBox(height: 12),
      ],
      if (state.recent.isNotEmpty) ...[
        _SectionLabel(ref.tr('announcement.recent')),
        const SizedBox(height: 8),
        for (final item in state.recent) _AnnouncementCard(announcement: item),
      ],
      if (state.canLoadMore) ...[
        const SizedBox(height: 8),
        Center(
          child: state.isLoadingMore
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : OutlinedButton(
                  onPressed: () =>
                      ref.read(announcementProvider.notifier).loadMore(),
                  child: Text(ref.tr('announcement.loadMore')),
                ),
        ),
      ],
    ];
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
        color: AppColors.mutedColor,
      ),
    );
  }
}

/// "14:20" today, "Yesterday", otherwise a short date — as the web screen.
String _when(WidgetRef ref, dynamic createdAt) {
  final date = parseApiDate(createdAt);

  if (date == null) return '';

  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);

  if (!date.isBefore(startOfToday)) return DateFormat('HH:mm').format(date);

  final startOfYesterday = startOfToday.subtract(const Duration(days: 1));

  if (!date.isBefore(startOfYesterday)) {
    return ref.tr('announcement.yesterday');
  }

  return DateFormat('d MMM').format(date);
}

Widget? _priorityChip(WidgetRef ref, String? priority) {
  switch (priority) {
    case 'action_required':
      return StatusChip(
        label: ref.tr('announcement.actionRequired'),
        tone: ChipTone.danger,
      );
    case 'high':
      return StatusChip(
        label: ref.tr('announcement.highPriority'),
        tone: ChipTone.warning,
      );
    default:
      return null;
  }
}

class _AnnouncementCard extends ConsumerWidget {
  final Map<String, dynamic> announcement;
  final bool pinned;

  const _AnnouncementCard({required this.announcement, this.pinned = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = announcement['title']?.toString() ?? '';
    final body = announcement['body']?.toString() ?? '';
    final priority = announcement['priority']?.toString();
    final chip = _priorityChip(ref, priority);
    final actionRequired = priority == 'action_required';

    final card = FeatureCard(
      onTap: () => _openDetail(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (pinned) ...[
                const Icon(
                  Icons.push_pin_rounded,
                  size: 16,
                  color: AppColors.saffronText,
                ),
                const SizedBox(width: 6),
              ],
              ?chip,
              const Spacer(),
              Text(
                _when(ref, announcement['createdAt']),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.mutedColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            maxLines: pinned ? null : 3,
            overflow: pinned ? null : TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: AppColors.mutedColor,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: actionRequired
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Color(0xFFB3261E), width: 4),
                  ),
                ),
                child: card,
              ),
            )
          : card,
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref) {
    final title = announcement['title']?.toString() ?? '';
    final body = announcement['body']?.toString() ?? '';
    final author = announcement['authorName']?.toString();
    final date = parseApiDate(announcement['createdAt']);
    final chip = _priorityChip(ref, announcement['priority']?.toString());
    final pinnedLabel = ref.tr('announcement.pinnedChip');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (chip != null || pinned)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (pinned)
                      StatusChip(label: pinnedLabel, tone: ChipTone.primary),
                    ?chip,
                  ],
                ),
              ),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              [
                if (author != null && author.isNotEmpty) author,
                if (date != null) DateFormat('dd MMM yyyy, HH:mm').format(date),
              ].join(' · '),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              body,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
