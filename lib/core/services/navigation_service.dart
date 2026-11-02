import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/services/auth_service.dart';
import 'package:workforce/core/styles/app_colors.dart';

import '../../app/routes/app_routes.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    // debugLogDiagnostics: true,

    errorBuilder: (context, state) {
      return Scaffold(
        backgroundColor: AppColors.whiteBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Error',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          backgroundColor: AppColors.appBarColor,
          foregroundColor: AppColors.onAppBarColor,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  'Page Not Found',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The screen you are looking for is not available or has moved.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.mutedColor,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    final destination = AuthService.isAuthenticated
                        ? AppRoutes.dashboard
                        : AppRoutes.login;
                    context.go(destination);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryFillColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Go to Home',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },

    redirect: (BuildContext context, GoRouterState state) {
      final bool loggedIn = AuthService.isAuthenticated;
      final String location = state.matchedLocation;

      final bool isLogin = location == AppRoutes.login;

      final bool isSplash = location == AppRoutes.splash;

      // Not logged in
      if (!loggedIn) {
        // Allow splash and login
        if (isSplash || isLogin) {
          return null;
        }

        // Any protected page → Login
        return AppRoutes.login;
      }

      // Logged in
      if (loggedIn && (isLogin || isSplash)) {
        return AppRoutes.dashboard;
      }

      return null;
    },

    routes: AppRoutes.routes,
  );
}
