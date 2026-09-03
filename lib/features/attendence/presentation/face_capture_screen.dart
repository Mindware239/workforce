import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:workforce/app/routes/app_routes.dart';

import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';
import 'package:workforce/features/onboarding/presentation/widget/workforce_brand.dart';

class FaceCaptureScreen extends ConsumerStatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  ConsumerState<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends ConsumerState<FaceCaptureScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;

  Future<void> _takePhoto() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Check location service
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      debugPrint('Location service enabled: $serviceEnabled');

      if (!serviceEnabled) {
        _showMessage('Please turn on location services and try again.');
        return;
      }

      // 2. Check location permission
      LocationPermission permission = await Geolocator.checkPermission();

      debugPrint('Location permission: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        debugPrint('Location permission after request: $permission');
      }

      if (permission == LocationPermission.denied) {
        _showMessage('Location permission is required for attendance.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          'Location permission is permanently denied. '
          'Please enable it from Settings.',
        );
        return;
      }

      // 3. Get location
      debugPrint('Getting current location...');

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      debugPrint('Latitude: ${position.latitude}');
      debugPrint('Longitude: ${position.longitude}');
      debugPrint('Accuracy: ${position.accuracy}');

      // 4. Capture photo
      debugPrint('Opening camera...');

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90,
      );

      debugPrint('Photo: ${photo?.path}');

      if (!mounted || photo == null) {
        return;
      }

      // 5. Open preview
      context.push(
        AppRoutes.photoPreview,
        extra: {
          'imagePath': photo.path,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
        },
      );
    } catch (e, stackTrace) {
      debugPrint('================================');
      debugPrint('ATTENDANCE CAPTURE ERROR');
      debugPrint('ERROR: $e');
      debugPrint('STACK TRACE: $stackTrace');
      debugPrint('================================');

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

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

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
                title: _isLoading ? 'Please wait...' : 'Take Photo',
                onPressed: () {
                  if (!_isLoading) {
                    _takePhoto();
                  }
                },
              ),

              const SizedBox(height: 12),

              _buildCancelButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraFrame() {
    return SizedBox(
      width: double.infinity,
      height: 310,
      child: Center(child: Image.asset('assets/images/face_capture.png')),
    );
  }

  Widget _buildLocationChip() {
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
              'HQ – Factory Floor',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryFillColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            text: 'Position your face inside the frame',
          ),
          const SizedBox(height: 8),
          _InstructionRow(
            icon: Icons.light_mode_outlined,
            text: 'Make sure your face is clearly visible',
          ),
          const SizedBox(height: 8),
          _InstructionRow(
            icon: Icons.no_photography_outlined,
            text: 'Remove helmet or face covering if required',
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          context.pop();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryFillColor,
          side: const BorderSide(color: AppColors.borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Cancel',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

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
