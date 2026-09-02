import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';

class CompleteShiftScreen extends StatefulWidget {
  const CompleteShiftScreen({
    super.key,
  });

  @override
  State<CompleteShiftScreen> createState() => _CompleteShiftScreenState();
}

class _CompleteShiftScreenState extends State<CompleteShiftScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
       appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.whiteBackgroundColor,
        surfaceTintColor: AppColors.whiteBackgroundColor,
        title: Text(
          'Complete your shift',
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
              // _buildHeader(),

              // const SizedBox(height: 16),

              Text(
                'Take a photo to confirm your check-out.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.mutedColor,
                ),
              ),

              const SizedBox(height: 16),

              _buildShiftInfo(),

              const SizedBox(height: 16),

              _buildCameraPreview(),

              const SizedBox(height: 24),

              WorkforcePrimaryButton(
                title: 'Take Photo',
                icon: Icons.camera_alt_outlined,
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

 
 
  Widget _buildShiftInfo() {
    return Row(
      children: [
        Expanded(
          child: _InfoChip(
            icon: Icons.access_time_rounded,
            text: '05:00 PM',
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: _InfoChip(
            icon: Icons.location_on_outlined,
            text: 'HQ – Factory Floor',
          ),
        ),
      ],
    );
  }

  
  Widget _buildCameraPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: double.infinity,
        height: 400,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Replace this with your actual camera preview.
            Image.asset(
              'assets/images/face_capture.png',
              fit: BoxFit.cover,
            ),

            // Dark overlay
            Container(
              color: Colors.black.withValues(alpha: .08),
            ),

            // Face frame
            Center(
              child: Container(
                width: 145,
                height: 205,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .85),
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(70),
                ),
              ),
            ),

            // Bottom instruction
            Positioned(
              bottom: 8,
              left: 64,
              right: 64,
              child: Container(
                height: 32,
                width: 145,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(100)),
                  color: Colors.black.withValues(alpha: .25),
                ),
                child: Text(
                  'Align face within frame',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
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
          side: const BorderSide(
            color: AppColors.borderColor,
            width: 1,
          ),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Cancel',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryFillColor,
          ),
        ),
      ),
    );
  }

 
  Future<void> _takePhoto() async {
    // Connect your checkout camera flow here.
  }
}


class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // height: 27,
      padding: const EdgeInsets.all(
        16
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.mutedColor,
          ),

          const SizedBox(width: 6),

          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textColor,
              ),
            ),
          ),

          
        ],
      ),
    );
  }
}