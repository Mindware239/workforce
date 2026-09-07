import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/attendence/providers/attendance_provider.dart';
import 'package:workforce/features/schedule/data/payslip_pdf_service.dart';

class MonthlySummaryScreen extends ConsumerStatefulWidget {
  const MonthlySummaryScreen({super.key});

  @override
  ConsumerState<MonthlySummaryScreen> createState() =>
      _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends ConsumerState<MonthlySummaryScreen> {
  late DateTime selectedMonth;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    selectedMonth = DateTime(now.year, now.month);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _loadReport();
    });
  }

  // ============================================================
  // LOAD REPORT
  // ============================================================

  void _loadReport() {
    ref
        .read(attendanceProvider.notifier)
        .getMonthlyReport(year: selectedMonth.year, month: selectedMonth.month);
  }

  // ============================================================
  // PREVIOUS MONTH
  // ============================================================

  void _previousMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
    });

    _loadReport();
  }

  // ============================================================
  // NEXT MONTH
  // ============================================================

  void _nextMonth() {
    final now = DateTime.now();

    final currentMonth = DateTime(now.year, now.month);

    final nextMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);

    if (nextMonth.isAfter(currentMonth)) {
      return;
    }

    setState(() {
      selectedMonth = nextMonth;
    });

    _loadReport();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.whiteBackgroundColor,
        surfaceTintColor: AppColors.whiteBackgroundColor,
        elevation: 0,
        title: Text(
          'Monthly Summary',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textColor,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _loadReport();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: state.isLoadingMonthlyReport
                ? _buildLoading()
                : state.monthlyReport == null
                ? _buildError(state.message ?? 'Unable to load monthly report.')
                : _buildContent(state.monthlyReport!),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent(Map<String, dynamic> data) {
    final summary = _map(data['summary']);

    final employee = _map(data['employee']);

    final organization = _map(data['organization']);

    final payslip = _map(data['payslip']);

    final pay = _map(data['pay']);

    final dailyTable = _list(data['dailyTable']);

    final year = _int(data['year']) ?? selectedMonth.year;

    final month = _int(data['month']) ?? selectedMonth.month;

    final downloadEnabled = data['payslipDownloadEnabled'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(year, month, employee),

        const SizedBox(height: 16),

        _buildAttendanceRate(summary),

        const SizedBox(height: 16),

        _buildMiniStats(summary, dailyTable),

        const SizedBox(height: 16),

        _buildHoursLogged(summary),

        const SizedBox(height: 16),

        _buildWeeklyBreakdown(dailyTable),

        const SizedBox(height: 16),

        _buildExceptions(dailyTable),

        const SizedBox(height: 16),

        _buildPayslip(payslip, pay, year, month, summary, downloadEnabled),

        const SizedBox(height: 16),

        _buildOrganization(organization),
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(int year, int month, Map<String, dynamic> employee) {
    final name = employee['fullName']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_monthName(month)} Summary',
                style: GoogleFonts.inter(
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
            ),

            _MonthButton(icon: Icons.chevron_left, onTap: _previousMonth),

            const SizedBox(width: 5),

            _MonthButton(
              icon: Icons.chevron_right,
              enabled: !_isCurrentMonth(year, month),
              onTap: _nextMonth,
            ),
          ],
        ),

        const SizedBox(height: 7),

        Text(
          name != null && name.isNotEmpty
              ? '$name · Your monthly performance and attendance overview.'
              : 'Your monthly performance and attendance overview.',
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.2,
            color: AppColors.mutedColor,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ATTENDANCE RATE
  // ============================================================

  Widget _buildAttendanceRate(Map<String, dynamic> summary) {
    final totalWorkingDays = _int(summary['totalWorkingDays']) ?? 0;

    final presentDays = _int(summary['presentDays']) ?? 0;

    final absentDays = _int(summary['absentDays']) ?? 0;

    final halfDays = _int(summary['halfDays']) ?? 0;

    final attendanceRate = totalWorkingDays > 0
        ? ((presentDays + (halfDays * 0.5)) / totalWorkingDays) * 100
        : 0;

    return _SummaryCard(
      height: 104,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'ATTENDANCE RATE',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .35,
                    color: AppColors.mutedColor,
                  ),
                ),

                const Spacer(),

                const Icon(
                  Icons.verified_outlined,
                  size: 16,
                  color: AppColors.primaryFillColor,
                ),
              ],
            ),

            const Spacer(),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${attendanceRate.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor,
                  ),
                ),

                const SizedBox(width: 12),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2DFFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$presentDays present · $absentDays absent',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryFillColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MINI STATS
  // ============================================================

  Widget _buildMiniStats(
    Map<String, dynamic> summary,
    List<Map<String, dynamic>> dailyTable,
  ) {
    final presentDays = _int(summary['presentDays']) ?? 0;

    final totalDays = _int(summary['totalWorkingDays']) ?? 0;

    final productivity = _calculateAverageProductivity(dailyTable);

    return Row(
      children: [
        Expanded(
          child: _SmallStatCard(
            title: 'DAYS WORKED',
            value: presentDays.toString(),
            secondaryValue: ' / $totalDays',
            icon: Icons.calendar_today_outlined,
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: _SmallStatCard(
            title: 'AVG PRODUCTIVITY',
            value: '${productivity.toStringAsFixed(0)}%',
            icon: Icons.trending_up,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HOURS LOGGED
  // ============================================================

  Widget _buildHoursLogged(Map<String, dynamic> summary) {
    final totalWorkingHours = _double(summary['totalWorkingHours']) ?? 0;

    final overtimeHours = _double(summary['overtimeHours']) ?? 0;

    return _SummaryCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL HOURS LOGGED',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .3,
                      color: AppColors.mutedColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: totalWorkingHours.toStringAsFixed(
                            totalWorkingHours ==
                                    totalWorkingHours.roundToDouble()
                                ? 0
                                : 1,
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textColor,
                          ),
                        ),

                        TextSpan(
                          text: ' h',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedColor,
                          ),
                        ),

                        if (overtimeHours > 0) ...[
                          TextSpan(
                            text: ' · ',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.mutedColor,
                            ),
                          ),
                          TextSpan(
                            text:
                                '${overtimeHours.toStringAsFixed(1)}h Overtime',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF7E3000),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.chevron_right,
                size: 14,
                color: AppColors.mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WEEKLY BREAKDOWN
  // ============================================================

  Widget _buildWeeklyBreakdown(List<Map<String, dynamic>> records) {
    final weeklyHours = _calculateWeeklyHours(records);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Hours Breakdown',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textColor,
          ),
        ),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor, width: 1),
          ),
          child: _WeeklyChart(weeklyHours: weeklyHours),
        ),
      ],
    );
  }

  // ============================================================
  // EXCEPTIONS
  // ============================================================

  Widget _buildExceptions(List<Map<String, dynamic>> records) {
    final exceptions = records.where((record) {
      final status = record['status']?.toString();

      final late = _int(record['lateMinutes']) ?? 0;

      final early = _int(record['earlyExitMinutes']) ?? 0;

      return status == 'late' ||
          late > 0 ||
          early > 0 ||
          status == 'absent' ||
          status == 'half_day';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notable Exceptions',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textColor,
          ),
        ),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor, width: 1),
          ),
          child: exceptions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'No notable exceptions this month.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.mutedColor,
                    ),
                  ),
                )
              : Column(
                  children: List.generate(exceptions.length, (index) {
                    final record = exceptions[index];

                    return _ExceptionRow(
                      icon: Icons.access_time,
                      title: _exceptionTitle(record),
                      subtitle: _exceptionSubtitle(record),
                      color: const Color(0xFFD9414D),
                      isLast: index == exceptions.length - 1,
                    );
                  }),
                ),
        ),
      ],
    );
  }

  // ============================================================
  // PAYSLIP
  // ============================================================

  Widget _buildPayslip(
    Map<String, dynamic> payslip,
    Map<String, dynamic> pay,
    int year,
    int month,
    Map<String, dynamic> summary,
    bool downloadEnabled,
  ) {
    final netSalary =
        _double(payslip['netSalary']) ?? _double(pay['estimatedTotal']) ?? 0;

    final basicSalary = _double(payslip['basicSalary']) ?? 0;

    final overtimePay = _double(payslip['overtimePay']) ?? 0;

    final totalEarnings = _double(payslip['totalEarnings']) ?? 0;

    final pf = _double(payslip['pf']) ?? 0;

    final esi = _double(payslip['esi']) ?? 0;

    final attendanceDeduction = _double(payslip['attendanceDeduction']) ?? 0;

    final totalDeductions = _double(payslip['totalDeductions']) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Payslip',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textColor,
              ),
            ),

            const Spacer(),

            if (downloadEnabled)
              TextButton.icon(
                onPressed: () async {
                  try {
                    final result = await PayslipPdfService.generate(
                      year: year,
                      month: month,
                      summary: summary,
                    );

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${result.fileName} saved to Downloads.'),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceFirst('Exception: ', ''),
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Download'),
              ),
          ],
        ),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Column(
            children: [
              _PayRow(label: 'Basic Salary', value: _money(basicSalary)),

              _PayRow(label: 'Overtime Pay', value: _money(overtimePay)),

              _PayRow(
                label: 'Total Earnings',
                value: _money(totalEarnings),
                bold: true,
              ),

              const Divider(height: 20),

              _PayRow(label: 'PF', value: '-${_money(pf)}'),

              _PayRow(label: 'ESI', value: '-${_money(esi)}'),

              _PayRow(
                label: 'Attendance Deduction',
                value: '-${_money(attendanceDeduction)}',
              ),

              _PayRow(
                label: 'Total Deductions',
                value: '-${_money(totalDeductions)}',
                bold: true,
              ),

              const Divider(height: 20),

              Row(
                children: [
                  Text(
                    'Net Salary',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _money(netSalary),
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryFillColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ORGANIZATION
  // ============================================================

  Widget _buildOrganization(Map<String, dynamic> organization) {
    final name = organization['name']?.toString();

    final workspace = organization['workspaceName']?.toString();

    final address = organization['workspaceAddress']?.toString();

    if (name == null && workspace == null && address == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Organization',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textColor,
            ),
          ),

          const SizedBox(height: 10),

          if (name != null) _InfoLine(label: 'Company', value: name),

          if (workspace != null)
            _InfoLine(label: 'Workspace', value: workspace),

          if (address != null) _InfoLine(label: 'Address', value: address),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return Column(
      children: [
        Container(
          height: 104,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(child: _loadingBox()),
            const SizedBox(width: 8),
            Expanded(child: _loadingBox()),
          ],
        ),

        const SizedBox(height: 16),

        _loadingBox(height: 150),
      ],
    );
  }

  Widget _loadingBox({double height = 100}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 38, color: Colors.redAccent),

          const SizedBox(height: 10),

          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textColor),
          ),

          const SizedBox(height: 12),

          ElevatedButton(onPressed: _loadReport, child: const Text('Retry')),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int? _int(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  double? _double(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  String _money(double value) {
    return '₹${value.toStringAsFixed(2)}';
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }

  bool _isCurrentMonth(int year, int month) {
    final now = DateTime.now();

    return year == now.year && month == now.month;
  }

  double _calculateAverageProductivity(List<Map<String, dynamic>> records) {
    final values = records
        .map((record) => _double(record['productivityPercent']))
        .whereType<double>()
        .toList();

    if (values.isEmpty) {
      return 0;
    }

    return values.reduce((a, b) => a + b) / values.length;
  }

  List<double> _calculateWeeklyHours(List<Map<String, dynamic>> records) {
    final weeks = List<double>.filled(5, 0);

    for (final record in records) {
      final date = DateTime.tryParse(record['date']?.toString() ?? '');

      if (date == null) continue;

      final week = ((date.day - 1) ~/ 7).clamp(0, 4);

      final minutes = _int(record['workingMinutes']) ?? 0;

      weeks[week] += minutes / 60;
    }

    return weeks;
  }

  String _exceptionTitle(Map<String, dynamic> record) {
    final status = record['status']?.toString();

    final late = _int(record['lateMinutes']) ?? 0;

    final early = _int(record['earlyExitMinutes']) ?? 0;

    if (status == 'absent') {
      return 'Absent';
    }

    if (late > 0 || status == 'late') {
      return 'Late Arrival';
    }

    if (early > 0) {
      return 'Early Exit';
    }

    return 'Attendance Exception';
  }

  String _exceptionSubtitle(Map<String, dynamic> record) {
    final date = record['date']?.toString() ?? '';

    final late = _int(record['lateMinutes']) ?? 0;

    final early = _int(record['earlyExitMinutes']) ?? 0;

    if (late > 0) {
      return '$date · $late mins late';
    }

    if (early > 0) {
      return '$date · $early mins early';
    }

    return '$date · ${record['status'] ?? 'Exception'}';
  }

  void _showDownloadMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Payslip download endpoint is not available in the provided API.',
        ),
      ),
    );
  }
}

