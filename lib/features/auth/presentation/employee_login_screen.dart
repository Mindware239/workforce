import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/app/routes/app_routes.dart';

import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/auth/providers/auth_provider.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';
import 'package:workforce/features/onboarding/presentation/widget/workforce_brand.dart';

class EmployeeLoginScreen extends ConsumerStatefulWidget {
  const EmployeeLoginScreen({super.key});

  @override
  ConsumerState<EmployeeLoginScreen> createState() =>
      _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends ConsumerState<EmployeeLoginScreen> {
  final TextEditingController mobileController = TextEditingController();

  @override
  void dispose() {
    mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.success) {
        context.go(AppRoutes.dashboard);
      }

      if (next.status == AuthStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? 'Login failed.')),
        );
      }
    });

    final authState = ref.watch(authProvider);

    final isLoading = authState.status == AuthStatus.loading;

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
                'Enter your mobile number to access your account.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.mutedColor,
                ),
              ),

              const SizedBox(height: 32),

              _buildFieldLabel('Employee ID'),

              const SizedBox(height: 12),

              _buildMobileField(),

              const SizedBox(height: 32),

              WorkforcePrimaryButton(
                title: isLoading ? 'Signing In...' : 'Sign In',
                onPressed: isLoading ? () {} : _login,
              ),

              const SizedBox(height: 24),

              _buildHelpText(),
            ],
          ),
        ),
      ),
    );
  }

  void _login() {
    final mobileNumber = mobileController.text.trim();

    if (mobileNumber.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number.'),
        ),
      );

      return;
    }

    ref.read(authProvider.notifier).login(mobileNumber: mobileNumber);
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

  Widget _buildMobileField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: TextField(
        controller: mobileController,
        keyboardType: TextInputType.phone,
        maxLength: 10,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textColor),
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,

          prefixIcon: const Icon(
            Icons.badge_outlined,
            size: 20,
            color: AppColors.mutedColor,
          ),

          prefixIconConstraints: const BoxConstraints(minWidth: 35),

          hintText: 'e.g. EMP-10294',

          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.mutedColor,
          ),

          contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
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
