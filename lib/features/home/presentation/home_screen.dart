import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/location/precise_location.dart';
import 'package:workforce/core/offline/offline_sync_service.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/styles/tricolour_strip.dart';
import 'package:workforce/features/attendence/data/attendance_repository.dart';
import 'package:workforce/features/attendence/providers/attendance_provider.dart';
import 'package:workforce/features/auth/providers/auth_provider.dart';
import 'package:workforce/features/home/presentation/widget/current_date_text.dart';
import 'package:workforce/features/notification/providers/notification_provider.dart';
import 'package:workforce/features/operations/providers/entitlements_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _attendanceTimer;

  // Calendar day the attendance was last loaded for; a change means a new day.
  DateTime _loadedDay = DateUtils.dateOnly(DateTime.now());

  // Stable targets for the first-launch home screen tour.
  final GlobalKey _tourGreeting = GlobalKey();
  final GlobalKey _tourShift = GlobalKey();
  final GlobalKey _tourAttendance = GlobalKey();
  final GlobalKey _tourProductivity = GlobalKey();
  final GlobalKey _tourHistory = GlobalKey();
  final GlobalKey _tourMonthlySummary = GlobalKey();
  final GlobalKey _tourLeave = GlobalKey();
  final GlobalKey _tourNotifications = GlobalKey();
  final GlobalKey _tourSchedule = GlobalKey();
  final GlobalKey _tourProfile = GlobalKey();

  static const String _tourCompletedKey = 'workforce_home_tour_completed';
  bool _tourStarted = false;

  List<GlobalKey> get _tourKeys => [
    _tourGreeting,
    _tourShift,
    _tourAttendance,
    _tourProductivity,
    _tourHistory,
    _tourMonthlySummary,
    _tourLeave,
    _tourNotifications,
    _tourSchedule,
    _tourProfile,
  ];

  Future<void> _markTourCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourCompletedKey, true);
  }

  Future<void> _startTourIfNeeded() async {
    if (_tourStarted || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted || (prefs.getBool(_tourCompletedKey) ?? false)) return;

    _tourStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ShowcaseView.get().startShowCase(_tourKeys);
    });
  }

  Future<void> _startShift(bool isStart) async {
    bool loadingShown = false;

    try {
      loadingShown = true;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted && loadingShown) {
          Navigator.of(context).pop();
          loadingShown = false;
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.tr('home.locationPermissionRequired'))),
        );

        return;
      }

      final position = await getPrecisePosition();

      debugPrint('========================================');
      debugPrint('📍 CURRENT LOCATION');
      debugPrint('📍 Latitude: ${position.latitude}');
      debugPrint('📍 Longitude: ${position.longitude}');
      debugPrint('📍 Accuracy: ${position.accuracy}');
      debugPrint('📍 Speed: ${position.speed}');
      debugPrint('📍 Heading: ${position.heading}');
      debugPrint('========================================');

      try {
        final locationResponse = await ref
            .read(attendanceRepositoryProvider)
            .updateEmployeeLocation(
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
              speed: position.speed >= 0 ? position.speed : null,
              heading: position.heading >= 0 ? position.heading : null,
            );

        debugPrint('========================================');
        debugPrint('📍 LIVE LOCATION UPDATED');
        debugPrint('📍 Response: $locationResponse');
        debugPrint('========================================');
      } catch (e, stackTrace) {
        debugPrint('⚠️ Live location update failed: $e');
        debugPrint('$stackTrace');
      }

      bool isOffline = false;
      try {
        final response = await ref
            .read(attendanceRepositoryProvider)
            .checkGeofence(
              lat: position.latitude,
              lng: position.longitude,
              accuracy: position.accuracy,
            );

        debugPrint('========================================');
        debugPrint('📍 ATTENDANCE GEOFENCE RESULT');
        debugPrint('$response');
        debugPrint('========================================');

        if (!mounted) return;

        if (loadingShown && mounted) {
          Navigator.of(context).pop();
          loadingShown = false;
        }

        final data = response['data'];

        if (data == null) {
          if (mounted) context.push(AppRoutes.locationVerificationUnsuccessful);
          return;
        }

        if (data['isOfflineCalculated'] == true) {
          isOffline = true;
        }

        final isWithinFence = data['isWithinFence'] == true;
        final distanceMeters = data['distanceMeters'];
        final allowedRadiusMeters = data['allowedRadiusMeters'];

        debugPrint('📍 Within fence: $isWithinFence');
        debugPrint('📏 Distance: $distanceMeters m');
        debugPrint('⭕ Allowed radius: $allowedRadiusMeters m');

        if (!isWithinFence) {
          debugPrint('❌ User is outside office geofence');
          if (mounted) {
            context.push(
              AppRoutes.locationVerificationUnsuccessful,
              extra: distanceMeters is num ? distanceMeters.toDouble() : null,
            );
          }
          return;
        }
      } catch (e) {
        if (loadingShown && mounted) {
          Navigator.of(context).pop();
          loadingShown = false;
        }

        if (isNetworkError(e)) {
          isOffline = true;
          debugPrint('ℹ️ Network offline during geofence check. Proceeding in offline mode.');
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      debugPrint('✅ Proceeding to face capture (Offline: $isOffline)');

      context.push(
        AppRoutes.attendanceMethod,
        extra: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'isStart': isStart,
        },
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Start Shift error: $e');
      debugPrint('$stackTrace');

      if (mounted && loadingShown) {
        Navigator.of(context).pop();
        loadingShown = false;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    ShowcaseView.register(
      blurValue: 1.5,
      globalTooltipActionConfig: const TooltipActionConfig(
        position: TooltipActionPosition.inside,
        alignment: MainAxisAlignment.spaceBetween,
        actionGap: 12,
      ),
      globalTooltipActions: [
        TooltipActionButton(
          type: TooltipDefaultActionType.previous,
          name: 'Previous',
          hideActionWidgetForShowcase: [_tourGreeting],
          textStyle: const TextStyle(color: Colors.white),
        ),
        TooltipActionButton(
          type: TooltipDefaultActionType.next,
          name: 'Next',
          hideActionWidgetForShowcase: [_tourSchedule],
          textStyle: const TextStyle(color: Colors.white),
        ),
        TooltipActionButton(
          type: TooltipDefaultActionType.skip,
          name: 'Skip',
          textStyle: const TextStyle(color: Colors.white),
        ),
      ],
      onDismiss: (key) {
        _markTourCompleted();
      },
      onComplete: (index, key) {
        if (index == _tourKeys.length - 1) {
          _markTourCompleted();
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceProvider.notifier).getDashboard();

      ref.read(attendanceProvider.notifier).getTodayAttendance();

      ref.read(notificationProvider.notifier).startRealtimeNotifications();

      _startTourIfNeeded();
    });

    _attendanceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      // App left open past midnight: yesterday's record is no longer "today".
      final day = DateUtils.dateOnly(DateTime.now());
      if (day != _loadedDay) {
        _loadedDay = day;
        ref.read(attendanceProvider.notifier).getDashboard();
        ref.read(attendanceProvider.notifier).getTodayAttendance();
        return;
      }

      final attendance = ref.read(attendanceProvider);

      final today = attendance.today;

      if (today != null &&
          today['entryTime'] != null &&
          today['exitTime'] == null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _attendanceTimer?.cancel();
    ShowcaseView.get().unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attendanceState = ref.watch(attendanceProvider);

    final notificationState = ref.watch(notificationProvider);

    final authState = ref.watch(authProvider);

    final user = authState.user;

    final String fullName = user?['fullName']?.toString() ?? 'Employee';

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: AppBar(
        surfaceTintColor: AppColors.appBarColor,
        foregroundColor: AppColors.onAppBarColor,
        bottom: const TricolourStrip(),
        backgroundColor: AppColors.appBarColor,
        title: Text(
          // ref.tr('home.workforce'),
          'WorkForce Pro',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.onAppBarColor,
          ),
        ),
        actions: [
          Showcase(
            key: _tourSchedule,
            title: 'Your Schedule',
            description:
                'Open your schedule to view your assigned shift details.',
            child: IconButton(
              onPressed: () {
                context.push(AppRoutes.schedule);
              },
              splashRadius: 20,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.calendar_today_outlined,
                size: 21,
                color: AppColors.onAppBarColor,
              ),
            ),
          ),

          Showcase(
            key: _tourProfile,
            title: 'Your Profile',
            description: 'Open your profile to view or update your personal information and account details.',
            child: IconButton(
              onPressed: () {
                // Keep the exact profile navigation logic already in your app.
                context.push(
                  AppRoutes.profile,
                ); // Replace if your route name differs.
              },
              splashRadius: 20,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.account_circle_outlined,
                size: 24,
                color: AppColors.onAppBarColor,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CurrentDateText(),

              const SizedBox(height: 8),

              Showcase(
                key: _tourGreeting,
                title: 'Welcome to Workforce',
                description:
                    'Your daily workspace for attendance, productivity, '
                    'shift schedules and employee activities.',
                child: _buildGreeting(fullName),
              ),

              const SizedBox(height: 16),

              Showcase(
                key: _tourShift,
                title: "Today's Shift",
                description:
                    'View your shift timings and attendance status. '
                    'Use the available buttons to start or end your shift '
                    'and manage your breaks. Location verification and face '
                    'capture may be required.',
                child: _buildShiftCard(attendanceState),
              ),

              const SizedBox(height: 16),

              _buildStats(attendanceState),

              const SizedBox(height: 16),

              _buildQuickActions(notificationState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(String fullName) {
    final greeting = ref
        .tr('home.goodMorning')
        .replaceFirst('{name}', fullName);

    return Text(
      greeting,
      style: GoogleFonts.inter(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1B1B24),
        height: 1.15,
      ),
    );
  }

  Widget _buildShiftCard(AttendanceState attendanceState) {
    final today = attendanceState.today;
    final schedule = attendanceState.schedule;
    final activeBreak = attendanceState.activeBreak;

    if (attendanceState.isLoadingToday && today == null) {
      return _buildShiftCardShimmer();
    }

    if (schedule == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor, width: 1),
        ),
        child: Text(
          ref.tr('home.shiftScheduleUnavailable'),
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedColor),
        ),
      );
    }

    final standardEntryTime = schedule['standardEntryTime']?.toString();

    final standardExitTime = schedule['standardExitTime']?.toString();

    final shiftTime = _formatShiftTime(standardEntryTime, standardExitTime);

    final hasCheckedIn = today != null && today['entryTime'] != null;

    final hasCheckedOut = today != null && today['exitTime'] != null;

    final isBreakActive = activeBreak != null;

    final status = today?['status']?.toString().toLowerCase();

    String statusText;
    IconData statusIcon;
    Color statusColor;
    Color statusBackground;

    if (hasCheckedOut) {
      statusText = ref.tr('home.completed');

      statusIcon = Icons.check_circle_outline;

      statusColor = AppColors.successColor;

      statusBackground = AppColors.indiaGreenLight;
    } else if (hasCheckedIn) {
      if (isBreakActive) {
        statusText = ref.tr('home.onBreak');

        statusIcon = Icons.coffee_outlined;

        statusColor = const Color(0xFFB06000);

        statusBackground = const Color(0xFFFFF1D6);
      } else if (status == 'late') {
        statusText = ref.tr('home.checkedInLate');

        statusIcon = Icons.access_time;

        statusColor = AppColors.saffronText;

        statusBackground = AppColors.primaryTintColor;
      } else {
        statusText = ref.tr('home.checkedIn');

        statusIcon = Icons.access_time;

        statusColor = AppColors.saffronText;

        statusBackground = AppColors.primaryTintColor;
      }
    } else {
      statusText = ref.tr('home.upcoming');

      statusIcon = Icons.access_time;

      statusColor = AppColors.saffronText;

      statusBackground = AppColors.primaryTintColor;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                ref.tr('home.todaysShift'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: .4,
                  color: AppColors.mutedColor,
                ),
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),

                    const SizedBox(width: 4),

                    Text(
                      statusText,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          Text(
            shiftTime,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textColor,
            ),
          ),

          const SizedBox(height: 10),

          if (!hasCheckedIn)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  _startShift(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryFillColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_outlined, size: 16),
                label: Text(
                  ref.tr('home.startShift'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else if (!hasCheckedOut)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed:
                        attendanceState.status == AttendanceStatus.loading
                        ? null
                        : () async {
                            final wasBreakActive = isBreakActive;

                            final success = wasBreakActive
                                ? await ref
                                      .read(attendanceProvider.notifier)
                                      .endBreak()
                                : await ref
                                      .read(attendanceProvider.notifier)
                                      .startBreak();

                            if (!mounted || !success) {
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  wasBreakActive
                                      ? ref.tr('home.breakEnded')
                                      : ref.tr('home.breakStarted'),
                                ),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryFillColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primaryFillColor,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(
                      isBreakActive
                          ? Icons.play_arrow_outlined
                          : Icons.coffee_outlined,
                      size: 16,
                    ),
                    label: Text(
                      isBreakActive
                          ? ref.tr('home.endBreak')
                          : ref.tr('home.startBreak'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed:
                        attendanceState.status == AttendanceStatus.loading
                        ? null
                        : () {
                            _startShift(false);
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.saffronText,
                      side: const BorderSide(color: AppColors.primaryFillColor),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 16),
                    label: Text(
                      ref.tr('home.endSession'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.indiaGreenLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ref.tr('home.shiftCompleted'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.successColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShiftCardShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                _shimmerBox(width: 95, height: 14),
                const Spacer(),
                _shimmerBox(width: 72, height: 24, radius: 12),
              ],
            ),

            const SizedBox(height: 12),

            // Shift time
            _shimmerBox(width: 145, height: 20),

            const SizedBox(height: 14),

            // Main button
            _shimmerBox(width: double.infinity, height: 48, radius: 8),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox({
    required double width,
    required double height,
    double radius = 6,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  String _formatShiftTime(String? start, String? end) {
    if (start == null || end == null) {
      return '--';
    }

    return '${_formatTime(start)} – '
        '${_formatTime(end)}';
  }

  String _formatTime(String value) {
    try {
      final parts = value.split(':');

      if (parts.length < 2) {
        return value;
      }

      int hour = int.parse(parts[0]);
      final minute = parts[1];

      final period = hour >= 12 ? 'PM' : 'AM';

      hour = hour % 12;

      if (hour == 0) {
        hour = 12;
      }

      return '$hour:$minute $period';
    } catch (_) {
      return value;
    }
  }

  Widget _buildStats(AttendanceState attendanceState) {
    return Row(
      children: [
        Expanded(
          child: Showcase(
            key: _tourAttendance,
            title: 'Attendance Overview',
            description:
                'Track your working hours, attendance status and progress '
                'toward your scheduled working time.',
            child: _AttendanceCard(
              today: attendanceState.today,
              schedule: attendanceState.schedule,
              breakMinutes: attendanceState.breakMinutes,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Showcase(
            key: _tourProductivity,
            title: 'Your Productivity',
            description:
                'Review your productivity score and see how your '
                'performance compares with last week.',
            child: _ProductivityCard(dashboard: attendanceState.dashboard),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(NotificationState notificationState) {
    final unreadCount = notificationState.unreadCount;
    final operationsFeatures = ref.watch(entitlementsProvider);

    // String notificationSubtitle;

    // if (unreadCount == 0) {
    //   notificationSubtitle = ref.tr('home.noUnreadMessages');
    // } else if (unreadCount == 1) {
    //   notificationSubtitle = ref
    //       .tr('home.unreadMessage')
    //       .replaceFirst('{count}', unreadCount.toString());
    // } else {
    //   notificationSubtitle = ref
    //       .tr('home.unreadMessages')
    //       .replaceFirst('{count}', unreadCount.toString());
    // }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ref.tr('home.quickActions'),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: .5,
            color: AppColors.mutedColor,
          ),
        ),

        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor, width: 1),
          ),
          child: Column(
            children: [
              Showcase(
                key: _tourHistory,
                title: 'Attendance History',
                description: 'Review your previous attendance records and working hours.',
                child: _QuickAction(
                  icon: 'assets/icons/clock.svg',
                  title: ref.tr('home.attendanceHistory'),
                  onTap: () {
                    context.push(AppRoutes.attendanceHistory);
                  },
                ),
              ),

              Showcase(
                key: _tourMonthlySummary,
                title: 'Monthly Summary',
                description:
                    'Review your monthly attendance overview and trends.',
                child: _QuickAction(
                  icon: 'assets/icons/summary.svg',
                  title: ref.tr('home.monthlySummary'),
                  onTap: () {
                    context.push(AppRoutes.monthlySummary);
                  },
                ),
              ),

              Showcase(
                key: _tourLeave,
                title: 'Leave Requests',
                description: 'Open this section to access your leave requests.',
                child: _QuickAction(
                  icon: 'assets/icons/leave.svg',
                  title: ref.tr('home.leaveRequests'),
                  onTap: () {
                    context.push(AppRoutes.leaveRequest);
                  },
                ),
              ),

              _QuickAction(
                iconData: Icons.receipt_long_outlined,
                title: ref.tr('home.expenses'),
                // subtitle: ref.tr('home.expensesSubtitle'),
                onTap: () {
                  context.push(AppRoutes.expenses);
                },
              ),

              _QuickAction(
                iconData: Icons.directions_walk_rounded,
                title: ref.tr('home.fieldWork'),
                // subtitle: ref.tr('home.fieldWorkSubtitle'),
                onTap: () {
                  context.push(AppRoutes.fieldWork);
                },
              ),

              _QuickAction(
                iconData: Icons.devices_other_outlined,
                title: ref.tr('home.myAssets'),
                // subtitle: ref.tr('home.myAssetsSubtitle'),
                onTap: () {
                  context.push(AppRoutes.myAssets);
                },
              ),

              // The floor and the warehouse exist only where the plan
              // includes production / inventory (same rule as the web).
              if (featureEnabled(operationsFeatures, productionFeature))
                _QuickAction(
                  iconData: Icons.precision_manufacturing_outlined,
                  title: ref.tr('home.floor'),
                  // subtitle: ref.tr('home.floorSubtitle'),
                  onTap: () {
                    context.push(AppRoutes.floor);
                  },
                ),

              if (featureEnabled(operationsFeatures, inventoryFeature))
                _QuickAction(
                  iconData: Icons.qr_code_scanner_rounded,
                  title: ref.tr('home.warehouse'),
                  // subtitle: ref.tr('home.warehouseSubtitle'),
                  onTap: () {
                    context.push(AppRoutes.warehouse);
                  },
                ),

              _QuickAction(
                iconData: Icons.insights_outlined,
                title: ref.tr('home.performanceReviews'),
                // subtitle: ref.tr('home.performanceReviewsSubtitle'),
                onTap: () {
                  context.push(AppRoutes.reviews);
                },
              ),

              _QuickAction(
                iconData: Icons.payments_outlined,
                title: ref.tr('home.myPay'),
                // subtitle: ref.tr('home.myPaySubtitle'),
                onTap: () {
                  context.push(AppRoutes.myPay);
                },
              ),

              _QuickAction(
                iconData: Icons.campaign_outlined,
                title: ref.tr('home.announcements'),
                // subtitle: ref.tr('home.announcementsSubtitle'),
                onTap: () {
                  context.push(AppRoutes.announcements);
                },
              ),

              Showcase(
                key: _tourNotifications,
                title: 'Notifications',
                description:
                    'Stay informed about important updates and check '
                    'notifications you have not read yet.',
                child: _QuickAction(
                  icon: 'assets/icons/notification.svg',
                  title: ref.tr('home.notifications'),
                  // subtitle: notificationSubtitle,
                  showNotificationDot: unreadCount > 0,
                  onTap: () {
                    context.push(AppRoutes.notification);
                  },
                  isLast: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttendanceCard extends ConsumerWidget {
  final Map<String, dynamic>? today;
  final Map<String, dynamic>? schedule;
  final int breakMinutes;

  const _AttendanceCard({this.today, this.schedule, this.breakMinutes = 0});

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours == 0) {
      return '${mins}m';
    }

    if (mins == 0) {
      return '${hours}h';
    }

    return '${hours}h ${mins}m';
  }

  int _getWorkingMinutes() {
    if (today == null || today?['entryTime'] == null) {
      return 0;
    }

    if (today?['exitTime'] != null) {
      return int.tryParse(today?['totalWorkingMinutes']?.toString() ?? '0') ??
          0;
    }

    final entryTime = today?['entryTime']?.toString();

    if (entryTime == null || entryTime.isEmpty) {
      return 0;
    }

    final parts = entryTime.split(':');

    if (parts.length < 2) {
      return 0;
    }

    final hour = int.tryParse(parts[0]);

    final minute = int.tryParse(parts[1]);

    final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;

    if (hour == null || minute == null) {
      return 0;
    }

    final now = DateTime.now();

    final entry = DateTime(now.year, now.month, now.day, hour, minute, second);

    final elapsedMinutes = now.difference(entry).inMinutes;

    final workingMinutes = elapsedMinutes - breakMinutes;

    return workingMinutes.clamp(0, 1440);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workingMinutes = _getWorkingMinutes();

    final standardMinutes =
        int.tryParse(
          schedule?['standardWorkingHoursMinutes']?.toString() ?? '0',
        ) ??
        0;

    final progress = standardMinutes > 0
        ? (workingMinutes / standardMinutes).clamp(0.0, 1.0)
        : 0.0;

    final status = today?['status']?.toString().toLowerCase();

    String statusText;

    if (today == null) {
      statusText = ref.tr('home.notCheckedIn');
    } else if (today?['exitTime'] != null) {
      if (status == 'late' && _getLateMinutes() > 0) {
        statusText = ref
            .tr('home.lateByMin')
            .replaceFirst('{minutes}', _getLateMinutes().toString());
      } else {
        statusText = ref.tr('home.shiftCompleted');
      }
    } else if (status == 'late') {
      final lateMinutes = _getLateMinutes();

      statusText = lateMinutes > 0
          ? ref
                .tr('home.lateByMin')
                .replaceFirst('{minutes}', lateMinutes.toString())
          : ref.tr('home.lateCheckIn');
    } else {
      statusText = ref.tr('home.onTimeCheckIn');
    }

    return Container(
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 16,
                color: Color(0xFF75666C),
              ),

              const SizedBox(width: 4),

              Text(
                ref.tr('home.attendance'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .4,
                  color: AppColors.mutedColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: _formatMinutes(workingMinutes),
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textColor,
                  ),
                ),

                TextSpan(
                  text: standardMinutes > 0
                      ? ' / ${_formatMinutes(standardMinutes)}'
                      : '',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 5),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFE4E1EE),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryFillColor,
              ),
            ),
          ),

          const SizedBox(height: 6),

          Text(
            statusText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedColor),
          ),
        ],
      ),
    );
  }

  int _getLateMinutes() {
    return int.tryParse(today?['lateMinutes']?.toString() ?? '0') ?? 0;
  }
}

class _ProductivityCard extends ConsumerWidget {
  final Map<String, dynamic>? dashboard;

  const _ProductivityCard({this.dashboard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productivity = dashboard?['productivity'];

    final int percent =
        int.tryParse(productivity?['percent']?.toString() ?? '0') ?? 0;

    final int deltaPercent =
        int.tryParse(productivity?['deltaPercent']?.toString() ?? '0') ?? 0;

    final bool isPositive = deltaPercent >= 0;

    return Container(
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, size: 16, color: Color(0xFF75666C)),

              const SizedBox(width: 4),

              Text(
                ref.tr('home.productivity'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .35,
                  color: AppColors.mutedColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            '$percent%',
            style: GoogleFonts.inter(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF302329),
              height: 1,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                size: 10,
                color: isPositive
                    ? AppColors.successColor
                    : const Color(0xFFBA1A1A),
              ),

              const SizedBox(width: 4),

              Expanded(
                child: Text(
                  '${isPositive ? '+' : ''}'
                  '$deltaPercent% '
                  '${ref.tr('home.fromLastWeek')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isPositive
                        ? AppColors.successColor
                        : const Color(0xFFBA1A1A),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  /// An SVG asset path, or [iconData] for a Material icon.
  final String? icon;
  final IconData? iconData;
  final String title;
  final bool showNotificationDot;
  final bool isLast;
  final VoidCallback onTap;

  const _QuickAction({
    this.icon,
    this.iconData,
    required this.title,
    required this.onTap,
    this.showNotificationDot = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(
                    bottom: BorderSide(color: AppColors.borderColor, width: 1),
                  ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primarySurfaceTintColor,
                ),
                child: icon != null
                    ? SvgPicture.asset(
                        icon!,
                        width: 18,
                        height: 18,
                        fit: BoxFit.contain,
                        colorFilter: const ColorFilter.mode(
                          AppColors.primaryFillColor,
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(
                        iconData ?? Icons.apps_outlined,
                        size: 20,
                        color: AppColors.primaryFillColor,
                      ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textColor,
                      ),
                    ),

                  ],
                ),
              ),

              if (showNotificationDot)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFBA1A1A),
                  ),
                ),

              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.mutedColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
