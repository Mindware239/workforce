import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/onboarding/presentation/screen/face_capture_screen.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';
import 'package:workforce/features/onboarding/presentation/widget/workforce_brand.dart';

import 'reset_password_screen.dart';

class EmployeeLoginScreen extends StatefulWidget {
  const EmployeeLoginScreen({
    super.key,
  });

  @override
  State<EmployeeLoginScreen> createState() =>
      _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> {
  final TextEditingController employeeIdController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  bool obscurePassword = true;

  @override
  void dispose() {
    employeeIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(
           16
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
        
              WorkforceBrand(),
        
              const SizedBox(height: 48),
        
              Text(
                'Employee Login',
                style: GoogleFonts.inter(
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
        
              const SizedBox(height: 6),
        
              Text(
                'Enter your credentials to access your account.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.mutedColor,
                ),
              ),
        
              const SizedBox(height: 24),
        
              _buildFieldLabel('Employee ID'),
        
              const SizedBox(height: 6),
        
              _buildEmployeeIdField(),
        
              const SizedBox(height: 12),
        
              _buildFieldLabel('Password'),
        
              const SizedBox(height: 6),
        
              _buildPasswordField(),
        
              const SizedBox(height: 12),
        
              _buildForgotPassword(),
        
              const SizedBox(height: 16),
        
              WorkforcePrimaryButton(title: "Sign In", onPressed: () { Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FaceCaptureScreen(),
            ),
          ); },),
        
              const SizedBox(height: 24),
        
              _buildHelpText(),
            ],
          ),
        ),
      ),
    );
  }


 
  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textColor,
      ),
    );
  }

 
  Widget _buildEmployeeIdField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
      ),
      child: TextField(
        controller: employeeIdController,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textColor,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: const Icon(
            Icons.badge_outlined,
            size: 20,
            color: AppColors.mutedColor,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 35,
          ),
          hintText: 'e.g. EMP-10294',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.mutedColor,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
          ),
        ),
      ),
    );
  }

 
  Widget _buildPasswordField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor,
          width: .8,
        ),
      ),
      child: TextField(
        controller: passwordController,
        obscureText: obscurePassword,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textColor,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color: AppColors.mutedColor,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 35,
          ),
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                obscurePassword = !obscurePassword;
              });
            },
            padding: EdgeInsets.zero,
            icon: Icon(
              obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
              color: AppColors.mutedColor,
            ),
          ),
          hintText: '••••••••',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            letterSpacing: 1,
            color: AppColors.mutedColor,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
          ),
        ),
      ),
    );
  }

 
  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ResetPasswordScreen(),
            ),
          );
        },
        child: Text(
          'Forgot Password?',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryFillColor,
          ),
        ),
      ),
    );
  }

  
  Widget _buildHelpText() {
    return Center(
      child: Column(
        children: [
          Text(
            'Need help signing in?',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.mutedColor,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Contact your administrator.',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryFillColor,
            ),
          ),
        ],
      ),
    );
  }
}