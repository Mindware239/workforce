import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/attendence/data/attendance_repository.dart';
import 'package:workforce/features/attendence/providers/attendance_provider.dart';
import 'package:workforce/features/auth/providers/auth_provider.dart';
import 'package:workforce/features/home/presentation/widget/current_date_text.dart';
import 'package:workforce/features/notification/providers/notification_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _attendanceTimer;

  Future<void> _startShift(bool isStart) async {
    bool loadingShown = false;

    try {
      // --------------------------------------------------
      // SHOW LOADING
      // --------------------------------------------------

      loadingShown = true;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      // --------------------------------------------------
      // CHECK LOCATION PERMISSION
      // --------------------------------------------------

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
          const SnackBar(
            content: Text(
              'Location permission is required to start your shift.',
            ),
          ),
        );

        return;
      }

      // --------------------------------------------------
      // GET CURRENT LOCATION
      // --------------------------------------------------

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      debugPrint('========================================');
      debugPrint('📍 CURRENT LOCATION');
      debugPrint('📍 Latitude: ${position.latitude}');
      debugPrint('📍 Longitude: ${position.longitude}');
      debugPrint('📍 Accuracy: ${position.accuracy}');
      debugPrint('📍 Speed: ${position.speed}');
      debugPrint('📍 Heading: ${position.heading}');
      debugPrint('========================================');

      // --------------------------------------------------
      // REPORT LIVE EMPLOYEE LOCATION
      // POST /api/v1/employee/location
      // --------------------------------------------------

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
        // Live location failure should NOT stop
        // the attendance flow.
        debugPrint('⚠️ Live location update failed: $e');
        debugPrint('$stackTrace');
      }

      // --------------------------------------------------
      // CHECK OFFICE GEOFENCE FOR ATTENDANCE
      // --------------------------------------------------

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

      // --------------------------------------------------
      // CLOSE LOADING
      // --------------------------------------------------

      if (loadingShown) {
        Navigator.of(context).pop();
        loadingShown = false;
      }

      // --------------------------------------------------
      // READ GEOFENCE DATA
      // --------------------------------------------------

      final data = response['data'];

      if (data == null) {
        context.push(AppRoutes.locationVerificationUnsuccessful);
        return;
      }

      final isWithinFence = data['isWithinFence'] == true;

      final distanceMeters = data['distanceMeters'];

      final allowedRadiusMeters = data['allowedRadiusMeters'];

      debugPrint('📍 Within fence: $isWithinFence');

      debugPrint('📏 Distance: $distanceMeters m');

      debugPrint('⭕ Allowed radius: $allowedRadiusMeters m');

      // --------------------------------------------------
      // OUTSIDE OFFICE GEOFENCE
      // --------------------------------------------------

      if (!isWithinFence) {
        debugPrint('❌ User is outside office geofence');

        context.push(
          AppRoutes.locationVerificationUnsuccessful,
          extra: distanceMeters is num ? distanceMeters.toDouble() : null,
        );

        return;
      }

      // --------------------------------------------------
      // INSIDE OFFICE GEOFENCE
      // --------------------------------------------------

      debugPrint('✅ User is inside office geofence');

      // --------------------------------------------------
      // GO TO FACE CAPTURE
      // --------------------------------------------------

      context.push(
        AppRoutes.faceCapture,
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

      // --------------------------------------------------
      // CLOSE LOADING IF STILL OPEN
      // --------------------------------------------------

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceProvider.notifier).getDashboard();
      ref.read(attendanceProvider.notifier).getTodayAttendance();
      ref.read(notificationProvider.notifier).startRealtimeNotifications();
    });

    _attendanceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final attendance = ref.read(attendanceProvider);
      final today = attendance.today;

      // Only rebuild the card locally.
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
        surfaceTintColor: AppColors.whiteBackgroundColor,
        backgroundColor: AppColors.whiteBackgroundColor,
        title: Text(
          'Workforce',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryFillColor,
          ),
        ),

        actions: [
          IconButton(
            onPressed: () {
              context.push(AppRoutes.schedule);
            },
            splashRadius: 20,
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.calendar_today_outlined,
              size: 21,
              color: AppColors.textColor,
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
              // _buildHeader(),

              CurrentDateText(),

              const SizedBox(height: 8),

              _buildGreeting(fullName),

              const SizedBox(height: 16),

              // 🔄 Rebuilds whenever attendanceProvider changes
              _buildShiftCard(attendanceState),

              const SizedBox(height: 16),

              // 🔄 Rebuilds whenever attendanceProvider changes
              _buildStats(attendanceState),

              const SizedBox(height: 16),

              _buildQuickActions(notificationState),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildHeader() {
  //   return SizedBox(
  //     height: 56,
  //     child: Row(
  //       children: [
  //         // ClipOval(
  //         //   child: Image.asset(
  //         //     'assets/images/profile.png',
  //         //     height: 32,
  //         //     width: 32,
  //         //     fit: BoxFit.cover,
  //         //     errorBuilder: (_, __, ___) {
  //         //       return Container(
  //         //         color: const Color(0xFFE7B8A8),
  //         //         child: const Icon(
  //         //           Icons.person,
  //         //           size: 17,
  //         //           color: Colors.white,
  //         //         ),
  //         //       );
  //         //     },
  //         //   ),
  //         // ),

  //         // const SizedBox(width: 16),
  //         Text(
  //           'Workforce',
  //           style: GoogleFonts.inter(
  //             fontSize: 20,
  //             fontWeight: FontWeight.bold,
  //             color: AppColors.primaryFillColor,
  //           ),
  //         ),

  //         const Spacer(),

  //         IconButton(
  //           onPressed: () {},
  //           splashRadius: 20,
  //           padding: EdgeInsets.zero,
  //           icon: const Icon(
  //             Icons.calendar_today_outlined,
  //             size: 21,
  //             color: AppColors.textColor,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildGreeting(String fullName) {
    return Text(
      'Good morning, $fullName',
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
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor, width: 1),
        ),
        child: const SizedBox(
          height: 116,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
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
          'Shift schedule is not available.',
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
      statusText = 'Completed';
      statusIcon = Icons.check_circle_outline;
      statusColor = const Color(0xFF137333);
      statusBackground = const Color(0xFFE6F4EA);
    } else if (hasCheckedIn) {
      if (isBreakActive) {
        statusText = 'On Break';
        statusIcon = Icons.coffee_outlined;
        statusColor = const Color(0xFFB06000);
        statusBackground = const Color(0xFFFFF1D6);
      } else if (status == 'late') {
        statusText = 'Checked In • Late';
        statusIcon = Icons.access_time;
        statusColor = AppColors.primaryFillColor;
        statusBackground = const Color(0xFFE8D8FF);
      } else {
        statusText = 'Checked In';
        statusIcon = Icons.access_time;
        statusColor = AppColors.primaryFillColor;
        statusBackground = const Color(0xFFE8D8FF);
      }
    } else {
      statusText = 'Upcoming';
      statusIcon = Icons.access_time;
      statusColor = AppColors.primaryFillColor;
      statusBackground = const Color(0xFFE8D8FF);
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
                "TODAY'S SHIFT",
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

          // ======================================================
          // BEFORE CHECK-IN
          // ======================================================
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
                  'Start Shift',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          // ======================================================
          // SHIFT IN PROGRESS
          // ======================================================
          else if (!hasCheckedOut)
            Column(
              children: [
                // -----------------------------------------------
                // BREAK BUTTON
                // -----------------------------------------------

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed:
                        attendanceState.status == AttendanceStatus.loading
                        ? null
                        : () async {
                            bool success;

                            if (isBreakActive) {
                              success = await ref
                                  .read(attendanceProvider.notifier)
                                  .endBreak();
                            } else {
                              success = await ref
                                  .read(attendanceProvider.notifier)
                                  .startBreak();
                            }

                            if (!mounted || !success) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isBreakActive
                                      ? 'Break ended'
                                      : 'Break started',
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
                      isBreakActive ? 'End Break' : 'Start Break',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // -----------------------------------------------
                // END SESSION
                // -----------------------------------------------
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed:
                        attendanceState.status == AttendanceStatus.loading
                        ? null
                        : () {
                            _startShift(false);
                            // Open your End Session flow here.
                            // This should eventually call:
                            // POST /api/attendance/exit
                            //
                            // For FACE:
                            // -> capture photo
                            //
                            // For FINGERPRINT:
                            // -> challenge purpose:
                            //    attendance_exit
                            // -> sign challenge
                            // -> call endSession()
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryFillColor,
                      side: BorderSide(color: AppColors.primaryFillColor),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 16),
                    label: Text(
                      'End Session',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            )
          // ======================================================
          // SHIFT COMPLETED
          // ======================================================
          else
            Container(
              width: double.infinity,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4EA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Shift completed',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF137333),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatShiftTime(String? start, String? end) {
    if (start == null || end == null) {
      return '--';
    }

    return '${_formatTime(start)} – ${_formatTime(end)}';
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
          child: _AttendanceCard(
            today: attendanceState.today,
            schedule: attendanceState.schedule,
            breakMinutes: attendanceState.breakMinutes,
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: _ProductivityCard(dashboard: attendanceState.dashboard),
        ),
      ],
    );
  }

  Widget _buildQuickActions(NotificationState notificationState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
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
              _QuickAction(
                icon: 'assets/icons/clock.svg',
                title: 'Attendance History',
                onTap: () {
                  context.push(AppRoutes.attendanceHistory);
                },
              ),

              _QuickAction(
                icon: 'assets/icons/summary.svg',
                title: 'Monthly Summary',
                onTap: () {
                  context.push(AppRoutes.monthlySummary);
                },
              ),

              _QuickAction(
                icon: 'assets/icons/leave.svg',
                title: 'Leave Requests',
                onTap: () {
                  context.push(AppRoutes.leaveRequest);
                },
              ),

              _QuickAction(
                icon: 'assets/icons/notification.svg',
                title: 'Notifications',
                subtitle: notificationState.unreadCount == 0
                    ? 'No unread messages'
                    : '${notificationState.unreadCount} unread '
                          '${notificationState.unreadCount == 1 ? 'message' : 'messages'}',
                showNotificationDot: notificationState.unreadCount > 0,

                onTap: () {
                  context.push(AppRoutes.notification);
                },
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttendanceCard extends StatelessWidget {
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
    // Not checked in.
    if (today == null || today?['entryTime'] == null) {
      return 0;
    }

    // Shift completed.
    // Use the final value calculated by backend.
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

    // Local elapsed time.
    final elapsedMinutes = now.difference(entry).inMinutes;

    // Remove already completed break time.
    final workingMinutes = elapsedMinutes - breakMinutes;

    return workingMinutes.clamp(0, 1440);
  }

  @override
  Widget build(BuildContext context) {
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

    final lateMinutes =
        int.tryParse(today?['lateMinutes']?.toString() ?? '0') ?? 0;

    String statusText;

    if (today == null) {
      statusText = 'Not checked in';
    } else if (today?['exitTime'] != null) {
      if (status == 'late' && lateMinutes > 0) {
        statusText = 'Late by $lateMinutes min';
      } else {
        statusText = 'Shift completed';
      }
    } else if (status == 'late') {
      statusText = lateMinutes > 0
          ? 'Late by $lateMinutes min'
          : 'Late check-in';
    } else {
      statusText = 'On Time, Check-in';
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
                'ATTENDANCE',
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
}

class _ProductivityCard extends StatelessWidget {
  final Map<String, dynamic>? dashboard;

  const _ProductivityCard({this.dashboard});

  @override
  Widget build(BuildContext context) {
    final productivity = dashboard?['productivity'];

    final int percent =
        int.tryParse(productivity?['percent']?.toString() ?? '0') ?? 0;

    final int previousPercent =
        int.tryParse(productivity?['previousPercent']?.toString() ?? '0') ?? 0;

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
                'PRODUCTIVITY',
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
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFBA1A1A),
              ),

              const SizedBox(width: 4),

              Expanded(
                child: Text(
                  '${isPositive ? '+' : ''}$deltaPercent% '
                  'from last week',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isPositive
                        ? const Color(0xFF16A34A)
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
  final String icon;
  final String title;
  final String? subtitle;
  final bool showNotificationDot;
  final bool isLast;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
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
              // Icon circle
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF0ECF9),
                ),
                child: SvgPicture.asset(
                  icon,
                  width: 18,
                  height: 18,
                  fit: BoxFit.contain,
                  colorFilter: const ColorFilter.mode(
                    AppColors.primaryFillColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Text
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
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.mutedColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Notification dot
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

              // Arrow
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
