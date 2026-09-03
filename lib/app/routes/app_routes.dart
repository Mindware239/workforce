import 'package:go_router/go_router.dart';
import 'package:workforce/features/attendence/presentation/location_verification_unsuccessful.dart';
import 'package:workforce/features/auth/presentation/employee_login_screen.dart';
import 'package:workforce/features/dashboard/presentation/dashboard_screen.dart';
import 'package:workforce/features/attendence/presentation/face_capture_screen.dart';
import 'package:workforce/features/attendence/presentation/photo_preview_screen.dart';
import 'package:workforce/features/attendence/presentation/verification_unsuccessful_screen.dart';
import 'package:workforce/features/splash/presentation/splash_screen.dart';
import 'package:workforce/features/home/presentation/home_screen.dart';
import 'package:workforce/features/attendence/presentation/attendence_screen.dart';
import 'package:workforce/features/schedule/presentation/schedule_screen.dart';
import 'package:workforce/features/profile/presentation/profile_screen.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String dashboard = '/dashboard';
  static const String login = '/login';

  static const String home = '/dashboard/home';
  static const String attendance = '/dashboard/attendance';
  static const String schedule = '/dashboard/schedule';
  static const String profile = '/dashboard/profile';

  static const String faceCapture = '/dashboard/faceCapture';
  static const String photoPreview = '/dashboard/photo-preview';
  static const String verificationUnsuccessful = '/dashboard/verification-unsuccessful';
  static const locationVerificationUnsuccessful =
      '/dashboard/location-verification-unsuccessful';

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
        return const DashboardPage(index: 0);
      },
    ),

    GoRoute(
      path: login,
      name: 'login',
      builder: (context, state) {
        return const EmployeeLoginScreen();
      },
    ),
    GoRoute(
      path: faceCapture,
      name: 'faceCapture',
      builder: (context, state) {
        return const FaceCaptureScreen();
      },
    ),
    GoRoute(
      path: verificationUnsuccessful,
      name: 'verificationUnsuccessful',
      builder: (context, state) {
        return const VerificationUnsuccessfulScreen();
      },
    ),
    GoRoute(
      path: photoPreview,
      name: 'photoPreview',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return PhotoPreviewScreen(
          imagePath: data['imagePath'] as String,
          latitude: data['latitude'] as double,
          longitude: data['longitude'] as double,
          accuracy: data['accuracy'] as double?,
        );
      },
    ),

    GoRoute(
      path: locationVerificationUnsuccessful,
      name: 'locationVerificationUnsuccessful',
      builder: (context, state) {
        final distance = state.extra;

        return LocationVerificationUnsuccessfulScreen(
          distanceMeters: distance is num ? distance.toDouble() : null,
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
