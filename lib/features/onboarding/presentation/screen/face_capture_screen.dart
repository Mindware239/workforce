import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';
import 'package:workforce/features/onboarding/presentation/widget/workforce_brand.dart';

import 'photo_preview_screen.dart';

class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90,
      );

      if (!mounted || photo == null) {
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoPreviewScreen(imagePath: photo.path),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to access the camera. Please try again.'),
        ),
      );
    }
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

              WorkforceBrand(),

              const SizedBox(height: 24),

              _buildCameraFrame(),

              const SizedBox(height: 32),

              _buildLocationChip(),

              const SizedBox(height: 32),

              _buildInstructions(),

              const SizedBox(height: 24),

              WorkforcePrimaryButton(
                icon: Icons.camera_alt,
                title: "Take Photo",
                onPressed: _takePhoto,
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
          Navigator.pop(context);
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
