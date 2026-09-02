import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';
import 'package:workforce/features/onboarding/presentation/widget/workforce_brand.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController employeeIdController = TextEditingController();

  @override
  void dispose() {
    employeeIdController.dispose();
    super.dispose();
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
              const SizedBox(height: 48),

              WorkforceBrand(),

              const SizedBox(height: 48),

              

              Center(
                child: Column(
                  children: [
                    Text(
                      'Reset your password',
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'How will your employee ID and we\'ll send instructions to your registered contact.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.35,
                        color: AppColors.mutedColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Employee ID',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor,
                ),
              ),

              const SizedBox(height: 8),

              _buildEmployeeIdField(),

              const SizedBox(height: 24),

              WorkforcePrimaryButton( title: "Continue", onPressed: () {  },),

              const SizedBox(height: 8),

              _buildBackButton(),

              const SizedBox(height: 30),

              _buildHelpText(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeIdField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: TextField(
        controller: employeeIdController,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textColor),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: const Icon(
            Icons.badge_outlined,
            size: 20,
            color: AppColors.mutedColor,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 35),
          hintText: 'e.g. EMP-00000',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.mutedColor,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

 
 



  Widget _buildBackButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          Navigator.pop(context);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryFillColor,
          padding: EdgeInsets.zero,
          side: const BorderSide(color: AppColors.borderColor, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          '← Back to Login',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryFillColor,
          ),
        ),
      ),
    );
  }


  Widget _buildHelpText() {
    return Center(
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Need help? ',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            ),
            TextSpan(
              text: 'Contact IT Support',
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
}
