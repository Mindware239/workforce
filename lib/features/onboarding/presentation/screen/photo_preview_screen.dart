import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';

import 'identity_verification_screen.dart';

class PhotoPreviewScreen extends StatelessWidget {
  final String imagePath;

  const PhotoPreviewScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // const SizedBox(height: 48),

              _buildPhoto(),

              const SizedBox(height: 16),

              _buildPhotoInfo(),

              const SizedBox(height: 16),

              _buildSecurityMessage(),

              const SizedBox(height: 8),

              Divider(color: AppColors.borderColor, thickness: 1),

              const SizedBox(height: 8),

              _securityIdentityMessage(),

              const SizedBox(height: 16),

              WorkforcePrimaryButton(
                title: 'Use This Photo',
                icon: Icons.check_circle_outline,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const IdentityVerificationScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              _buildRetakeButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoto() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(imagePath),
        width: double.infinity,
        height: 464,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildPhotoInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.primaryFillColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Site Alpha · Entrance Gate B',
                  style: GoogleFonts.inter(color: AppColors.textColor),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(
                Icons.access_time_outlined,
                size: 16,
                color: AppColors.mutedColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Oct 24, 2023 · 08:42 AM',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.mutedColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityMessage() {
    return SizedBox(
      width: double.infinity,

      child: Column(
        children: [
          SvgPicture.asset('assets/icons/face.svg', width: 16, height: 16),
          const SizedBox(height: 8),
          Text(
            'Make sure your face is clearly visible, well-lit, and not obstructed before continuing.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedColor),
          ),
        ],
      ),
    );
  }

  Widget _securityIdentityMessage() {
    return SizedBox(
      width: double.infinity,

      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset('assets/icons/lock.svg', width: 12, height: 12),
          const SizedBox(width: 8),
          Text(
            'Secure Identity Verification',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedColor),
          ),
        ],
      ),
    );
  }

  Widget _buildRetakeButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.pop(context);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryFillColor,
          side: const BorderSide(color: AppColors.borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.refresh_rounded, size: 12),
        label: Text(
          'Retake Photo',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
