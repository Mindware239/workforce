import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/pay/providers/pay_provider.dart';

/// My pay: the finalized payroll for one month, read back to the employee.
///
/// Mirrors the web employee salary screen. A month that has not been
/// finalized shows its state rather than its figures; a finalized month shows
/// net pay, earnings, deductions, the attendance basis, the payslip PDF the
/// server rendered, and the full working folded away underneath.
class MyPayScreen extends ConsumerStatefulWidget {
  const MyPayScreen({super.key});

  @override
  ConsumerState<MyPayScreen> createState() => _MyPayScreenState();
}

class _MyPayScreenState extends ConsumerState<MyPayScreen> {
  bool _showWorking = false;
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(payProvider.notifier).load();
    });
  }

  String _periodLabel(int year, int month, {bool short = false}) {
    return DateFormat(short ? 'MMM yyyy' : 'MMMM yyyy')
        .format(DateTime(year, month));
  }

  Future<void> _pickPeriod(PayState state) async {
    final now = DateTime.now();
    var year = state.year;
    var month = state.month;
    final years = [for (var i = 0; i < 4; i++) now.year - i];

    final picked = await showDialog<(int, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            ref.tr('pay.choosePeriod'),
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: month,
                  isExpanded: true,
                  decoration: featureInputDecoration(ref.tr('pay.month')),
                  items: [
                    for (var m = 1; m <= 12; m++)
                      if (!(year == now.year && m > now.month))
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            DateFormat('MMMM').format(DateTime(2000, m)),
                          ),
                        ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => month = value);
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<int>(
                  initialValue: year,
                  isExpanded: true,
                  decoration: featureInputDecoration(ref.tr('pay.year')),
                  items: [
                    for (final y in years)
                      DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setDialogState(() {
                      year = value;

                      if (year == now.year && month > now.month) {
                        month = now.month;
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(ref.tr('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop((year, month)),
              child: Text(ref.tr('pay.show')),
            ),
          ],
        ),
      ),
    );

    if (picked != null) {
      await ref.read(payProvider.notifier).selectPeriod(picked.$1, picked.$2);
    }
  }

  Future<void> _download(Map<String, dynamic> payslip) async {
    final id = toInt(payslip['id']);

    if (id == null) return;

    final number = payslip['number']?.toString() ?? 'payslip-$id';

    try {
      final path = await ref
          .read(payProvider.notifier)
          .downloadPayslip(payslipId: id, fileName: number);

      if (!mounted) return;

      showFeatureSnack(
        context,
        fill(ref.tr('pay.payslipSaved'), {'path': path}),
      );
    } catch (e) {
      if (!mounted) return;

      showFeatureSnack(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(payProvider);

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(payProvider.notifier).load(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              FeatureHeading(
                title: ref.tr('pay.title'),
                subtitle: ref.tr('pay.subtitle'),
              ),
              const SizedBox(height: 14),
              _buildPeriodBar(state),
              const SizedBox(height: 14),
              ..._buildBody(state),
              // const SizedBox(height: 16),
              // _buildBankLink(),
              const SizedBox(height: 8),
              _buildHistory(state),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // PERIOD
  // ==========================================================================

  Widget _buildPeriodBar(PayState state) {
    return Row(
      children: [
        IconButton(
          tooltip: ref.tr('pay.previousMonth'),
          onPressed: state.isLoading
              ? null
              : () => ref.read(payProvider.notifier).shift(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Center(
            child: OutlinedButton.icon(
              onPressed: () => _pickPeriod(state),
              icon: const Icon(
                Icons.calendar_month_outlined,
                size: 18,
                color: AppColors.saffronText,
              ),
              label: Text(
                _periodLabel(state.year, state.month),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor,
                ),
              ),
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                side: const BorderSide(color: AppColors.borderColor),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: ref.tr('pay.nextMonth'),
          onPressed: state.isLoading || state.isCurrentMonth
              ? null
              : () => ref.read(payProvider.notifier).shift(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  // ==========================================================================
  // BODY
  // ==========================================================================

  List<Widget> _buildBody(PayState state) {
    if (state.isLoading && state.data == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (state.error != null && state.data == null) {
      return [
        LoadErrorView(
          message: state.error!,
          retryLabel: ref.tr('common.retry'),
          onRetry: () => ref.read(payProvider.notifier).loadMonth(),
        ),
      ];
    }

    final data = state.data;

    if (data == null) return const [];

    final record = state.record;

    return [
      _NetCard(data: data, record: record),
      const SizedBox(height: 14),
      if (record == null)
        _buildUnavailable(data)
      else ...[
        _LinesBlock(
          title: ref.tr('pay.earnings'),
          icon: Icons.add_circle_outline_rounded,
          minus: false,
          items: asItems(record['earnings']),
          totalLabel: ref.tr('pay.totalEarnings'),
          total: toNum(record['grossEarnings']) ?? 0,
        ),
        if (asItems(record['deductions']).isNotEmpty) ...[
          const SizedBox(height: 12),
          _LinesBlock(
            title: ref.tr('pay.deductions'),
            icon: Icons.remove_circle_outline_rounded,
            minus: true,
            items: asItems(record['deductions']),
            totalLabel: ref.tr('pay.totalDeductions'),
            total: toNum(record['totalDeductions']) ?? 0,
          ),
        ],
        const SizedBox(height: 12),
        _AttendanceSummary(record: record),
        const SizedBox(height: 16),
        _buildPayslipAction(state, record),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _showWorking = !_showWorking),
            child: Text(
              ref.tr(_showWorking ? 'pay.hideWorking' : 'pay.showWorking'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.saffronText,
              ),
            ),
          ),
        ),
        if (_showWorking) _Working(record: record),
      ],
    ];
  }

  Widget _buildUnavailable(Map<String, dynamic> data) {
    final notFinalized = data['reason'] == 'not_finalized';
    final runStatus = data['runStatus']?.toString();

    return FeatureCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          Icon(
            notFinalized
                ? Icons.hourglass_top_rounded
                : Icons.event_busy_outlined,
            size: 32,
            color: AppColors.mutedColor,
          ),
          const SizedBox(height: 10),
          Text(
            ref.tr(notFinalized ? 'pay.beingPrepared' : 'pay.noPayrollYet'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ref.tr(
              notFinalized ? 'pay.beingPreparedNote' : 'pay.noPayrollYetNote',
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: AppColors.mutedColor,
            ),
          ),
          if (notFinalized && runStatus != null) ...[
            const SizedBox(height: 12),
            StatusChip(
              label: ref.tr('pay.run_$runStatus'),
              tone: ChipTone.info,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPayslipAction(PayState state, Map<String, dynamic> record) {
    final payslip = record['payslip'];

    if (payslip is! Map) {
      return Text(
        ref.tr('pay.payslipNotReady'),
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedColor),
      );
    }

    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: state.isDownloading
            ? null
            : () => _download(Map<String, dynamic>.from(payslip)),
        icon: state.isDownloading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : const Icon(Icons.download_rounded),
        label: Text(
          ref.tr('pay.downloadPayslip'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // Widget _buildBankLink() {
  //   return FeatureCard(
  //     onTap: () => context.push(AppRoutes.profile),
  //     child: Row(
  //       children: [
  //         const Icon(
  //           Icons.account_balance_outlined,
  //           color: AppColors.saffronText,
  //         ),
  //         const SizedBox(width: 12),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 ref.tr('pay.bankDetails'),
  //                 style: GoogleFonts.inter(
  //                   fontSize: 14,
  //                   fontWeight: FontWeight.w600,
  //                   color: AppColors.textColor,
  //                 ),
  //               ),
  //               const SizedBox(height: 2),
  //               Text(
  //                 ref.tr('pay.bankDetailsHint'),
  //                 style: GoogleFonts.inter(
  //                   fontSize: 12,
  //                   color: AppColors.mutedColor,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //         const Icon(Icons.chevron_right_rounded, color: AppColors.mutedColor),
  //       ],
  //     ),
  //   );
  // }

  // ==========================================================================
  // PREVIOUS MONTHS
  // ==========================================================================

  Widget _buildHistory(PayState state) {
    if (state.history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: TextButton(
            onPressed: () => setState(() => _showHistory = !_showHistory),
            child: Text(
              ref.tr('pay.previousMonths'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.saffronText,
              ),
            ),
          ),
        ),
        if (_showHistory)
          for (final row in state.history) _historyRow(state, row),
      ],
    );
  }

  Widget _historyRow(PayState state, Map<String, dynamic> row) {
    final year = toInt(row['year']) ?? 0;
    final month = toInt(row['month']) ?? 1;
    final current = year == state.year && month == state.month;
    final paymentStatus = row['paymentStatus']?.toString() ?? 'pending';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FeatureCard(
        onTap: () {
          setState(() => _showHistory = false);
          ref.read(payProvider.notifier).selectPeriod(year, month);
        },
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _periodLabel(year, month),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: current
                          ? AppColors.saffronText
                          : AppColors.textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${ref.tr('pay.grossShort')} ${formatInr(toNum(row['grossEarnings']))}'
                    ' · ${ref.tr('pay.deductionsShort')} ${formatInr(toNum(row['totalDeductions']))}',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: AppColors.mutedColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatInr(toNum(row['netPay'])),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                StatusChip(
                  label: ref.tr('pay.payment_$paymentStatus'),
                  tone: paymentTone(paymentStatus),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HELPERS
// ============================================================================

List<Map<String, dynamic>> asItems(dynamic value) {
  if (value is! List) return const [];

  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

ChipTone paymentTone(String? status) {
  switch (status) {
    case 'paid':
      return ChipTone.success;
    case 'processing':
      return ChipTone.info;
    case 'failed':
      return ChipTone.danger;
    case 'pending':
      return ChipTone.warning;
    default:
      return ChipTone.neutral;
  }
}

/// Half days are real; whole days should not read "12.0".
String formatDays(dynamic value) {
  final n = toNum(value) ?? 0;

  return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);
}

// ============================================================================
// NET PAY CARD
// ============================================================================

class _NetCard extends ConsumerWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic>? record;

  const _NetCard({required this.data, required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payment = record?['payment'];
    final paid = payment is Map && payment['status'] == 'paid';

    final String status;

    if (record != null) {
      status = ref.tr(paid ? 'pay.statusCredited' : 'pay.statusPending');
    } else if (data['reason'] == 'not_finalized') {
      status = ref.tr('pay.statusInProgress');
    } else {
      status = ref.tr('pay.statusPending');
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: AppColors.saffronGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ref.tr('pay.netPay'),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onAppBarMutedColor,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              record == null ? '—' : formatInr(toNum(record!['netPay'])),
              style: GoogleFonts.inter(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  paid
                      ? Icons.check_circle_rounded
                      : Icons.hourglass_top_rounded,
                  size: 15,
                  color: paid ? AppColors.indiaGreen : AppColors.saffronText,
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: paid ? AppColors.indiaGreen : AppColors.saffronText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EARNINGS / DEDUCTIONS
// ============================================================================

class _LinesBlock extends ConsumerWidget {
  final String title;
  final IconData icon;
  final bool minus;
  final List<Map<String, dynamic>> items;
  final String totalLabel;
  final num total;

  const _LinesBlock({
    required this.title,
    required this.icon,
    required this.minus,
    required this.items,
    required this.totalLabel,
    required this.total,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const danger = Color(0xFFB3261E);

    return FeatureCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: minus ? danger : AppColors.indiaGreen,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),
          const Divider(height: 22, color: AppColors.borderColor),
          for (final item in items) _line(ref, item, danger),
          const Divider(height: 22, color: AppColors.borderColor),
          Row(
            children: [
              Expanded(
                child: Text(
                  totalLabel,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textColor,
                  ),
                ),
              ),
              Text(
                '${minus ? '-' : ''}${formatInr(total)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: minus ? danger : AppColors.textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(WidgetRef ref, Map<String, dynamic> item, Color danger) {
    final pending = item['approvalStatus'] == 'pending';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Text(
                  item['label']?.toString() ?? item['code']?.toString() ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: AppColors.mutedColor,
                  ),
                ),
                if (pending)
                  Text(
                    ref.tr('pay.awaitingApproval'),
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.saffronText,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${minus ? '-' : ''}${formatInr(toNum(item['amount']))}',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: pending
                  ? AppColors.mutedColor
                  : minus
                      ? danger
                      : AppColors.textColor,
              decoration: pending ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ATTENDANCE SUMMARY
// ============================================================================

class _AttendanceSummary extends ConsumerWidget {
  final Map<String, dynamic> record;

  const _AttendanceSummary({required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaveOrAbsent = (toNum(record['absentDays']) ?? 0) +
        (toNum(record['paidLeaveDays']) ?? 0) +
        (toNum(record['unpaidLeaveDays']) ?? 0);

    Widget figure(String value, String label, Color color) {
      return Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: .5,
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
          Row(
            children: [
              const Icon(
                Icons.event_available_outlined,
                size: 20,
                color: AppColors.indiaGreen,
              ),
              const SizedBox(width: 8),
              Text(
                ref.tr('pay.attendanceSummary'),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              figure(
                formatDays(record['workingDays']),
                ref.tr('pay.workingDays'),
                AppColors.textColor,
              ),
              figure(
                formatDays(record['presentDays']),
                ref.tr('pay.daysWorked'),
                AppColors.saffronText,
              ),
              figure(
                formatDays(leaveOrAbsent),
                ref.tr('pay.leaveAbsent'),
                const Color(0xFFB3261E),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FULL WORKING
// ============================================================================

class _Working extends ConsumerWidget {
  final Map<String, dynamic> record;

  const _Working({required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overtimeMinutes = toNum(record['overtimeMinutes']) ?? 0;
    final overtimeHours = (overtimeMinutes / 60 * 10).round() / 10;
    final pending = asItems(record['pendingEarnings']);
    final employer = asItems(record['employerContributions']);
    final payment = record['payment'] is Map
        ? Map<String, dynamic>.from(record['payment'] as Map)
        : const <String, dynamic>{};
    final paymentStatus = payment['status']?.toString() ?? 'pending';

    final calculated = [
      ...asItems(record['earnings']),
      ...asItems(record['deductions']),
    ].where((item) {
      final calc = item['calculation'];

      return calc is Map && (calc['formula']?.toString().isNotEmpty ?? false);
    }).toList();

    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(ref.tr('pay.attendanceImpact')),
          const SizedBox(height: 6),
          InfoRow(
            label: ref.tr('pay.dayPresent'),
            value: formatDays(record['presentDays']),
          ),
          InfoRow(
            label: ref.tr('pay.dayHalf'),
            value: formatDays(record['halfDays']),
          ),
          InfoRow(
            label: ref.tr('pay.dayAbsent'),
            value: formatDays(record['absentDays']),
          ),
          InfoRow(
            label: ref.tr('pay.dayFieldWork'),
            value: formatDays(record['wfhDays']),
          ),
          InfoRow(
            label: ref.tr('pay.paidLeave'),
            value: formatDays(record['paidLeaveDays']),
          ),
          InfoRow(
            label: ref.tr('pay.unpaidLeave'),
            value: formatDays(record['unpaidLeaveDays']),
          ),
          InfoRow(
            label: ref.tr('pay.lateArrivals'),
            value: '${toInt(record['lateOccurrences']) ?? 0}',
          ),
          InfoRow(
            label: ref.tr('pay.overtimeHours'),
            value: formatDays(overtimeHours),
          ),
          const SizedBox(height: 6),
          Text(
            fill(ref.tr('pay.payableOfWorking'), {
              'payable': formatDays(record['payableDays']),
              'working': formatDays(record['workingDays']),
            }),
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textColor,
            ),
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              fill(ref.tr('pay.pendingEarningsNotice'), {
                'count': pending.length,
              }),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.saffronText,
              ),
            ),
          ],
          if (calculated.isNotEmpty) ...[
            const SizedBox(height: 14),
            SectionTitle(ref.tr('pay.howCalculated')),
            const SizedBox(height: 6),
            for (final item in calculated)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['label']?.toString() ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor,
                      ),
                    ),
                    Text(
                      (item['calculation'] as Map)['formula'].toString(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (employer.isNotEmpty) ...[
            const SizedBox(height: 14),
            SectionTitle(ref.tr('pay.employerContributions')),
            const SizedBox(height: 6),
            for (final item in employer)
              InfoRow(
                label: item['label']?.toString() ?? '',
                value: formatInr(toNum(item['amount'])),
              ),
          ],
          const SizedBox(height: 14),
          SectionTitle(
            ref.tr('pay.payment'),
            trailing: StatusChip(
              label: ref.tr('pay.payment_$paymentStatus'),
              tone: paymentTone(paymentStatus),
            ),
          ),
          const SizedBox(height: 6),
          if (payment['method'] != null)
            InfoRow(
              label: ref.tr('pay.paymentMethod'),
              value: payment['method'].toString(),
            ),
          if (payment['reference'] != null)
            InfoRow(
              label: ref.tr('pay.paymentReference'),
              value: payment['reference'].toString(),
            ),
          InfoRow(
            label: ref.tr('pay.paidOn'),
            value: formatApiDate(payment['paidOn']),
          ),
          InfoRow(
            label: ref.tr('pay.finalizedOn'),
            value: formatApiDate(record['finalizedAt']),
          ),
        ],
      ),
    );
  }
}
