import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/expenses/presentation/expense_ui.dart';
import 'package:workforce/features/expenses/providers/expense_provider.dart';

/// One claim: amounts, the decision trail, the receipt, and cancel while pending.
class ExpenseDetailScreen extends ConsumerWidget {
  final int claimId;

  const ExpenseDetailScreen({super.key, required this.claimId});

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmAction(
      context,
      title: ref.tr('expense.cancelConfirm'),
      message: ref.tr('expense.cancelBody'),
      confirmLabel: ref.tr('expense.cancelClaim'),
      cancelLabel: ref.tr('expense.keep'),
      destructive: true,
    );

    if (!confirmed || !context.mounted) return;

    final failure =
        await ref.read(expenseProvider.notifier).cancelClaim(claimId);

    if (!context.mounted) return;

    if (failure == null) {
      ref.invalidate(expenseDetailProvider(claimId));
      showFeatureSnack(context, ref.tr('expense.cancelledToast'));
    } else {
      showFeatureSnack(context, failure);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(expenseDetailProvider(claimId));
    final cancelling = ref.watch(expenseProvider).isCancelling;

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(
        title: fill(ref.tr('expense.ref'), {'id': claimId}),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(expenseDetailProvider(claimId));
            await ref.read(expenseDetailProvider(claimId).future);
          },
          child: detail.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ListView(
              children: [
                LoadErrorView(
                  message: cleanErrorMessage(error),
                  retryLabel: ref.tr('common.retry'),
                  onRetry: () => ref.invalidate(expenseDetailProvider(claimId)),
                ),
              ],
            ),
            data: (claim) => _buildBody(context, ref, claim, cancelling),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> claim,
    bool cancelling,
  ) {
    final status = claim['status']?.toString();
    final category = claim['category']?.toString();
    final level = toInt(claim['approvalLevel']);
    final totalLevels = toInt(claim['approvalTotalLevels']);
    final history = asMapList(claim['history']);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        FeatureCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    expenseCategoryIcon(category),
                    color: AppColors.primaryFillColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      expenseCategoryLabel(ref, category),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor,
                      ),
                    ),
                  ),
                  ExpenseStatusChips(claim: claim),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                formatInr(toNum(claim['amount'])),
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textColor,
                ),
              ),
              const SizedBox(height: 8),
              InfoRow(
                label: ref.tr('expense.date'),
                value: formatApiDate(claim['expenseDate']),
              ),
              InfoRow(
                label: ref.tr('expense.submittedOn'),
                value: formatApiDate(claim['createdAt']),
              ),
              if (status == 'pending' && level != null && totalLevels != null)
                InfoRow(
                  label: ref.tr('expense.approvalStep'),
                  value: fill(ref.tr('expense.levelOf'), {
                    'level': level,
                    'total': totalLevels,
                  }),
                ),
              if (claim['decidedByName'] != null)
                InfoRow(
                  label: ref.tr('expense.decidedBy'),
                  value: '${claim['decidedByName']} · '
                      '${formatApiDate(claim['decidedAt'])}',
                ),
              if ((claim['decisionComment']?.toString() ?? '').isNotEmpty)
                InfoRow(
                  label: ref.tr('expense.comment'),
                  value: claim['decisionComment'].toString(),
                ),
              if (status == 'paid' && claim['paidOn'] != null)
                InfoRow(
                  label: ref.tr('expense.paidOn'),
                  value: [
                    formatApiDate(claim['paidOn']),
                    if ((claim['paidReference']?.toString() ?? '').isNotEmpty)
                      claim['paidReference'].toString(),
                  ].join(' · '),
                ),
              if (status == 'cancelled' && claim['cancelledAt'] != null)
                InfoRow(
                  label: ref.tr('expense.cancelledOn'),
                  value: formatApiDate(claim['cancelledAt']),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FeatureCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(ref.tr('expense.description')),
              const SizedBox(height: 6),
              Text(
                claim['description']?.toString() ?? '',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FeatureCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(ref.tr('expense.receipt')),
              const SizedBox(height: 8),
              ExpenseReceiptView(claim: claim),
            ],
          ),
        ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 12),
          _HistoryCard(history: history),
        ],
        if (status == 'pending') ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB3261E),
                side: const BorderSide(color: Color(0xFFB3261E)),
              ),
              onPressed: cancelling ? null : () => _cancel(context, ref),
              icon: cancelling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cancel_outlined, size: 18),
              label: Text(ref.tr('expense.cancelClaim')),
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  final List<Map<String, dynamic>> history;

  const _HistoryCard({required this.history});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <Map<String, dynamic>>[
      for (final entry in history) ...asMapList(entry['actions']),
    ];

    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(ref.tr('expense.history')),
          const SizedBox(height: 8),
          if (actions.isEmpty)
            Text(
              ref.tr('expense.historyEmpty'),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            ),
          for (final action in actions)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _actionIcon(action['action']?.toString()),
                    size: 18,
                    color: _actionColor(action['action']?.toString()),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            _actionLabel(ref, action['action']?.toString()),
                            if (action['actorName'] != null)
                              action['actorName'].toString(),
                          ].join(' · '),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textColor,
                          ),
                        ),
                        Text(
                          formatApiDate(action['at']),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.mutedColor,
                          ),
                        ),
                        if ((action['remarks']?.toString() ?? '').isNotEmpty)
                          Text(
                            action['remarks'].toString(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _actionLabel(WidgetRef ref, String? action) {
    switch (action?.toUpperCase()) {
      case 'APPROVED':
        return ref.tr('expense.status_approved');
      case 'REJECTED':
        return ref.tr('expense.status_rejected');
      case 'CANCELLED':
        return ref.tr('expense.status_cancelled');
      case 'REQUESTED':
        return ref.tr('expense.submitted');
      default:
        return action ?? '-';
    }
  }

  static IconData _actionIcon(String? action) {
    switch (action?.toUpperCase()) {
      case 'APPROVED':
        return Icons.check_circle_outline;
      case 'REJECTED':
        return Icons.highlight_off;
      case 'CANCELLED':
        return Icons.block;
      default:
        return Icons.radio_button_checked;
    }
  }

  static Color _actionColor(String? action) {
    switch (action?.toUpperCase()) {
      case 'APPROVED':
        return AppColors.indiaGreen;
      case 'REJECTED':
        return const Color(0xFFB3261E);
      case 'CANCELLED':
        return AppColors.mutedColor;
      default:
        return AppColors.navy;
    }
  }
}
