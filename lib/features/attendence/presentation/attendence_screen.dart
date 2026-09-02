import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/attendence/presentation/active_workSession.dart';
import 'package:workforce/features/attendence/presentation/attendence_record.dart';
import 'package:workforce/features/attendence/presentation/complete_shift.dart';
import 'package:workforce/features/attendence/presentation/employee_checkout.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
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

              const SizedBox(height: 14),

              _buildAttendanceInfo(),

              const SizedBox(height: 16),

              _buildStats(),

              const SizedBox(height: 16),

              _buildActivityTimeline(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2E7D32),
                ),
                child: const Icon(Icons.check, size: 8, color: Colors.white),
              ),
              const SizedBox(width: 4),
              Text(
                'On Time',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF237A35),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceInfo() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const AttendanceRecordedScreen(),
          ),
        );
      },
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
              value: '08:55 AM',
            ),

            const SizedBox(height: 16),

            _InfoRow(
              icon: Icons.access_time_rounded,
              label: 'Shift',
              value: '09:00 AM – 05:00 PM',
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  Widget _buildStats() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ActiveWorkSessionScreen(),
              ),
            );
          },
          child: _StatCard(
            title: 'Hours Worked',
            value: '5h 30m',
            valueColor: AppColors.primaryFillColor,
          ),
        ),

        const SizedBox(height: 12),

        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CompleteShiftScreen(),
              ),
            );
          },
          child: _StatCard(
            title: 'Break Duration',
            value: '30m',
            valueColor: const Color(0xFF5D606A),
          ),
        ),

        const SizedBox(height: 12),

         GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ConfirmCheckoutPhotoScreen(imagePath: '',),
              ),
            );
          },
          child: _StatCard(
            title: 'Remaining',
            value: '2h 30m',
            valueColor: AppColors.textColor,
          ),
        ),
      ],
    );
  }

  // ============================================================
  Widget _buildActivityTimeline() {
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

          _TimelineItem(
            time: '08:55 AM',
            title: 'Check-in',
            color: AppColors.primaryFillColor,
            isFirst: true,
          ),

          _TimelineItem(
            time: '09:00 AM',
            title: 'Work Session started',
            color: const Color(0xFF85858D),
          ),

          _TimelineItem(
            time: '12:30 PM',
            title: 'Break started',
            color: const Color(0xFFF2A900),
          ),

          _TimelineItem(
            time: '01:00 PM',
            title: 'Work Session resumed',
            color: const Color(0xFF85858D),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

// ================================================================
// INFO ROW
// ================================================================

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

        Column(
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
      ],
    );
  }
}

// ================================================================
// STAT CARD
// ================================================================

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

// ================================================================
// TIMELINE ITEM
// ================================================================

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
