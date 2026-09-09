// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/network/network_providers.dart';
import 'package:workforce/core/services/auth_service.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Keep splash screen visible for 2 seconds.
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final secureStorage = ref.read(secureStorageProvider);
    final token = await secureStorage.getToken();

    // No saved token → Login
    if (token == null || token.isEmpty) {
      AuthService.logout();

      if (!mounted) return;

      context.go(AppRoutes.login);
      return;
    }

    try {
      // Restore employee session and check onboarding status.
      await ref.read(authProvider.notifier).restoreSession();

      if (!mounted) return;

      final authState = ref.read(authProvider);

      // restoreSession failed / session is not authenticated.
      if (!authState.isAuthenticated) {
        AuthService.logout();

        if (!mounted) return;

        context.go(AppRoutes.login);
        return;
      }

      // Restore authentication state.
      AuthService.login();

      // Onboarding is still pending.
      if (authState.onboardingPending) {
        context.go(AppRoutes.completeProfile);
        return;
      }

      // Onboarding completed.
      context.go(AppRoutes.dashboard);
    } catch (e) {
      if (!mounted) return;

      AuthService.logout();

      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/WorkForce_logo.png',
              width: 96,
              height: 96,
            ),
            const SizedBox(height: 24),
            Text(
              'WorkForce',
              style: GoogleFonts.inter(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B1B24),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Employee Management System',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.normal,
                color: Color(0xFF464555),
              ),
            ),
          ],
        ),
      ),
    );
  }
}