import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';

import 'device_connection_screen.dart';

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({
    super.key,
  });

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  bool photoCaptured = true;
  bool faceDetected = true;
  bool identityVerified = false;

  @override
  void initState() {
    super.initState();

    _startVerification();
  }

  Future<void> _startVerification() async {
    await Future.delayed(
      const Duration(milliseconds: 700),
    );

    if (!mounted) return;

    setState(() {
      identityVerified = true;
    });
  }

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

              Text(
                'Verifying your identity',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 30,
                  
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Checking your identity...',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.mutedColor,
                ),
              ),

              const SizedBox(height: 16),

              _buildVerificationCircle(),

              const SizedBox(height: 16),

              _buildSteps(),

              const SizedBox(height: 24),

              _buildSecurityNote(),

              if (identityVerified) ...[
                const SizedBox(height: 24),
                WorkforcePrimaryButton(
                  title: 'Continue',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DeviceConnectionScreen(),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationCircle() {
    return Container(
      width: 192,
      height: 192,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
     
        border: Border.all(
          color: AppColors.borderColor,
          width: 2,
        ),
      ),
      child: Center(
        child: const Icon(
          Icons.face_outlined,
          size: 66,
          // color: Color(0xFFB69DAA),
        ),
      ),
    );
  }

  Widget _buildSteps() {
    return Column(
      children: [
        _VerificationStep(
          title: 'Photo captured',
          completed: photoCaptured,
        ),
        _VerificationStep(
          title: 'Face detected',
          completed: faceDetected,
        ),
        _VerificationStep(
          title: 'Identity verified',
          completed: identityVerified,
        ),
      ],
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline,
            size: 16,
            color: AppColors.mutedColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'This may take a few seconds. Ensure your network connection is stable.',
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color: AppColors.mutedColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

 

}

class _VerificationStep extends StatelessWidget {
  final String title;
  final bool completed;

  const _VerificationStep({
    required this.title,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completed
                  ? AppColors.primaryFillColor
                  : Colors.transparent,
              border: Border.all(
                color: AppColors.primaryFillColor,
                width: 1,
              ),
            ),
            child: completed
                ? const Icon(
                    Icons.check,
                    size: 16,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: completed
                  ? AppColors.textColor
                  : AppColors.mutedColor,
            ),
          ),
        ],
      ),
    );
  }
}