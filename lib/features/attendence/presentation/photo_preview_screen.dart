import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/app/routes/app_routes.dart';

import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/attendence/providers/attendance_provider.dart';
import 'package:workforce/features/attendence/services/employee_location_service.dart';

import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';
import 'package:workforce/features/profile/providers/profile_provider.dart';

class PhotoPreviewScreen extends ConsumerStatefulWidget {
  final bool? isStart;
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
    this.isStart,
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

    try {
      debugPrint('========================================');
      debugPrint('📷 FACE ATTENDANCE');
      debugPrint('📷 Image: ${widget.imagePath}');
      debugPrint('📍 Latitude: ${widget.latitude}');
      debugPrint('📍 Longitude: ${widget.longitude}');
      debugPrint('📍 Accuracy: ${widget.accuracy}');
      debugPrint('========================================');

      final success = widget.isStart == true
          ? await ref
                .read(attendanceProvider.notifier)
                .checkIn(
                  attendanceType: 'face',
                  photoPath: widget.imagePath,
                  lat: widget.latitude,
                  lng: widget.longitude,
                  accuracy: widget.accuracy,
                )
          : await ref
                .read(attendanceProvider.notifier)
                .checkout(
                  attendanceType: 'face',
                  photoPath: widget.imagePath,
                  lat: widget.latitude,
                  lng: widget.longitude,
                  accuracy: widget.accuracy,
                );

      if (success) {
        if (widget.isStart == true) {
          // Check-in successful → start background location tracking
          await LocationTrackingService.start();

          print('🚀 Location tracking started after check-in');
        } else {
          // Checkout successful → stop background location tracking
          await LocationTrackingService.stop();

          print('🛑 Location tracking stopped after checkout');
        }
      }

      if (!mounted) return;

      final attendanceState = ref.read(attendanceProvider);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isStart == true
                  ? ref.tr('photoPreview.checkInSuccessful')
                  : ref.tr('photoPreview.checkOutSuccessful'),
            ),
          ),
        );

        context.go(AppRoutes.dashboard);

        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            attendanceState.message ?? ref.tr('photoPreview.unableCheckIn'),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ FACE ATTENDANCE ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
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
                title: _isSubmitting
                    ? ref.tr('photoPreview.checkingIn')
                    : ref.tr('photoPreview.useThisPhoto'),
                icon: Icons.check_circle_outline,
                onPressed: _isSubmitting
                    ? () {}
                    : () {
                        _usePhoto();
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

  String _getValue(dynamic value) {
    if (value == null) {
      return ref.tr('common.notAvailable');
    }

    if (value is String) {
      return value.isEmpty ? ref.tr('common.notAvailable') : value;
    }

    if (value is num || value is bool) {
      return value.toString();
    }

    if (value is Map) {
      final possibleKeys = [
        'name',
        'fullName',
        'title',
        'label',
        'value',
        'id',
      ];

      for (final key in possibleKeys) {
        final nestedValue = value[key];

        if (nestedValue != null && nestedValue.toString().isNotEmpty) {
          return nestedValue.toString();
        }
      }
    }

    return value.toString();
  }

  Widget _buildPhotoInfo() {
    final profileState = ref.watch(profileProvider);
    final profile = profileState.profile ?? {};

    final organizationName = _getValue(profile['organizationName']);
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
                  organizationName.isNotEmpty
                      ? organizationName
                      : ref.tr('photoPreview.locationLabel'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Row(
          //   children: [
          //     const Icon(
          //       Icons.location_on_outlined,
          //       size: 16,
          //       color: AppColors.mutedColor,
          //     ),
          //     const SizedBox(width: 8),
          //     Expanded(
          //       child: Text(
          //         organizationName.isNotEmpty
          //             ? organizationName
          //             : _locationText(),
          //         style: GoogleFonts.inter(
          //           fontSize: 12,
          //           height: 1.5,
          //           color: AppColors.mutedColor,
          //         ),
          //       ),
          //     ),
          //   ],
          // ),

          // const SizedBox(height: 8),

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
    final localization = ref.read(appLocalizationProvider);
    final lat = widget.latitude.toStringAsFixed(6);
    final lng = widget.longitude.toStringAsFixed(6);

    if (widget.accuracy != null) {
      return '$lat, $lng · ${localization.tr('photoPreview.accuracy')} '
          '${widget.accuracy!.toStringAsFixed(0)}m';
    }

    return '$lat, $lng';
  }

  String _currentDateTime() {
    final now = DateTime.now();

    final localization = ref.read(appLocalizationProvider);

    final months = [
      localization.tr('monthlySummary.january'),
      localization.tr('monthlySummary.february'),
      localization.tr('monthlySummary.march'),
      localization.tr('monthlySummary.april'),
      localization.tr('monthlySummary.may'),
      localization.tr('monthlySummary.june'),
      localization.tr('monthlySummary.july'),
      localization.tr('monthlySummary.august'),
      localization.tr('monthlySummary.september'),
      localization.tr('monthlySummary.october'),
      localization.tr('monthlySummary.november'),
      localization.tr('monthlySummary.december'),
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
            ref.tr('photoPreview.securityMessage'),
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
            ref.tr('photoPreview.secureAttendanceVerification'),
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
                context.pop();
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
          ref.tr('photoPreview.retakePhoto'),
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
