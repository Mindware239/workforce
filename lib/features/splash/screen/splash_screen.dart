import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/styles/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _goToDashboard();
  }

  Future<void> _goToDashboard() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    context.go(AppRoutes.dashboard);
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
