import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/expenses/presentation/expense_ui.dart';
import 'package:workforce/features/expenses/providers/expense_provider.dart';

/// My expense claims: totals, a status filter, and each claim.
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  /// null = all statuses.
  String? _statusFilter;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(expenseProvider.notifier).load();
    });
  }

  Future<void> _openNewClaim() async {
    final created = await context.push<bool>(AppRoutes.expenseNew);

    if (created == true && mounted) {
      showFeatureSnack(context, ref.tr('expense.submittedToast'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expenseProvider);

    final claims = _statusFilter == null
        ? state.claims
        : state.claims.where((c) => c['status'] == _statusFilter).toList();

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewClaim,
        icon: const Icon(Icons.add),
        label: Text(
          ref.tr('expense.newClaim'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(expenseProvider.notifier).load(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              FeatureHeading(
                title: ref.tr('expense.employeeTitle'),
                subtitle: ref.tr('expense.employeeSubtitle'),
              ),
              const SizedBox(height: 16),
              _buildTotals(state),
              if (state.receiptRequiredAbove != null) ...[
                const SizedBox(height: 10),
                Text(
                  fill(ref.tr('expense.receiptRule'), {
                    'amount': formatInr(state.receiptRequiredAbove),
                  }),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedColor,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SectionTitle(ref.tr('expense.yourClaims')),
              const SizedBox(height: 10),
              _buildFilters(state),
              const SizedBox(height: 12),
              ..._buildList(state, claims),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotals(ExpenseState state) {
    return Row(
      children: [
        Expanded(
          child: _TotalTile(
            label: ref.tr('expense.awaitingDecision'),
            amount: state.pendingTotal,
            color: AppColors.saffronText,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TotalTile(
            label: ref.tr('expense.approvedUnpaid'),
            amount: state.approvedUnpaidTotal,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TotalTile(
            label: ref.tr('expense.paidTotal'),
            amount: state.paidTotal,
            color: AppColors.indiaGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(ExpenseState state) {
    Widget chip(String? status, String label) {
      final count =
          status == null ? state.claims.length : state.countOf(status);

      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text('$label ($count)'),
          selected: _statusFilter == status,
          labelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _statusFilter == status
                ? AppColors.saffronText
                : AppColors.textColor,
          ),
          onSelected: (_) => setState(() => _statusFilter = status),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(null, ref.tr('expense.all')),
          for (final status in expenseStatuses)
            chip(status, expenseStatusLabel(ref, status)),
        ],
      ),
    );
  }

  List<Widget> _buildList(
    ExpenseState state,
    List<Map<String, dynamic>> claims,
  ) {
    if (state.isLoading && state.claims.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (state.error != null && state.claims.isEmpty) {
      return [
        LoadErrorView(
          message: state.error!,
          retryLabel: ref.tr('common.retry'),
          onRetry: () => ref.read(expenseProvider.notifier).load(),
        ),
      ];
    }

    if (claims.isEmpty) {
      return [
        EmptyNote(
          ref.tr('expense.noClaims'),
          icon: Icons.receipt_long_outlined,
        ),
      ];
    }

    return claims.map((claim) => _ClaimCard(claim: claim)).toList();
  }
}

class _TotalTile extends StatelessWidget {
  final String label;
  final num amount;
  final Color color;

  const _TotalTile({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FeatureCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedColor,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatInr(amount),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimCard extends ConsumerWidget {
  final Map<String, dynamic> claim;

  const _ClaimCard({required this.claim});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = toInt(claim['id']);
    final category = claim['category']?.toString();
    final hasReceipt = (claim['receiptPath']?.toString() ?? '').isNotEmpty;

    return FeatureCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: id == null
          ? null
          : () => context.push(AppRoutes.expenseDetailPath(id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySurfaceTintColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              expenseCategoryIcon(category),
              color: AppColors.primaryFillColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        expenseCategoryLabel(ref, category),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textColor,
                        ),
                      ),
                    ),
                    Text(
                      formatInr(toNum(claim['amount'])),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatApiDate(claim['expenseDate'])} · '
                  '${fill(ref.tr('expense.ref'), {'id': id})}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.mutedColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  claim['description']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: ExpenseStatusChips(claim: claim)),
                    if (hasReceipt)
                      const Icon(
                        Icons.attach_file,
                        size: 16,
                        color: AppColors.mutedColor,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
