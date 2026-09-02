import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';

class ActiveWorkSessionScreen extends StatefulWidget {
  const ActiveWorkSessionScreen({super.key});

  @override
  State<ActiveWorkSessionScreen> createState() =>
      _ActiveWorkSessionScreenState();
}

class _ActiveWorkSessionScreenState extends State<ActiveWorkSessionScreen> {
  Duration elapsed = const Duration(hours: 3, minutes: 2, seconds: 42);

  bool isWorking = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.whiteBackgroundColor,
        surfaceTintColor: AppColors.whiteBackgroundColor,
        title: Text(
          'Active Work Session',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryFillColor,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    _buildSessionCard(),

                    const SizedBox(height: 16),

                    _buildStats(),

                    const SizedBox(height: 16),

                    _buildDeviceStatus(),

                    const SizedBox(height: 24),

                    _buildBreakButton(),

                    const SizedBox(height: 12),

                    WorkforcePrimaryButton(
                      title: "End Shift",
                      icon: Icons.logout_rounded,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard() {
    return Container(
      width: double.infinity,
      height: 166,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        children: [
          // WORKING CHIP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE5F1E6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Working',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),

          Spacer(),

          Text(
            _formatDuration(elapsed),
            style: GoogleFonts.inter(
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.login_rounded,
                size: 16,
                color: AppColors.mutedColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Checked in at 08:55 AM',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.mutedColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.access_time_outlined,
            title: 'Shift',
            child: Text(
              '09:00 AM\n05:00 PM',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: AppColors.textColor,
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: _StatCard(
            icon: Icons.trending_up_rounded,
            title: 'Productivity',
            child: Text(
              '94%',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryFillColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceStatus() {
    return Container(
      height: 54,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.devices_outlined,
            size: 16,
            color: AppColors.mutedColor,
          ),

          const SizedBox(width: 7),

          Text(
            'Device Status',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedColor,
            ),
          ),

          const Spacer(),

          Container(
            width: 6,
            height: 65,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryFillColor,
            ),
          ),

          const SizedBox(width: 4),

          Text(
            'Connected',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryFillColor,
          side: const BorderSide(color: AppColors.borderColor, width: 1),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.coffee_outlined, size: 16),
            const SizedBox(width: 8),
            Text(
              'Start Break',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.mutedColor),
              const SizedBox(width: 5),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedColor,
                ),
              ),
            ],
          ),

          const Spacer(),

          child,
        ],
      ),
    );
  }
}
