import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/location/precise_location.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/features/attendence/presentation/blink_capture_screen.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';
import 'package:workforce/features/onboarding/presentation/widget/workforce_brand.dart';
import 'package:workforce/features/profile/providers/profile_provider.dart';

class FaceCaptureScreen extends ConsumerStatefulWidget {
  final bool? isStart;
  final double? latitude;
  final double? longitude;
  final double? accuracy;

  const FaceCaptureScreen({
    super.key,
    this.isStart,
    this.latitude,
    this.longitude,
    this.accuracy,
  });

  @override
  ConsumerState<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends ConsumerState<FaceCaptureScreen> {
  bool _isLoading = false;

  // ============================================================
  // RESOLVE GPS POSITION
  // ============================================================

  Future<Position> _resolvePosition() async {
    if (widget.latitude != null &&
        widget.longitude != null &&
        widget.latitude != 0.0 &&
        widget.longitude != 0.0) {
      return Position(
        latitude: widget.latitude!,
        longitude: widget.longitude!,
        timestamp: DateTime.now(),
        accuracy: widget.accuracy ?? 15.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage(ref.tr('faceCapture.locationServicesRequired'));
      throw Exception('Location service disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showMessage(ref.tr('faceCapture.locationPermissionRequired'));
      throw Exception('Location permission denied');
    }

    return await getPrecisePosition();
  }

  // ============================================================
  // TAKE ATTENDANCE (FACE CAPTURE)
  // ============================================================

  Future<void> _takePhoto() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final position = await _resolvePosition();
      await _openBlinkCamera(position: position);
    } catch (e, stackTrace) {
      debugPrint('❌ FACE CAPTURE ERROR: $e\n$stackTrace');
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  

  // ============================================================
  // OPEN BLINK CAMERA
  // ============================================================

  Future<void> _openBlinkCamera({required Position position}) async {
    debugPrint('========================================');

    debugPrint('📷 FACE ATTENDANCE');

    debugPrint('📷 Opening blink camera...');

    debugPrint('📍 Latitude: ${position.latitude}');

    debugPrint('📍 Longitude: ${position.longitude}');

    debugPrint('📍 Accuracy: ${position.accuracy}');

    debugPrint('========================================');

    final String? imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BlinkCameraScreen()),
    );

    if (!mounted) return;

    // ==========================================================
    // USER CANCELLED CAMERA
    // ==========================================================

    if (imagePath == null || imagePath.isEmpty) {
      debugPrint('📷 Blink camera cancelled.');
      return;
    }

    debugPrint('📷 Automatically captured photo:');

    debugPrint('📷 $imagePath');

    // ==========================================================
    // OPEN PHOTO PREVIEW
    // ==========================================================

    context.push(
      AppRoutes.photoPreview,
      extra: {
        'imagePath': imagePath,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'attendance_type': 'face',
        'isStart': widget.isStart,
      },
    );
  }

  // ============================================================
  // FINGERPRINT ATTENDANCE
  // ============================================================

 
  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

 
  // ============================================================
  // SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              const WorkforceBrand(),

              const SizedBox(height: 24),

              _buildCameraFrame(),

              const SizedBox(height: 32),

              _buildLocationChip(),

              const SizedBox(height: 32),

              _buildInstructions(),

              const SizedBox(height: 24),

              WorkforcePrimaryButton(
                icon: Icons.camera_alt,
                title: _isLoading
                    ? ref.tr('faceCapture.pleaseWait')
                    : ref.tr('faceCapture.takePhoto'),
                onPressed: () {
                  if (!_isLoading) {
                    _takePhoto();
                  }
                },
              ),

              const SizedBox(height: 12),

              // SizedBox(
              //   width: double.infinity,
              //   height: 48,
              //   child: OutlinedButton.icon(
              //     icon: const Icon(
              //       Icons.fingerprint,
              //       color: AppColors.primaryFillColor,
              //       size: 22,
              //     ),
              //     label: Text(
              //       ref.tr('faceCapture.fingerprint'),
              //       style: GoogleFonts.inter(
              //         fontSize: 14,
              //         fontWeight: FontWeight.w600,
              //         color: AppColors.primaryFillColor,
              //       ),
              //     ),
              //     style: OutlinedButton.styleFrom(
              //       side: const BorderSide(
              //         color: AppColors.primaryFillColor,
              //         width: 1.5,
              //       ),
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(12),
              //       ),
              //     ),
              //     onPressed: _isLoading ? null : _authenticateWithFingerprintDirectly,
              //   ),
              // ),

              // const SizedBox(height: 12),

              _buildCancelButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CAMERA FRAME / PREVIEW IMAGE
  // ============================================================

  Widget _buildCameraFrame() {
    return SizedBox(
      width: double.infinity,
      height: 310,
      child: Center(child: Image.asset('assets/images/face_capture.jpg')),
    );
  }

  // ============================================================
  // LOCATION CHIP
  // ============================================================
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

  Widget _buildLocationChip() {
    final profileState = ref.watch(profileProvider);
    final profile = profileState.profile ?? {};

    final organizationName = _getValue(profile['organizationName']);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(500),
          border: Border.all(color: AppColors.borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 16,
              color: AppColors.primaryFillColor,
            ),

            const SizedBox(width: 4),

            Text(
              organizationName.isNotEmpty
                  ? organizationName
                  : ref.tr('faceCapture.locationLabel'),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.saffronText,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ============================================================
  // INSTRUCTIONS
  // ============================================================

  Widget _buildInstructions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: .1),
      ),
      child: Column(
        children: [
          _InstructionRow(
            icon: Icons.face_outlined,
            text: ref.tr('faceCapture.positionFace'),
          ),

          const SizedBox(height: 8),

          _InstructionRow(
            icon: Icons.light_mode_outlined,
            text: ref.tr('faceCapture.faceClearlyVisible'),
          ),

          const SizedBox(height: 8),

          _InstructionRow(
            icon: Icons.no_photography_outlined,
            text: ref.tr('faceCapture.removeFaceCovering'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CANCEL
  // ============================================================

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          context.pop();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.saffronText,
          side: const BorderSide(color: AppColors.borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          ref.tr('faceCapture.cancel'),
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

// ================================================================
// INSTRUCTION ROW
// ================================================================

class _InstructionRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InstructionRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryFillColor),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 16, color: AppColors.mutedColor),
          ),
        ),
      ],
    );
  }
}
