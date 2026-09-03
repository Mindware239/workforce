import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workforce/core/services/auth_service.dart';

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
        body: Center(
          child: Text('Error: ${state.error}', textAlign: TextAlign.center),
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
