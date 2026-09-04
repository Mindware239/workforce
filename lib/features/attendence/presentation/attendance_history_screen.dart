import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/styles/app_colors.dart';

import '../providers/attendance_provider.dart';

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState
    extends ConsumerState<AttendanceHistoryScreen> {
  late DateTime selectedMonth;
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    selectedMonth = DateTime(now.year, now.month);

    selectedDate = now;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _loadHistory();
    });
  }

  void _loadHistory() {
    ref
        .read(attendanceProvider.notifier)
        .getAttendanceHistory(
          year: selectedMonth.year,
          month: selectedMonth.month,
        );
  }

  void _previousMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);

      selectedDate = null;
    });

    _loadHistory();
  }

  void _nextMonth() {
    final now = DateTime.now();

    final currentMonth = DateTime(now.year, now.month);

    final nextMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);

    if (nextMonth.isAfter(currentMonth)) {
      return;
    }

    setState(() {
      selectedMonth = nextMonth;
      selectedDate = null;
    });

    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
       appBar: AppBar(
        backgroundColor: AppColors.whiteBackgroundColor,
        surfaceTintColor: AppColors.whiteBackgroundColor,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _loadHistory();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),

                const SizedBox(height: 16),

                if (state.isLoadingHistory)
                  _buildLoading()
                else
                  _buildHistoryContent(state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      'Attendance History',
      style: GoogleFonts.inter(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: AppColors.textColor,
      ),
    );
  }

  Widget _buildHistoryContent(AttendanceState state) {
    if (state.message != null && state.historyRecords.isEmpty) {
      return _buildError(state.message!);
    }

    return Column(
      children: [
        _buildMonthCalendar(state),

        const SizedBox(height: 16),

        _buildSummary(state),

        const SizedBox(height: 16),

        //   _buildLogHeader(),

        //   const SizedBox(height: 16),

        //   _buildLogEntries(state),
      ],
    );
  }

  Widget _buildMonthCalendar(AttendanceState state) {
    final daysInMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      0,
    ).day;

    final firstDay = DateTime(selectedMonth.year, selectedMonth.month, 1);

    // Monday = 0 ... Sunday = 6
    final firstWeekday = firstDay.weekday - 1;

    final records = state.historyRecords;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          _buildMonthNavigation(),

          const SizedBox(height: 14),

          _buildWeekHeader(),

          const SizedBox(height: 8),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: firstWeekday + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 3,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              if (index < firstWeekday) {
                return const SizedBox();
              }

              final day = index - firstWeekday + 1;

              final date = DateTime(
                selectedMonth.year,
                selectedMonth.month,
                day,
              );

              final record = _recordForDate(records, date);

              return _CalendarDay(
                date: date,
                record: record,
                isSelected: _isSameDate(selectedDate, date),
                isToday: _isSameDate(DateTime.now(), date),
                onTap: () {
                  setState(() {
                    selectedDate = date;
                  });
                  context.push(AppRoutes.attendance);
                },
              );
            },
          ),

          // const SizedBox(height: 10),

          // _buildCalendarLegend(),
        ],
      ),
    );
  }

  Widget _buildMonthNavigation() {
    final now = DateTime.now();

    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;

    return Row(
      children: [
        _MonthButton(icon: Icons.chevron_left_rounded, onTap: _previousMonth),

        Expanded(
          child: Center(
            child: Text(
              '${_monthName(selectedMonth.month)} ${selectedMonth.year}',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textColor,
              ),
            ),
          ),
        ),

        _MonthButton(
          icon: Icons.chevron_right_rounded,
          enabled: !isCurrentMonth,
          onTap: _nextMonth,
        ),
      ],
    );
  }

  Widget _buildWeekHeader() {
    const days = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];

    return Row(
      children: days.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF8B7C82),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarLegend() {
    return Row(
      children: [
        _LegendItem(color: const Color(0xFFE33D59), text: 'Present'),

        const Spacer(),

        _LegendItem(color: const Color(0xFFF2A21B), text: 'Exception'),
      ],
    );
  }

  Widget _buildSummary(AttendanceState state) {
    final summary = state.historySummary;

    final averageMinutes = summary?['averageWorkingMinutes'] is num
        ? (summary!['averageWorkingMinutes'] as num).toInt()
        : 0;

    final onTimeRate = summary?['onTimeRatePercent'] is num
        ? (summary!['onTimeRatePercent'] as num).toDouble()
        : 0.0;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Avg. Hours',
            value: _formatDuration(averageMinutes),
            valueColor: const Color(0xFF00B889),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _SummaryCard(
            title: 'On-Time Rate',
            value: '${_formatNumber(onTimeRate)}%',
            valueColor: const Color(0xFF7657FF),
          ),
        ),
      ],
    );
  }

  Widget _buildLogHeader() {
    return Row(
      children: [
        Text(
          'LOG ENTRIES',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
            color: AppColors.mutedColor,
          ),
        ),

        const Spacer(),

        Row(
          children: [
            const Icon(
              Icons.file_download_outlined,
              size: 14,
              color: Color(0xFFFF3656),
            ),
            const SizedBox(width: 4),
            Text(
              'Export',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFF3656),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogEntries(AttendanceState state) {
    var records = state.historyRecords;

    if (selectedDate != null) {
      final selectedRecord = _recordForDate(records, selectedDate!);

      if (selectedRecord != null) {
        records = [
          selectedRecord,
          ...records.where((record) => record != selectedRecord),
        ];
      }
    }

    if (records.isEmpty) {
      return _buildEmptyLogs();
    }

    return Column(
      children: records.map((record) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _AttendanceLogCard(record: record),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyLogs() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEADFE3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_busy_outlined,
            size: 32,
            color: Color(0xFFB6AEB2),
          ),
          const SizedBox(height: 8),
          Text(
            'No attendance records',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'No attendance was recorded for this month.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.mutedColor),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 370,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEADFE3)),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: Container(
                height: 78,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 78,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEADFE3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 38,
            color: Colors.redAccent,
          ),

          const SizedBox(height: 10),

          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textColor),
          ),

          const SizedBox(height: 12),

          ElevatedButton(onPressed: _loadHistory, child: const Text('Retry')),
        ],
      ),
    );
  }

  Map<String, dynamic>? _recordForDate(
    List<Map<String, dynamic>> records,
    DateTime date,
  ) {
    for (final record in records) {
      final value = record['date']?.toString();

      if (value == null) continue;

      final parsed = DateTime.tryParse(value);

      if (parsed == null) continue;

      if (_isSameDate(parsed, date)) {
        return record;
      }
    }

    return null;
  }

  bool _isSameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return false;
    }

    return a.year == b.year && a.month == b.month && a.day == b.day;
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

  String _formatDuration(int minutes) {
    if (minutes <= 0) {
      return '0m';
    }

    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours == 0) {
      return '${mins}m';
    }

    if (mins == 0) {
      return '${hours}h';
    }

    return '${hours}h ${mins}m';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }
}

