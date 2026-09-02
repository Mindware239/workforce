import 'package:go_router/go_router.dart';

import 'package:workforce/features/dashboard/screens/dashboard_screen.dart';
import 'package:workforce/features/splash/screen/splash_screen.dart';

import 'package:workforce/features/home/presentation/home_screen.dart';
import 'package:workforce/features/attendence/presentation/attendence_screen.dart';
import 'package:workforce/features/schedule/presentation/schedule_screen.dart';
import 'package:workforce/features/profile/presentation/profile_screen.dart';

class AppRoutes {
 
  static const String splash = '/splash';
  static const String dashboard = '/dashboard';


  static const String home = '/dashboard/home';
  static const String attendance = '/dashboard/attendance';
  static const String schedule = '/dashboard/schedule';
  static const String profile = '/dashboard/profile';


  static final List<RouteBase> routes = [
 
    GoRoute(
      path: splash,
      name: 'splash',
      builder: (context, state) {
        return const SplashScreen();
      },
    ),

    GoRoute(
      path: dashboard,
      name: 'dashboard',
      builder: (context, state) {
        return const DashboardPage(
          index: 0,
        );
      },
    ),


    GoRoute(
      path: home,
      name: 'home',
      builder: (context, state) {
        return const HomeScreen();
      },
    ),


    GoRoute(
      path: attendance,
      name: 'attendance',
      builder: (context, state) {
        return const AttendanceScreen();
      },
    ),

    GoRoute(
      path: schedule,
      name: 'schedule',
      builder: (context, state) {
        return const ScheduleScreen();
      },
    ),

    GoRoute(
      path: profile,
      name: 'profile',
      builder: (context, state) {
        return const ProfileScreen();
      },
    ),
  ];
}