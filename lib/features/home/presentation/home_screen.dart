import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/attendence/data/attendance_repository.dart';
import 'package:workforce/features/auth/providers/auth_provider.dart';
import 'package:workforce/features/home/presentation/widget/current_date_text.dart';
import 'package:workforce/features/notification/presentation/notification.dart';
import 'package:workforce/features/schedule/presentation/leave_request.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const Color backgroundColor = Color(0xFFFFE0E6);
  static const Color cardColor = Color(0xFFFFE8EC);
  static const Color primaryColor = Color(0xFF5125C8);
  static const Color textColor = Color(0xFF1B1B24);
  static const Color mutedColor = Color(0xFF585E6F);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _startShift() async {
    bool loadingShown = false;

    try {
      // Show loading
      loadingShown = true;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // Permission denied
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

      // Get current location
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      debugPrint('📍 Latitude: ${position.latitude}');
      debugPrint('📍 Longitude: ${position.longitude}');
      debugPrint('📍 Accuracy: ${position.accuracy}');

      // Check office geofence
      final response = await ref
          .read(attendanceRepositoryProvider)
          .checkGeofence(
            lat: position.latitude,
            lng: position.longitude,
            accuracy: position.accuracy,
          );

      debugPrint('📍 Geofence result: $response');

      if (!mounted) return;

      // Close loading dialog
      if (loadingShown) {
        Navigator.of(context).pop();
        loadingShown = false;
      }

      final data = response['data'];

      // Invalid/missing geofence response
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

      // ❌ Outside office geofence
      if (!isWithinFence) {
        debugPrint('❌ User is outside office geofence');

        context.push(
          AppRoutes.locationVerificationUnsuccessful,
          extra: distanceMeters is num ? distanceMeters.toDouble() : null,
        );

        return;
      }

      // ✅ User is inside office geofence
      debugPrint('✅ User is inside office geofence');

      context.push(
        AppRoutes.faceCapture,
        extra: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
        },
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Start Shift error: $e');
      debugPrint('$stackTrace');

      // Close loading only if it is still open
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
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    final String fullName = user?['fullName']?.toString() ?? 'Employee';
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          // physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              CurrentDateText(),
              // _buildDate(),
              const SizedBox(height: 8),
              _buildGreeting(fullName),
              const SizedBox(height: 16),
              _buildShiftCard(),
              const SizedBox(height: 16),
              _buildStats(),
              const SizedBox(height: 16),
              _buildQuickActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/images/profile.png',
              height: 32,
              width: 32,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  color: const Color(0xFFE7B8A8),
                  child: const Icon(
                    Icons.person,
                    size: 17,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 16),

          Text(
            'Workforce',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryFillColor,
            ),
          ),

          const Spacer(),

          IconButton(
            onPressed: () {},
            splashRadius: 20,
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.calendar_today_outlined,
              size: 21,
              color: HomeScreen.textColor,
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildShiftCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // color: cardColor,
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
                  color: const Color(0xFFE8D8FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppColors.primaryFillColor,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Upcoming',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryFillColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          Text(
            '9:00 AM – 5:00 PM',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: HomeScreen.textColor,
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                // context.push(AppRoutes.faceCapture);
                _startShift();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: HomeScreen.primaryColor,
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
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(child: _AttendanceCard()),
        const SizedBox(width: 8),
        Expanded(child: _ProductivityCard()),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: .5,
            color: HomeScreen.mutedColor,
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
                onTap: () {},
              ),

              _QuickAction(
                icon: 'assets/icons/summary.svg',
                title: 'Monthly Summary',
                onTap: () {},
              ),

              _QuickAction(
                icon: 'assets/icons/leave.svg',
                title: 'Leave Requests',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LeaveRequestScreen(),
                    ),
                  );
                },
              ),

              _QuickAction(
                icon: 'assets/icons/notification.svg',
                title: 'Notifications',
                subtitle: '2 unread messages',
                showNotificationDot: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
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
  const _AttendanceCard();

  @override
  Widget build(BuildContext context) {
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
              Icon(Icons.person_outline, size: 16, color: Color(0xFF75666C)),
              SizedBox(width: 4),
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
                  text: '5h 30m',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textColor,
                  ),
                ),
                TextSpan(
                  text: ' / 8h',
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
              value: .68,
              minHeight: 6,
              backgroundColor: Color(0xFFE4E1EE),
              valueColor: AlwaysStoppedAnimation(AppColors.primaryFillColor),
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'On Time, Check-in',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedColor),
          ),
        ],
      ),
    );
  }
}

class _ProductivityCard extends StatelessWidget {
  const _ProductivityCard();

  @override
  Widget build(BuildContext context) {
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
              Icon(Icons.trending_up, size: 16, color: Color(0xFF75666C)),
              SizedBox(width: 4),
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
            '92%',
            style: GoogleFonts.inter(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Color(0xFF302329),
              height: 1,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.arrow_upward, size: 10, color: Color(0xFF16A34A)),
              const SizedBox(width: 4),
              Text(
                '+4% from last week',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF16A34A),
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
