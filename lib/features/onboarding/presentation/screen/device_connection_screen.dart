import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';

class DeviceConnectionScreen extends StatelessWidget {
  const DeviceConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.whiteBackgroundColor,
        surfaceTintColor: AppColors.whiteBackgroundColor,
        title: Text(
          'Device Connection',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryFillColor,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 16),

              _buildDeviceIcon(),

              const SizedBox(height: 12),

              Text(
                'Connect your work device',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Your device has been successfully authenticated on the secure enterprise network.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.mutedColor,
                ),
              ),

              const SizedBox(height: 16),

              _buildDeviceDetails(),

              const SizedBox(height: 24),

              WorkforcePrimaryButton(title: 'Continue', onPressed: () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceIcon() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,

        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.devices_outlined,
            size: 36,
            color: AppColors.primaryFillColor,
          ),
          Positioned(
            right: 11,
            bottom: 10,
            child: Container(
              width: 11,
              height: 11,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2E7D32),
              ),
              child: const Icon(Icons.check, size: 7, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceDetails() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        children: [
          _DeviceRow(
            icon: Icons.dns_outlined,
            label: 'WORKSTATION',
            value: 'Connected',
          ),
          _DeviceRow(
            icon: Icons.tag_outlined,
            label: 'DEVICE ID',
            value: 'WS-8829',
          ),
          _DeviceRow(
            icon: Icons.access_time_outlined,
            label: 'CONNECTION TIME',
            value: '08:55 AM',
          ),
          _DeviceRow(
            icon: Icons.wifi_outlined,
            label: 'NETWORK STATUS',
            value: 'Enterprise_Secure',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _DeviceRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.borderColor, width: .7),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ICON
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(icon, size: 16, color: AppColors.mutedColor),
          ),

          const SizedBox(width: 12),

          // LABEL + VALUE
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,

                    color: AppColors.mutedColor,
                  ),
                ),

                // const SizedBox(height: 8),
                Row(
                  children: [
                    if (label == 'NETWORK STATUS')
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF2E7D32),
                        ),
                      ),

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
          ),
        ],
      ),
    );
  }
}
