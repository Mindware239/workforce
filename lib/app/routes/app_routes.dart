import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workforce/features/attendence/presentation/attendance_history_screen.dart';
import 'package:workforce/features/attendence/presentation/location_verification_unsuccessful.dart';
import 'package:workforce/features/auth/presentation/employee_login_screen.dart';
import 'package:workforce/features/chat/presentation/chat_detail_screen.dart';
import 'package:workforce/features/chat/presentation/chat_list_screen.dart';
import 'package:workforce/features/dashboard/presentation/dashboard_screen.dart';
import 'package:workforce/features/assets/presentation/my_assets_screen.dart';
import 'package:workforce/features/expenses/presentation/expense_detail_screen.dart';
import 'package:workforce/features/expenses/presentation/expenses_screen.dart';
import 'package:workforce/features/expenses/presentation/new_expense_screen.dart';
import 'package:workforce/features/reviews/presentation/review_detail_screen.dart';
import 'package:workforce/features/reviews/presentation/reviews_screen.dart';
import 'package:workforce/features/attendence/presentation/face_capture_screen.dart';
import 'package:workforce/features/attendence/presentation/photo_preview_screen.dart';
import 'package:workforce/features/attendence/presentation/verification_unsuccessful_screen.dart';
import 'package:workforce/features/leave/presentation/leave_request.dart';
import 'package:workforce/features/notification/presentation/notification.dart';
import 'package:workforce/features/onboarding/presentation/screen/complete_profile_page.dart';
import 'package:workforce/features/profile/presentation/documnet_screen.dart';
import 'package:workforce/features/schedule/presentation/monthly_summary.dart';
import 'package:workforce/features/splash/presentation/splash_screen.dart';
import 'package:workforce/features/home/presentation/home_screen.dart';
import 'package:workforce/features/attendence/presentation/attendence_screen.dart';
import 'package:workforce/features/schedule/presentation/schedule_screen.dart';
import 'package:workforce/features/profile/presentation/profile_screen.dart';
import 'package:workforce/features/task/presentation/task_screen.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String dashboard = '/dashboard';
  static const String login = '/login';

  static const String home = '/dashboard/home';
  static const String attendance = '/dashboard/attendance';
  static const String attendanceHistory = '/dashboard/attendanceHistory';
  static const String task = '/dashboard/task';
  static const String schedule = '/dashboard/schedule';
  static const String profile = '/dashboard/profile';
  static const String document = '/dashboard/document';
  static const String notification = '/dashboard/notification';

  static const String chat = '/dashboard/chat';

  static const String faceCapture = '/dashboard/faceCapture';
  static const String photoPreview = '/dashboard/photo-preview';
  static const String verificationUnsuccessful =
      '/dashboard/verification-unsuccessful';
  static const locationVerificationUnsuccessful =
      '/dashboard/location-verification-unsuccessful';
  static const String leaveRequest = '/dashboard/leaveRequest';
  static const String monthlySummary = '/dashboard/monthlySummary';
  static const String completeProfile = '/completeProfile';

  static const String expenses = '/dashboard/expenses';
  static const String expenseNew = '/dashboard/expenses/new';
  static const String expenseDetail = '/dashboard/expenses/:id';
  static String expenseDetailPath(int id) => '/dashboard/expenses/$id';

  static const String myAssets = '/dashboard/assets';

  static const String reviews = '/dashboard/reviews';
  static const String reviewDetail = '/dashboard/reviews/:id';
  static String reviewDetailPath(int id) => '/dashboard/reviews/$id';

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
        final data = state.extra as Map<String, dynamic>;
        return FaceCaptureScreen(isStart: data['isStart'] as bool?);
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
      path: leaveRequest,
      name: 'leaveRequest',
      builder: (context, state) {
        return const LeaveRequestScreen();
      },
    ),

    GoRoute(
      path: completeProfile,
      name: 'completeProfile',
      builder: (context, state) {
        return const CompleteProfilePage();
      },
    ),

    GoRoute(
      path: monthlySummary,
      name: 'monthlySummary',
      builder: (context, state) {
        return const MonthlySummaryScreen();
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
          isStart: data['isStart'] as bool?,
        );
      },
    ),

    GoRoute(
      path: AppRoutes.chat,
      builder: (context, state) {
        return const ChatListScreen();
      },
    ),

    GoRoute(
      path: '${AppRoutes.chat}/:conversationId',
      builder: (context, state) {
        final conversationId = int.tryParse(
          state.pathParameters['conversationId'] ?? '',
        );

        if (conversationId == null) {
          return const Scaffold(
            body: Center(child: Text('Invalid conversation.')),
          );
        }

        final title = state.uri.queryParameters['title'] ?? 'Chat';

        return ChatDetailScreen(conversationId: conversationId, title: title);
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
      path: task,
      name: 'task',
      builder: (context, state) {
        return const TasksScreen();
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
      path: attendanceHistory,
      name: 'attendanceHistory',
      builder: (context, state) {
        return const AttendanceHistoryScreen();
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

    GoRoute(
      path: document,
      name: 'document',
      builder: (context, state) {
        return const DocumentsScreen();
      },
    ),
    GoRoute(
      path: notification,
      name: 'notification',
      builder: (context, state) {
        return const NotificationScreen();
      },
    ),

    // Expenses: `new` is declared before `:id` so it is not read as an id.
    GoRoute(
      path: expenses,
      name: 'expenses',
      builder: (context, state) {
        return const ExpensesScreen();
      },
    ),
    GoRoute(
      path: expenseNew,
      name: 'expenseNew',
      builder: (context, state) {
        return const NewExpenseScreen();
      },
    ),
    GoRoute(
      path: expenseDetail,
      name: 'expenseDetail',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');

        if (id == null) {
          return const Scaffold(
            body: Center(child: Text('Invalid expense claim.')),
          );
        }

        return ExpenseDetailScreen(claimId: id);
      },
    ),

    GoRoute(
      path: myAssets,
      name: 'myAssets',
      builder: (context, state) {
        return const MyAssetsScreen();
      },
    ),

    GoRoute(
      path: reviews,
      name: 'reviews',
      builder: (context, state) {
        return const ReviewsScreen();
      },
    ),
    GoRoute(
      path: reviewDetail,
      name: 'reviewDetail',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');

        if (id == null) {
          return const Scaffold(
            body: Center(child: Text('Invalid review.')),
          );
        }

        return ReviewDetailScreen(reviewId: id);
      },
    ),
  ];
}