// ================================================================
// SUMMARY CARD
// ================================================================

class _SummaryCard extends StatelessWidget {
  final Widget child;
  final double? height;

  const _SummaryCard({required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: .8),
      ),
      child: child,
    );
  }
}

// ================================================================
// SMALL STAT CARD
// ================================================================

class _SmallStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? secondaryValue;
  final IconData icon;

  const _SmallStatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.secondaryValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 114,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: .35,
              color: AppColors.mutedColor,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textColor,
                ),
              ),

              if (secondaryValue != null)
                Text(
                  secondaryValue!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.mutedColor,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderColor, width: 1),
            ),
            child: Icon(icon, size: 16, color: AppColors.mutedColor),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// PAY ROW
// ================================================================

class _PayRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _PayRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color: AppColors.textColor,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// INFO LINE
// ================================================================

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 75,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.mutedColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// EXCEPTION ROW
// ================================================================

class _ExceptionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isLast;

  const _ExceptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.borderColor, width: .7),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: .10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textColor,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedColor,
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

// ================================================================
// MONTH BUTTON
// ================================================================

class _MonthButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _MonthButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? AppColors.borderColor : const Color(0xFFEDE7E9),
          ),
        ),
        child: Icon(
          icon,
          size: 17,
          color: enabled ? AppColors.textColor : const Color(0xFFD4CCCF),
        ),
      ),
    );
  }
}

