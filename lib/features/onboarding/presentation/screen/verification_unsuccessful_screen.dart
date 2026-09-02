import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';

class VerificationUnsuccessfulScreen extends StatefulWidget {
  const VerificationUnsuccessfulScreen({super.key});

  @override
  State<VerificationUnsuccessfulScreen> createState() =>
      _VerificationUnsuccessfulScreenState();
}

class _VerificationUnsuccessfulScreenState
    extends State<VerificationUnsuccessfulScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 26),

              // ERROR ICON
              _buildErrorIcon(),

              const SizedBox(height: 28),

              // TITLE
              Text(
                'Verification unsuccessful',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),

              const SizedBox(height: 8),

              // DESCRIPTION
              Text(
                'We couldn\'t verify your identity from this photo. Please ensure the following before trying again:',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  height: 1.45,
                  color: AppColors.mutedColor,
                ),
              ),

              const SizedBox(height: 16),

              // REASONS
              _buildReasonCard(
                icon: Icons.lightbulb_outline,
                title: 'Poor lighting',
                description:
                    'Ensure your face is evenly lit, avoiding\n'
                    'strong shadows or backlighting.',
              ),

              const SizedBox(height: 8),

              _buildReasonCard(
                icon: Icons.face_outlined,
                title: 'Face not clearly visible',
                description:
                    'Remove sunglasses, hats, or masks.\n'
                    'Ensure your full face is in the frame.',
              ),

              const SizedBox(height: 8),

              _buildReasonCard(
                icon: Icons.image_not_supported_outlined,
                title: 'Photo mismatch',
                description:
                    'The submitted photo does not match\n'
                    'the reference ID on file.',
              ),

              const SizedBox(height: 16),

              // TRY AGAIN
              WorkforcePrimaryButton(
                title: 'Try Again',
                onPressed: () {
                  Navigator.pop(context);
                },
              ),

              const SizedBox(height: 12),

              // CONTACT SUPPORT
              _buildSupportButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorIcon() {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFFDAD6),
      ),
      child: const Icon(
        Icons.warning_amber_rounded,
        size: 32,
        color: Color(0xFF93000A),
      ),
    );
  }

  Widget _buildReasonCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.mutedColor),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.mutedColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          // TODO: Open support
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryFillColor,
          side: const BorderSide(color: AppColors.borderColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Contact Support',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryFillColor,
          ),
        ),
      ),
    );
  }
}
