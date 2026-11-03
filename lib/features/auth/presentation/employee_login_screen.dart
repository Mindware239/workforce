import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/attendence/services/employee_location_service.dart';
import 'package:workforce/features/auth/providers/auth_provider.dart';
import 'package:workforce/features/mdm/services/mdm_service.dart';
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
    ref.listen<AuthState>(authProvider, (previous, next) async {
      // Login / onboarding request completed successfully.
      if (previous?.isLoading == true && !next.isLoading) {
        if (next.error == null && next.isAuthenticated) {
          // Start background location tracking now that authentication is complete
          try {
            await LocationTrackingService.start();
          } catch (e) {
            debugPrint('Error starting LocationTrackingService: $e');
          }

          // Enroll this device for management and run any pending admin
          // commands. Non-blocking: failures must not hold up the login flow.
          unawaited(() async {
            try {
              final mdm = MdmService();
              await mdm.enroll();
              await mdm.syncCommands();
            } catch (e) {
              debugPrint('Error during MDM enroll/sync: $e');
            }
          }());

          if (next.onboardingPending) {
            context.go(AppRoutes.completeProfile);
          } else {
            context.go(AppRoutes.dashboard);
          }
        }
      }

      // Show error.
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(cleanErrorMessage(next.error!)),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    });

    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              const WorkforceBrand(),

              const SizedBox(height: 48),

              Text(
                ref.tr('auth.employeeLogin'),
                style: GoogleFonts.inter(
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                ref.tr('auth.loginSubtitle'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.mutedColor,
                ),
              ),

              const SizedBox(height: 32),

              _buildFieldLabel(ref.tr('auth.employeeId')),

              const SizedBox(height: 12),

              _buildMobileField(ref),

              const SizedBox(height: 32),

              WorkforcePrimaryButton(
                title: isLoading
                    ? ref.tr('auth.signingIn')
                    : ref.tr('auth.signIn'),
                onPressed: isLoading ? () {} : _login,
              ),

              const SizedBox(height: 24),

              _buildHelpText(ref),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    final mobileNumber = mobileController.text.trim();

    if (mobileNumber.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.tr('auth.invalidMobile')),
        ),
      );

      return;
    }

    // 1. Request notification permission (Android 13+)
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // 2. Request location permission before login
    var locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      locationStatus = await Permission.location.request();
    }

    if (!locationStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required for attendance tracking.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 3. Ensure device GPS hardware is turned ON
    final isGpsEnabled = await Permission.location.serviceStatus.isEnabled;
    if (!isGpsEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable GPS / Location in your device settings.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;

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

  Widget _buildMobileField(WidgetRef ref) {
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
        controller: mobileController,
        keyboardType: TextInputType.phone,
        maxLength: 10,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textColor,
        ),
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          prefixIcon: const Icon(
            Icons.badge_outlined,
            size: 20,
            color: AppColors.mutedColor,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 35),
          hintText: ref.tr('auth.employeeIdHint'),
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.mutedColor,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildHelpText(WidgetRef ref) {
    return Center(
      child: Column(
        children: [
          Text(
            ref.tr('auth.needHelpSigningIn'),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.mutedColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ref.tr('auth.contactAdministrator'),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.saffronText,
            ),
          ),
        ],
      ),
    );
  }
}
