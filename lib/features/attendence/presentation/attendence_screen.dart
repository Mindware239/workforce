import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/attendence/presentation/active_workSession.dart';
import 'package:workforce/features/attendence/presentation/attendence_record.dart';
import 'package:workforce/features/attendence/presentation/complete_shift.dart';
import 'package:workforce/features/attendence/presentation/employee_checkout.dart';

import '../providers/attendance_provider.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ref.read(attendanceProvider.notifier).getTodayAttendance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final attendanceState = ref.watch(attendanceProvider);

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(attendanceProvider.notifier).getTodayAttendance();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(attendanceState),

                const SizedBox(height: 14),

                if (attendanceState.isLoadingToday)
                  _buildLoading()
                else if (attendanceState.message != null &&
                    attendanceState.today == null)
                  _buildError(attendanceState.message!)
                else ...[
                  _buildAttendanceInfo(attendanceState),

                  const SizedBox(height: 16),

                  _buildStats(attendanceState),

                  const SizedBox(height: 16),

                  _buildActivityTimeline(attendanceState),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AttendanceState attendanceState) {
    final today = attendanceState.today;

    final status = today?['status']?.toString();

    final statusText = _getStatusText(status);
    final statusColor = _getStatusColor(status);
    final statusBackground = _getStatusBackground(status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            "Today's Attendance",
            style: GoogleFonts.inter(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
              height: 1.15,
            ),
          ),
        ),

        const SizedBox(width: 10),

        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: statusBackground,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                ),
                child: Icon(
                  status == null
                      ? Icons.remove
                      : status == 'late'
                      ? Icons.schedule
                      : Icons.check,
                  size: 8,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 4),

              Text(
                statusText,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceInfo(AttendanceState attendanceState) {
    final today = attendanceState.today;
    final schedule = attendanceState.schedule;

    final entryTime = today?['entryTime']?.toString();

    final standardEntry = schedule?['standardEntryTime']?.toString();

    final standardExit = schedule?['standardExitTime']?.toString();

    final hasAttendance = today != null;

    final shiftText = standardEntry != null && standardExit != null
        ? '${_formatTime(standardEntry)} – ${_formatTime(standardExit)}'
        : '--';

    return GestureDetector(
      onTap: hasAttendance
          ? () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AttendanceRecordedScreen(),
                ),
              );
            }
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor, width: 1),
        ),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.login_rounded,
              label: 'Check-in',
              value: hasAttendance && entryTime != null
                  ? _formatTime(entryTime)
                  : 'Not checked in',
            ),

            const SizedBox(height: 16),

            _InfoRow(
              icon: Icons.access_time_rounded,
              label: 'Shift',
              value: shiftText,
            ),

            if (today?['exitTime'] != null) ...[
              const SizedBox(height: 16),

              _InfoRow(
                icon: Icons.logout_rounded,
                label: 'Check-out',
                value: _formatTime(today!['exitTime'].toString()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStats(AttendanceState attendanceState) {
    final today = attendanceState.today;
    final schedule = attendanceState.schedule;

    final workingMinutes = today?['totalWorkingMinutes'] is num
        ? (today!['totalWorkingMinutes'] as num).toInt()
        : 0;

    final breakMinutes = attendanceState.breakMinutes;

    final standardWorkingMinutes =
        schedule?['standardWorkingHoursMinutes'] is num
        ? (schedule!['standardWorkingHoursMinutes'] as num).toInt()
        : 0;

    final remainingMinutes = (standardWorkingMinutes - workingMinutes)
        .clamp(0, double.infinity)
        .toInt();

    final hasAttendance = today != null;

    return Column(
      children: [
        GestureDetector(
          // onTap: hasAttendance
          //     ? () {
          //         Navigator.of(context).push(
          //           MaterialPageRoute(
          //             builder: (context) => const ActiveWorkSessionScreen(),
          //           ),
          //         );
          //       }
          //     : null,
          child: _StatCard(
            title: 'Hours Worked',
            value: hasAttendance ? _formatDuration(workingMinutes) : '--',
            valueColor: AppColors.primaryFillColor,
          ),
        ),

        const SizedBox(height: 12),

        GestureDetector(
          // onTap: hasAttendance
          //     ? () {
          //         Navigator.of(context).push(
          //           MaterialPageRoute(
          //             builder: (context) => const CompleteShiftScreen(),
          //           ),
          //         );
          //       }
          //     : null,
          child: _StatCard(
            title: 'Break Duration',
            value: hasAttendance ? _formatDuration(breakMinutes) : '--',
            valueColor: const Color(0xFF5D606A),
          ),
        ),

        const SizedBox(height: 12),

        GestureDetector(
          // onTap: hasAttendance
          //     ? () {
          //         Navigator.of(context).push(
          //           MaterialPageRoute(
          //             builder: (context) =>
          //                 const ConfirmCheckoutPhotoScreen(imagePath: ''),
          //           ),
          //         );
          //       }
          //     : null,
          child: _StatCard(
            title: 'Remaining',
            value: hasAttendance ? _formatDuration(remainingMinutes) : '--',
            valueColor: AppColors.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTimeline(AttendanceState attendanceState) {
    final timeline = attendanceState.timeline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Timeline',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textColor,
            ),
          ),

          const SizedBox(height: 12),

          if (timeline.isEmpty)
            _buildEmptyTimeline()
          else
            ...List.generate(timeline.length, (index) {
              final item = timeline[index];

              final time = item['time']?.toString() ?? '--';

              final label = item['label']?.toString() ?? '--';

              final tone = item['tone']?.toString();

              return _TimelineItem(
                time: _formatTime(time),
                title: label,
                color: _timelineColor(tone),
                isFirst: index == 0,
                isLast: index == timeline.length - 1,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 130,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),

        const SizedBox(height: 16),

        Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
          ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: Colors.redAccent,
          ),

          const SizedBox(height: 10),

          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textColor),
          ),

          const SizedBox(height: 14),

          ElevatedButton(
            onPressed: () {
              ref.read(attendanceProvider.notifier).getTodayAttendance();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTimeline() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          'No attendance activity yet',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedColor),
        ),
      ),
    );
  }

  String _getStatusText(String? status) {
    if (status == null || status.isEmpty) {
      return 'Not Started';
    }

    switch (status.toLowerCase()) {
      case 'late':
        return 'Late';

      case 'on_time':
      case 'on-time':
      case 'ontime':
        return 'On Time';

      case 'present':
        return 'Present';

      case 'absent':
        return 'Absent';

      default:
        return _capitalizeStatus(status);
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'late':
        return const Color(0xFFF2A900);

      case 'absent':
        return const Color(0xFFD32F2F);

      case 'on_time':
      case 'on-time':
      case 'ontime':
      case 'present':
        return const Color(0xFF2E7D32);

      default:
        return AppColors.mutedColor;
    }
  }

  Color _getStatusBackground(String? status) {
    switch (status?.toLowerCase()) {
      case 'late':
        return const Color(0xFFFFF4D6);

      case 'absent':
        return const Color(0xFFFFEBEE);

      case 'on_time':
      case 'on-time':
      case 'ontime':
      case 'present':
        return const Color(0xFFE8F5E9);

      default:
        return const Color(0xFFF1F1F3);
    }
  }

  String _capitalizeStatus(String value) {
    return value
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  Color _timelineColor(String? tone) {
    switch (tone?.toLowerCase()) {
      case 'primary':
        return AppColors.primaryFillColor;

      case 'warning':
        return const Color(0xFFF2A900);

      case 'muted':
        return const Color(0xFF85858D);

      default:
        return AppColors.primaryFillColor;
    }
  }

  String _formatTime(String? value) {
    if (value == null || value.isEmpty) {
      return '--';
    }

    try {
      final parts = value.split(':');

      if (parts.length < 2) {
        return value;
      }

      int hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final period = hour >= 12 ? 'PM' : 'AM';

      hour = hour % 12;

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
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '${remainingMinutes}m';
    }

    if (remainingMinutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remainingMinutes}m';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFF1EEFA),
          ),
          child: Icon(icon, size: 18, color: AppColors.primaryFillColor),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: AppColors.mutedColor,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: AppColors.mutedColor,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String time;
  final String title;
  final Color color;
  final bool isFirst;
  final bool isLast;

  const _TimelineItem({
    required this.time,
    required this.title,
    required this.color,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 14,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!isLast)
                  Positioned(
                    top: 10,
                    bottom: 0,
                    child: Container(width: 1, color: const Color(0xFFD8D8DD)),
                  ),

                Positioned(
                  top: 4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: color == AppColors.primaryFillColor
                        ? AppColors.primaryFillColor
                        : AppColors.mutedColor,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textColor,
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
