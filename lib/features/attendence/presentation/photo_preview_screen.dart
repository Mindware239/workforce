import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/app/routes/app_routes.dart';

import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/attendence/providers/attendance_provider.dart';

import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';

class PhotoPreviewScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final double latitude;
  final double longitude;
  final double? accuracy;

  const PhotoPreviewScreen({
    super.key,
    required this.imagePath,
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  @override
  ConsumerState<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends ConsumerState<PhotoPreviewScreen> {
  bool _isSubmitting = false;

  Future<void> _usePhoto() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final success = await ref
        .read(attendanceProvider.notifier)
        .checkIn(
          photoPath: widget.imagePath,
          lat: widget.latitude,
          lng: widget.longitude,
          accuracy: widget.accuracy,
        );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    final attendanceState = ref.read(attendanceProvider);

    if (success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Check-in successful')));

      // Return to the previous screen after successful check-in.
      Navigator.pop(context, true);
    } else {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(
      //       attendanceState.message ??
      //           'Unable to check in. Please try again.',
      //     ),
      //   ),
      // );
      context.push(AppRoutes.verificationUnsuccessful);
    }
  }

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
                title: _isSubmitting ? 'Checking In...' : 'Use This Photo',
                icon: Icons.check_circle_outline,
                onPressed: () {
                  if (!_isSubmitting) _usePhoto();
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
        File(widget.imagePath),
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
                  'HQ – Factory Floor',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(
                Icons.location_searching_outlined,
                size: 16,
                color: AppColors.mutedColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _locationText(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.mutedColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

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
                  _currentDateTime(),
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

  String _locationText() {
    final lat = widget.latitude.toStringAsFixed(6);
    final lng = widget.longitude.toStringAsFixed(6);

    if (widget.accuracy != null) {
      return '$lat, $lng · Accuracy ${widget.accuracy!.toStringAsFixed(0)}m';
    }

    return '$lat, $lng';
  }

  String _currentDateTime() {
    final now = DateTime.now();

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

    final hour = now.hour > 12
        ? now.hour - 12
        : now.hour == 0
        ? 12
        : now.hour;

    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';

    return '${months[now.month - 1]} ${now.day}, '
        '${now.year} · $hour:$minute $period';
  }

  Widget _buildSecurityMessage() {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          SvgPicture.asset('assets/icons/face.svg', width: 16, height: 16),
          const SizedBox(height: 8),
          Text(
            'Make sure your face is clearly visible, well-lit, '
            'and not obstructed before continuing.',
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
            'Secure Attendance Verification',
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
        onPressed: _isSubmitting
            ? null
            : () {
                Navigator.pop(context);
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryFillColor,
          side: const BorderSide(color: AppColors.borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: Text(
          'Retake Photo',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
