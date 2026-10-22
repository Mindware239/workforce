import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/network/stored_file.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/assets/data/asset_repository.dart';
import 'package:workforce/features/assets/providers/asset_provider.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';

/// Company property issued to the employee: what they hold now (acknowledge
/// receipt, report a problem), what they returned, and the problems they
/// reported.
class MyAssetsScreen extends ConsumerStatefulWidget {
  const MyAssetsScreen({super.key});

  @override
  ConsumerState<MyAssetsScreen> createState() => _MyAssetsScreenState();
}

class _MyAssetsScreenState extends ConsumerState<MyAssetsScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(assetProvider.notifier).load();
    });
  }

  Future<void> _acknowledge(Map<String, dynamic> assignment) async {
    final id = toInt(assignment['id']);

    if (id == null) return;

    final failure = await ref.read(assetProvider.notifier).acknowledge(id);

    if (!mounted) return;

    showFeatureSnack(context, failure ?? ref.tr('assets.ackDone'));
  }

  Future<void> _report(Map<String, dynamic> assignment) async {
    final id = toInt(assignment['id']);

    if (id == null) return;

    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReportProblemSheet(
        assignmentId: id,
        assetName: assignment['assetName']?.toString() ?? '',
      ),
    );

    if (sent == true && mounted) {
      showFeatureSnack(context, ref.tr('assets.reportSent'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assetProvider);
    final holdings = state.holdings;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.whiteBackgroundColor,
        appBar: featureAppBar(),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: FeatureHeading(
                  title: ref.tr('assets.myTitle'),
                  subtitle: ref.tr('assets.mySubtitle'),
                ),
              ),
              TabBar(
                labelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(
                    text: '${ref.tr('assets.tabCurrent')} '
                        '(${holdings.current.length})',
                  ),
                  Tab(
                    text: '${ref.tr('assets.tabReturned')} '
                        '(${holdings.history.length})',
                  ),
                  Tab(
                    text: '${ref.tr('assets.tabReports')} '
                        '(${holdings.issues.length})',
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _tab(
                      state,
                      holdings.current,
                      ref.tr('assets.myNone'),
                      (a) => _CurrentAssetCard(
                        assignment: a,
                        busy: state.busyAssignmentId == toInt(a['id']),
                        onAcknowledge: () => _acknowledge(a),
                        onReport: () => _report(a),
                      ),
                    ),
                    _tab(
                      state,
                      holdings.history,
                      ref.tr('assets.noHistory'),
                      (a) => _ReturnedAssetCard(assignment: a),
                    ),
                    _tab(
                      state,
                      holdings.issues,
                      ref.tr('assets.noReports'),
                      (i) => _IssueCard(issue: i),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(
    AssetState state,
    List<Map<String, dynamic>> items,
    String emptyMessage,
    Widget Function(Map<String, dynamic>) builder,
  ) {
    Widget content;

    if (state.isLoading && !state.loaded) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (state.error != null && !state.loaded) {
      content = LoadErrorView(
        message: state.error!,
        retryLabel: ref.tr('common.retry'),
        onRetry: () => ref.read(assetProvider.notifier).load(),
      );
    } else if (items.isEmpty) {
      content = EmptyNote(emptyMessage, icon: Icons.devices_other_outlined);
    } else {
      content = Column(children: items.map(builder).toList());
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(assetProvider.notifier).load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [content],
      ),
    );
  }
}

// ============================================================================
// HELPERS
// ============================================================================

IconData _categoryIcon(String? category) {
  switch (category) {
    case 'laptop':
      return Icons.laptop_outlined;
    case 'desktop':
      return Icons.desktop_windows_outlined;
    case 'mobile_phone':
      return Icons.smartphone_outlined;
    case 'sim_card':
      return Icons.sim_card_outlined;
    case 'id_card':
      return Icons.badge_outlined;
    case 'vehicle':
      return Icons.two_wheeler_outlined;
    case 'tools':
      return Icons.handyman_outlined;
    case 'furniture':
      return Icons.chair_outlined;
    default:
      return Icons.devices_other_outlined;
  }
}

String _subtitle(WidgetRef ref, Map<String, dynamic> a) {
  return [
    a['assetTag'],
    ref.tr('assets.cat_${a['assetCategory'] ?? 'other'}'),
    a['brand'],
    a['model'],
  ]
      .where((part) => part != null && part.toString().trim().isNotEmpty)
      .join(' · ');
}

class _AssetThumb extends StatelessWidget {
  final Map<String, dynamic> assignment;

  const _AssetThumb({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final photo = assignment['photoPath']?.toString();
    final icon = Icon(
      _categoryIcon(assignment['assetCategory']?.toString()),
      color: AppColors.primaryFillColor,
      size: 22,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 48,
        height: 48,
        color: AppColors.primarySurfaceTintColor,
        child: photo == null || photo.isEmpty
            ? icon
            : StoredFileImage(
                path: photo,
                width: 48,
                height: 48,
                fallback: icon,
              ),
      ),
    );
  }
}

class _AssetHeader extends ConsumerWidget {
  final Map<String, dynamic> assignment;
  final Widget? trailing;

  const _AssetHeader({required this.assignment, this.trailing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AssetThumb(assignment: assignment),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                assignment['assetName']?.toString() ?? '-',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _subtitle(ref, assignment),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.mutedColor,
                ),
              ),
              if ((assignment['serialNumber']?.toString() ?? '').isNotEmpty)
                Text(
                  fill(ref.tr('assets.serial'), {
                    'serial': assignment['serialNumber'],
                  }),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.mutedColor,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

// ============================================================================
// CURRENT
// ============================================================================

class _CurrentAssetCard extends ConsumerWidget {
  final Map<String, dynamic> assignment;
  final bool busy;
  final VoidCallback onAcknowledge;
  final VoidCallback onReport;

  const _CurrentAssetCard({
    required this.assignment,
    required this.busy,
    required this.onAcknowledge,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acknowledgedAt = assignment['acknowledgedAt'];
    final openIssues = toInt(assignment['openIssues']) ?? 0;
    final condition = assignment['conditionAtIssue']?.toString() ?? 'good';

    return FeatureCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AssetHeader(assignment: assignment),
          const SizedBox(height: 10),
          Text(
            fill(ref.tr('assets.issuedOnCond'), {
              'date': formatApiDate(assignment['assignedOn']),
              'condition': ref.tr('assets.cond_$condition'),
            }),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textColor),
          ),
          if (assignment['assignedByName'] != null)
            Text(
              fill(ref.tr('assets.issuedBy'), {
                'name': assignment['assignedByName'],
              }),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.mutedColor,
              ),
            ),
          if ((assignment['issueNotes']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                assignment['issueNotes'].toString(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.mutedColor,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (acknowledgedAt != null)
                StatusChip(
                  label: fill(ref.tr('assets.ackOn'), {
                    'date': formatApiDate(acknowledgedAt),
                  }),
                  tone: ChipTone.success,
                )
              else
                StatusChip(
                  label: ref.tr('assets.awaitingAck'),
                  tone: ChipTone.warning,
                ),
              if (openIssues > 0)
                StatusChip(
                  label: ref.tr('assets.reportPending'),
                  tone: ChipTone.info,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (acknowledgedAt == null) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : onAcknowledge,
                    icon: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(
                      ref.tr('assets.ackButton'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onReport,
                  icon: const Icon(Icons.report_problem_outlined, size: 18),
                  label: Text(
                    ref.tr('assets.reportProblem'),
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
// RETURNED
// ============================================================================

class _ReturnedAssetCard extends ConsumerWidget {
  final Map<String, dynamic> assignment;

  const _ReturnedAssetCard({required this.assignment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lost = assignment['closedReason'] == 'lost';
    final returnCondition = assignment['conditionAtReturn']?.toString();

    return FeatureCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AssetHeader(
            assignment: assignment,
            trailing: StatusChip(
              label: lost
                  ? ref.tr('assets.status_lost')
                  : ref.tr('assets.returned'),
              tone: lost ? ChipTone.danger : ChipTone.neutral,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${formatApiDate(assignment['assignedOn'])} → '
            '${formatApiDate(assignment['returnedOn'])}',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textColor),
          ),
          if (returnCondition != null)
            Text(
              fill(ref.tr('assets.returnedCondition'), {
                'condition': ref.tr('assets.cond_$returnCondition'),
              }),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.mutedColor,
              ),
            ),
          if (assignment['receivedByName'] != null)
            Text(
              fill(ref.tr('assets.receivedBy'), {
                'name': assignment['receivedByName'],
              }),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.mutedColor,
              ),
            ),
          if ((assignment['returnNotes']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                assignment['returnNotes'].toString(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.mutedColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// REPORTS
// ============================================================================

class _IssueCard extends ConsumerWidget {
  final Map<String, dynamic> issue;

  const _IssueCard({required this.issue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = issue['status'] == 'open';
    final kind = issue['kind']?.toString() ?? 'other';

    return FeatureCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${issue['assetName'] ?? '-'}'
                  '${issue['assetTag'] != null ? ' · ${issue['assetTag']}' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),
              ),
              StatusChip(
                label: ref.tr('assets.issue_${open ? 'open' : 'resolved'}'),
                tone: open ? ChipTone.warning : ChipTone.success,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${ref.tr('assets.kind_$kind')} · ${formatApiDate(issue['createdAt'])}',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedColor),
          ),
          const SizedBox(height: 6),
          Text(
            issue['description']?.toString() ?? '',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textColor),
          ),
          if ((issue['resolutionNote']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              fill(ref.tr('assets.resolution'), {
                'note': issue['resolutionNote'],
              }),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.indiaGreen,
              ),
            ),
          ],
          if (issue['resolvedAt'] != null)
            Text(
              [
                formatApiDate(issue['resolvedAt']),
                if (issue['resolvedByName'] != null)
                  issue['resolvedByName'].toString(),
              ].join(' · '),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.mutedColor,
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// REPORT A PROBLEM
// ============================================================================

class _ReportProblemSheet extends ConsumerStatefulWidget {
  final int assignmentId;
  final String assetName;

  const _ReportProblemSheet({
    required this.assignmentId,
    required this.assetName,
  });

  @override
  ConsumerState<_ReportProblemSheet> createState() =>
      _ReportProblemSheetState();
}

class _ReportProblemSheetState extends ConsumerState<_ReportProblemSheet> {
  final _descriptionController = TextEditingController();
  String _kind = AssetRepository.issueKinds.first;
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final description = _descriptionController.text.trim();

    if (description.length < 3) {
      setState(() => _error = ref.tr('assets.errDescribe'));
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    final failure = await ref.read(assetProvider.notifier).reportIssue(
          assignmentId: widget.assignmentId,
          kind: _kind,
          description: description,
        );

    if (!mounted) return;

    if (failure == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _sending = false;
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
              fill(ref.tr('assets.reportTitle'), {'name': widget.assetName}),
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
            Text(
              ref.tr('assets.whatHappened'),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: AssetRepository.issueKinds
                  .map(
                    (kind) => ChoiceChip(
                      label: Text(ref.tr('assets.kind_$kind')),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              decoration: featureInputDecoration(
                ref.tr('assets.describe'),
                hint: ref.tr('assets.describePlaceholder'),
              ),
            ),
            Text(
              ref.tr('assets.reportWho'),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.mutedColor,
              ),
            ),
            const SizedBox(height: 16),
            AbsorbPointer(
              absorbing: _sending,
              child: Opacity(
                opacity: _sending ? 0.6 : 1,
                child: WorkforcePrimaryButton(
                  title: _sending
                      ? ref.tr('common.pleaseWait')
                      : ref.tr('assets.reportSend'),
                  icon: Icons.send_outlined,
                  onPressed: _send,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