class _CalendarDay extends StatelessWidget {
  final DateTime date;
  final Map<String, dynamic>? record;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  const _CalendarDay({
    required this.date,
    required this.record,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasRecord = record != null;

    final status = record?['status']?.toString();

    final isException =
        status == 'late' || status == 'early_exit' || status == 'absent';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : isException && hasRecord
              ? const Color(0xFFFFF3DB)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: isSelected
              ? Border.all(color: const Color(0xFF29262B), width: 2)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${date.day}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected || isToday
                    ? FontWeight.w700
                    : FontWeight.w400,
                color: hasRecord
                    ? AppColors.textColor
                    : const Color(0xFF202024),
              ),
            ),

            // if (hasRecord)
            //   Positioned(
            //     bottom: 3,
            //     child: Container(
            //       width: 5,
            //       height: 5,
            //       decoration: BoxDecoration(
            //         shape: BoxShape.circle,
            //         color: isException
            //             ? const Color(0xFFF2A21B)
            //             : const Color(0xFFE33D59),
            //       ),
            //     ),
            //   ),
          ],
        ),
      ),
    );
  }
}

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
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? AppColors.primaryFillColor : AppColors.borderColor,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.textColor : AppColors.borderColor,
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6E6469),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.mutedColor,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceLogCard extends StatelessWidget {
  final Map<String, dynamic> record;

  const _AttendanceLogCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(record['date']?.toString() ?? '');

    final entryTime = record['entryTime']?.toString();

    final exitTime = record['exitTime']?.toString();

    final status = record['status']?.toString() ?? 'unknown';

    final workingMinutes = record['totalWorkingMinutes'] is num
        ? (record['totalWorkingMinutes'] as num).toInt()
        : 0;

    final productivity = record['productivityPercent'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEADFE3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _DateBadge(date: date),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date != null ? _weekdayName(date.weekday) : '--',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textColor,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      _timeRange(entryTime, exitTime),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: AppColors.mutedColor,
                      ),
                    ),
                  ],
                ),
              ),

              _StatusBadge(status: status),
            ],
          ),

          const SizedBox(height: 10),

          Container(height: 1, color: const Color(0xFFECE3E6)),

          const SizedBox(height: 9),

          Row(
            children: [
              _BottomInfo(
                label: 'Total',
                value: _formatDuration(workingMinutes),
              ),

              const SizedBox(width: 28),

              _BottomInfo(label: 'Status', value: _statusLabel(status)),

              const Spacer(),

              _BottomInfo(
                label: 'Prod.',
                value: productivity != null ? '$productivity%' : '--',
                alignEnd: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _timeRange(String? entry, String? exit) {
    if (entry == null || entry.isEmpty) {
      return '--';
    }

    final start = _formatTime(entry);

    if (exit == null || exit.isEmpty) {
      return '$start — --';
    }

    return '$start — ${_formatTime(exit)}';
  }

  String _formatTime(String value) {
    try {
      final parts = value.split(':');

      if (parts.length < 2) {
        return value;
      }

      var hour = int.parse(parts[0]);

      final minute = int.parse(parts[1]);

      final period = hour >= 12 ? 'PM' : 'AM';

      hour %= 12;

      if (hour == 0) {
        hour = 12;
      }

      return '$hour:${minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return value;
    }
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) {
      return '0m';
    }

    final hours = minutes ~/ 60;

    final mins = minutes % 60;

    if (hours == 0) {
      return '${mins}m';
    }

    if (mins == 0) {
      return '${hours}h';
    }

    return '${hours}h ${mins}m';
  }

  String _weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return names[weekday - 1];
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'late':
        return 'Late';

      case 'on_time':
      case 'on-time':
        return 'On Time';

      case 'early_exit':
      case 'early-exit':
        return 'Early Exit';

      case 'present':
        return 'Present';

      case 'absent':
        return 'Absent';

      default:
        return status.replaceAll('_', ' ');
    }
  }
}

