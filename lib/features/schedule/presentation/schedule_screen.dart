import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/attendence/providers/attendance_provider.dart';
import 'package:workforce/features/schedule/presentation/monthly_summary.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _selectedMonth = DateTime(now.year, now.month);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSalary();
    });
  }

  Future<void> _loadSalary() async {
    await ref
        .read(attendanceProvider.notifier)
        .getMySalary(year: _selectedMonth.year, month: _selectedMonth.month);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });

    _loadSalary();
  }

  void _nextMonth() {
    final now = DateTime.now();

    final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);

    if (nextMonth.isAfter(DateTime(now.year, now.month))) {
      return;
    }

    setState(() {
      _selectedMonth = nextMonth;
    });

    _loadSalary();
  }

  String _formatMoney(dynamic value) {
    final amount = double.tryParse(value?.toString() ?? '0') ?? 0;

    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: amount % 1 == 0 ? 0 : 2,
    ).format(amount);
  }

  String _monthName() {
    return DateFormat('MMMM\nyyyy').format(_selectedMonth);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);

    final salary = state.salarySnapshot?['liveSalary'];

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.whiteBackgroundColor,
        surfaceTintColor: AppColors.whiteBackgroundColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
      
              const SizedBox(height: 16),
        
              if (state.isLoadingSalary && salary == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (state.message != null && salary == null)
                _buildError(state.message!)
              else if (salary != null) ...[
                _buildNetSalary(salary),
        
                const SizedBox(height: 24),
        
                _buildEarnings(salary),
        
                const SizedBox(height: 24),
        
                _buildDeductions(salary),
        
                const SizedBox(height: 24),
        
                _buildAttendance(salary),
        
                const SizedBox(height: 24),
        
                _buildLiveProgress(salary),
        
                const SizedBox(height: 24),
        
                _buildDownloadButton(),
              ] else
                _buildEmpty(),
        
              const SizedBox(height: 16),
        
              _buildPreviousMonths(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Salary\nSummary',
          style: GoogleFonts.inter(
            fontSize: 30,
            height: .95,
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),

        Container(
          width: 145,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF0ECF9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _MonthButton(
                icon: Icons.chevron_left_rounded,
                onTap: _previousMonth,
              ),

              Expanded(
                child: Center(
                  child: Text(
                    _monthName(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: .95,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedColor,
                    ),
                  ),
                ),
              ),

              _MonthButton(
                icon: Icons.chevron_right_rounded,
                onTap: _nextMonth,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNetSalary(Map<String, dynamic> salary) {
    final projectedNet = salary['projectedNet'];

    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Projected Net Salary',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedColor),
          ),

          const SizedBox(height: 4),

          Text(
            _formatMoney(projectedNet),
            style: GoogleFonts.inter(
              fontSize: 36,
              height: 1,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
          ),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4EA),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 15,
                  color: Color(0xFF137333),
                ),

                const SizedBox(width: 6),

                Text(
                  'Live salary estimate',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF137333),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarnings(Map<String, dynamic> salary) {
    final grossSalary = salary['grossSalary'] ?? 0;

    final overtimePay = salary['overtimePay'] ?? 0;

    final accruedGross = salary['accruedGross'] ?? 0;

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SectionHeader(
            icon: Icons.add_circle_outline,
            title: 'Earnings',
            color: AppColors.primaryFillColor,
          ),

          _SalaryRow(title: 'Gross Salary', amount: _formatMoney(grossSalary)),

          _SalaryRow(
            title: 'Accrued To Date',
            amount: _formatMoney(accruedGross),
          ),

          _SalaryRow(title: 'Overtime', amount: _formatMoney(overtimePay)),
        ],
      ),
    );
  }

  Widget _buildDeductions(Map<String, dynamic> salary) {
    final deductions = salary['deductionsToDate'] ?? 0;

    final projectedDeductions = salary['projectedDeductions'] ?? 0;

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SectionHeader(
            icon: Icons.remove_circle_outline,
            title: 'Deductions',
            color: const Color(0xFFBA1A1A),
          ),

          _SalaryRow(
            title: 'Deductions To Date',
            amount: '-${_formatMoney(deductions)}',
            amountColor: const Color(0xFFBA1A1A),
          ),

          _SalaryRow(
            title: 'Projected Deductions',
            amount: '-${_formatMoney(projectedDeductions)}',
            amountColor: const Color(0xFFBA1A1A),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAttendance(Map<String, dynamic> salary) {
    final workingDays = salary['workingDaysInMonth'] ?? 0;

    final worked = salary['daysWorkedToDate'] ?? 0;

    final remaining = salary['workingDaysRemaining'] ?? 0;

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _SectionHeader(
            icon: Icons.badge_outlined,
            title: 'Attendance Summary',
            color: AppColors.mutedColor,
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _AttendanceValue(
                    value: '$workingDays',
                    label: 'WORKING DAYS',
                  ),
                ),

                Container(width: 1, height: 40, color: AppColors.borderColor),

                Expanded(
                  child: _AttendanceValue(
                    value: '$worked',
                    label: 'DAYS WORKED',
                    valueColor: AppColors.primaryFillColor,
                  ),
                ),

                Container(width: 1, height: 40, color: AppColors.borderColor),

                Expanded(
                  child: _AttendanceValue(
                    value: '$remaining',
                    label: 'DAYS REMAINING',
                    valueColor: AppColors.mutedColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveProgress(Map<String, dynamic> salary) {
    final accruedGross =
        double.tryParse(salary['accruedGross']?.toString() ?? '0') ?? 0;

    final grossSalary =
        double.tryParse(salary['grossSalary']?.toString() ?? '0') ?? 0;

    final progress = grossSalary > 0
        ? (accruedGross / grossSalary).clamp(0.0, 1.0)
        : 0.0;

    final elapsed = salary['workingDaysElapsed'] ?? 0;

    final remaining = salary['workingDaysRemaining'] ?? 0;

    final asOfDate = salary['asOfDate']?.toString();

    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Live Salary Progress',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor,
                ),
              ),

              const Spacer(),

              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryFillColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primaryFillColor,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Text(
                  '$elapsed working days elapsed',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedColor,
                  ),
                ),
              ),

              Text(
                '$remaining remaining',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.mutedColor,
                ),
              ),
            ],
          ),

          if (asOfDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Calculated as of $asOfDate',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.mutedColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payslip download is not available yet.'),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryFillColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.download_outlined, size: 18),
        label: Text(
          'Download Payslip',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildPreviousMonths() {
    return Center(
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MonthlySummaryScreen()),
          );
        },
        child: Text(
          'View Previous Months →',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.primaryFillColor,
          ),
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return _Card(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: Color(0xFFBA1A1A),
          ),

          const SizedBox(height: 12),

          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedColor),
          ),

          const SizedBox(height: 16),

          ElevatedButton(onPressed: _loadSalary, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return _Card(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          'No salary information available.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedColor),
        ),
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 30,
        height: 30,
        child: Icon(icon, size: 18, color: AppColors.mutedColor),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const _Card({required this.child, this.height, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),

              const SizedBox(width: 7),

              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          const Divider(height: 1, thickness: 1, color: AppColors.borderColor),
        ],
      ),
    );
  }
}

class _SalaryRow extends StatelessWidget {
  final String title;
  final String amount;
  final bool isTotal;
  final Color? amountColor;

  const _SalaryRow({
    required this.title,
    required this.amount,
    this.isTotal = false,
    this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, isTotal ? 12 : 9, 16, isTotal ? 12 : 9),
      child: Column(
        children: [
          if (isTotal)
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.borderColor,
            ),

          if (isTotal) const SizedBox(height: 12),

          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
                  color: AppColors.textColor,
                ),
              ),

              const Spacer(),

              Text(
                amount,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
                  color: amountColor ?? AppColors.textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceValue extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const _AttendanceValue({
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 30,
            height: 1,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.textColor,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.mutedColor,
          ),
        ),
      ],
    );
  }
}
