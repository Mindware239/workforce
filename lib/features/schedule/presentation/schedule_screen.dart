import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/schedule/presentation/monthly_summary.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          // physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),

              const SizedBox(height: 16),

              _buildNetSalary(),

              const SizedBox(height: 24),

              _buildEarnings(),

              const SizedBox(height: 24),

              _buildDeductions(),

              const SizedBox(height: 24),

              _buildAttendance(),

              const SizedBox(height: 24),

              _buildDownloadButton(),

              const SizedBox(height: 16),

              _buildPreviousMonths(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      child: Row(
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

          // const Spacer(),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MonthlySummaryScreen(),
                ),
              );
            },
            child: Container(
              width: 118,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0ECF9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'October\n2023',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: .95,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedColor,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: AppColors.mutedColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetSalary() {
    return _Card(
      // height: 65,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Net Salary',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedColor),
          ),

          const SizedBox(height: 4),

          Text(
            '₹24,500',
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
                  Icons.check_box_outlined,
                  size: 16,
                  color: Color(0xFF137333),
                ),
                const SizedBox(width: 8),
                Text(
                  'Status: Credited',
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

  Widget _buildEarnings() {
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SectionHeader(
            icon: Icons.add_circle_outline,
            title: 'Earnings',
            color: AppColors.primaryFillColor,
          ),

          _SalaryRow(title: 'Basic Salary', amount: '₹20,000'),

          _SalaryRow(title: 'Overtime', amount: '₹5,000'),

          const SizedBox(height: 2),

          _SalaryRow(title: 'Total Earnings', amount: '₹25,000', isTotal: true),
        ],
      ),
    );
  }

  Widget _buildDeductions() {
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
            title: 'PF/ESI',
            amount: '-₹500',
            amountColor: const Color(0xFFBA1A1A),
          ),

          const SizedBox(height: 2),

          _SalaryRow(
            title: 'Total Deductions',
            amount: '-₹500',
            isTotal: true,
            amountColor: const Color(0xFFBA1A1A),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendance() {
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
                  child: _AttendanceValue(value: '26', label: 'WORKING DAYS'),
                ),

                Container(width: 1, height: 40, color: AppColors.borderColor),

                Expanded(
                  child: _AttendanceValue(
                    value: '25',
                    label: 'DAYS WORKED',
                    valueColor: AppColors.primaryFillColor,
                  ),
                ),

                Container(width: 1, height: 40, color: AppColors.borderColor),

                Expanded(
                  child: _AttendanceValue(value: '1', label: 'LEAVE/ABSENT', valueColor: const Color(0xFFBA1A1A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () {},
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
        onTap: () {},
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
}

// ================================================================
// CARD
// ================================================================

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