class _DateBadge extends StatelessWidget {
  final DateTime? date;

  const _DateBadge({required this.date});

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return Container(
        width: 43,
        height: 49,
        decoration: BoxDecoration(
          color: const Color(0xFFFFE8EB),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Center(child: Text('--')),
      );
    }

    return Container(
      width: 43,
      height: 49,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8EB),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _monthShort(date!.month),
            style: GoogleFonts.inter(
              fontSize: 7,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFF3656),
            ),
          ),

          Text(
            date!.day.toString().padLeft(2, '0'),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFFF3656),
            ),
          ),
        ],
      ),
    );
  }

  String _monthShort(int month) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];

    return months[month - 1];
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();

    final isLate = normalized == 'late';

    final isAbsent = normalized == 'absent';

    final color = isLate
        ? const Color(0xFFFF3656)
        : isAbsent
        ? const Color(0xFFD32F2F)
        : const Color(0xFF00A77C);

    final background = isLate
        ? const Color(0xFFFFE5E9)
        : isAbsent
        ? const Color(0xFFFFEBEE)
        : const Color(0xFFE4F8F1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _BottomInfo extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _BottomInfo({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 8, color: const Color(0xFF8B7D83)),
        ),

        const SizedBox(height: 2),

        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.textColor,
          ),
        ),
      ],
    );
  }
}