// ================================================================
// WEEKLY CHART
// ================================================================

class _WeeklyChart extends StatelessWidget {
  final List<double> weeklyHours;

  const _WeeklyChart({required this.weeklyHours});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WeeklyChartPainter(weeklyHours: weeklyHours),
      child: const SizedBox.expand(),
    );
  }
}

class _WeeklyChartPainter extends CustomPainter {
  final List<double> weeklyHours;

  _WeeklyChartPainter({required this.weeklyHours});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    const left = 2.0;
    final right = width - 2;

    const top = 8.0;
    final bottom = height - 22;

    final chartWidth = right - left;

    final chartHeight = bottom - top;

    final gridPaint = Paint()
      ..color = const Color(0xFFD9C5CC)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke;

    final baselinePaint = Paint()
      ..color = const Color(0xFFB99FA8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final linePaint = Paint()
      ..color = const Color(0xFF9B6AE8)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = const Color(0xFF9B6AE8)
      ..style = PaintingStyle.fill;

    canvas.drawLine(Offset(left, top), Offset(right, top), gridPaint);

    canvas.drawLine(
      Offset(left, top + chartHeight * .5),
      Offset(right, top + chartHeight * .5),
      gridPaint,
    );

    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), baselinePaint);

    final maxHours = weeklyHours.isEmpty
        ? 1
        : weeklyHours.reduce((a, b) => a > b ? a : b) <= 0
        ? 1
        : weeklyHours.reduce((a, b) => a > b ? a : b);

    final points = <Offset>[];

    for (int i = 0; i < weeklyHours.length; i++) {
      final x = weeklyHours.length == 1
          ? left
          : left + chartWidth * (i / (weeklyHours.length - 1));

      final normalized = weeklyHours[i] / maxHours;

      final y = bottom - chartHeight * normalized;

      points.add(Offset(x, y));
    }

    if (points.isNotEmpty) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);

      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }

      canvas.drawPath(path, linePaint);

      for (final point in points) {
        canvas.drawCircle(point, 3.5, pointPaint);
      }
    }

    const labels = ['W1', 'W2', 'W3', 'W4', 'W5'];

    for (int i = 0; i < labels.length; i++) {
      final x = weeklyHours.length >= 5
          ? left + chartWidth * (i / 4)
          : left + chartWidth * (i / 4);

      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 8,
            fontWeight: FontWeight.w500,
            color: Color(0xFF75666C),
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      textPainter.paint(canvas, Offset(x - textPainter.width / 2, bottom + 10));
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyChartPainter oldDelegate) {
    return oldDelegate.weeklyHours != weeklyHours;
  }
}
