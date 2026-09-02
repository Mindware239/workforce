import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


import '../../app/routes/app_routes.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(
    debugLabel: 'root',
  );

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,

  
    initialLocation: AppRoutes.splash,

    debugLogDiagnostics: true,

    errorBuilder: (context, state) {
      return Text( 'Error: ${state.error}');
    },

    routes: AppRoutes.routes,
  );
}