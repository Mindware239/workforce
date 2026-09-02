import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';

class AttendanceRecordedScreen extends StatelessWidget {
  const AttendanceRecordedScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 48),

              // SUCCESS ICON
              _buildSuccessIcon(),

              const SizedBox(height: 16),

              // TITLE
              Text(
                'Attendance recorded',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 30,
                  height: 1.1,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),

              const SizedBox(height: 5),

              // DESCRIPTION
              Text(
                'Your attendance has been successfully recorded.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  height: 1.35,
                  color: AppColors.mutedColor,
                ),
              ),

              const SizedBox(height: 16),

              // ATTENDANCE DETAILS
              _buildAttendanceDetails(),

              const SizedBox(height: 24),

              // DASHBOARD BUTTON
              WorkforcePrimaryButton(
                title: 'Go to Dashboard',
                onPressed: () {
                  Navigator.popUntil(
                    context,
                    (route) => route.isFirst,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIcon() {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFEAE6F4),
      ),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF2E7D32),
        ),
        child: const Icon(
          Icons.check,
          size: 24,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildAttendanceDetails() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _AttendanceRow(
            icon: Icons.access_time_outlined,
            label: 'Check-in Time',
            value: '08:55 AM',
          ),
          _AttendanceRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: 'Tuesday, October 24',
          ),
          _AttendanceRow(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: 'HQ – Factory Floor',
          ),
          _AttendanceRow(
            icon: Icons.work_outline,
            label: 'Shift',
            value: '9:00 AM – 5:00 PM',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _AttendanceRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.all(
        16
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(
                  color: AppColors.borderColor,
                  width: 1,
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.mutedColor,
          ),

          const SizedBox(width: 8),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedColor,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}