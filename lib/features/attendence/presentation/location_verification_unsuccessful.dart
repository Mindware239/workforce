import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/attendence/data/attendance_repository.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';

class LocationVerificationUnsuccessfulScreen
    extends ConsumerStatefulWidget {
  final double? distanceMeters;

  const LocationVerificationUnsuccessfulScreen({
    super.key,
    this.distanceMeters,
  });

  @override
  ConsumerState<LocationVerificationUnsuccessfulScreen> createState() =>
      _LocationVerificationUnsuccessfulScreenState();
}

class _LocationVerificationUnsuccessfulScreenState
    extends ConsumerState<LocationVerificationUnsuccessfulScreen> {
  double? _distanceMeters;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();

    _distanceMeters = widget.distanceMeters;
  }

  Future<void> _startShift() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    try {
      // --------------------------------------------------
      // 1. Check location permission
      // --------------------------------------------------
      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
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
      // 2. Get current location
      // --------------------------------------------------
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      debugPrint('📍 Latitude: ${position.latitude}');
      debugPrint('📍 Longitude: ${position.longitude}');
      debugPrint('📍 Accuracy: ${position.accuracy}');

      // --------------------------------------------------
      // 3. Check office geofence
      // --------------------------------------------------
      final response = await ref
          .read(attendanceRepositoryProvider)
          .checkGeofence(
            lat: position.latitude,
            lng: position.longitude,
            accuracy: position.accuracy,
          );

      debugPrint('📍 Geofence result: $response');

      if (!mounted) return;

      final data = response['data'];

      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to verify office location.',
            ),
          ),
        );

        return;
      }

      final isWithinFence = data['isWithinFence'] == true;

      final distance = data['distanceMeters'];
      final allowedRadius = data['allowedRadiusMeters'];

      debugPrint('📍 Within fence: $isWithinFence');
      debugPrint('📏 Distance: $distance m');
      debugPrint('⭕ Allowed radius: $allowedRadius m');

      // --------------------------------------------------
      // 4. Still outside
      // --------------------------------------------------
      if (!isWithinFence) {
        setState(() {
          _distanceMeters = distance is num
              ? distance.toDouble()
              : null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You are still outside the allowed area.\n'
              'Distance: ${distance ?? '-'} m '
              '(Allowed: ${allowedRadius ?? '-'} m)',
            ),
            duration: const Duration(seconds: 3),
          ),
        );

        return;
      }

      // --------------------------------------------------
      // 5. Inside office → open camera
      // --------------------------------------------------
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
      debugPrint('❌ Try Again / Start Shift error: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final distance = _distanceMeters?.round() ?? 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 24),

              _buildErrorIcon(),

              const SizedBox(height: 28),

              // Title
              Text(
                "Can't checkin here",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),

              const SizedBox(height: 8),

              // Description
              Text(
                'You are $distance m outside the allowed area. '
                'Move inside the premises and try again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  height: 1.45,
                  color: AppColors.mutedColor,
                ),
              ),

              const SizedBox(height: 16),

              // Try Again
              WorkforcePrimaryButton(
                title: _isChecking
                    ? 'Checking location...'
                    : 'Try Again',
                onPressed: _isChecking ? () {} : () => _startShift(),
              ),

              const SizedBox(height: 12),

              _buildSupportButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorIcon() {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFFDAD6),
      ),
      child: const Icon(
        Icons.warning_amber_rounded,
        size: 32,
        color: Color(0xFF93000A),
      ),
    );
  }

  Widget _buildSupportButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: _isChecking
            ? null
            : () {
                context.go(AppRoutes.dashboard);
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryFillColor,
          side: const BorderSide(
            color: AppColors.borderColor,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Go to Dashboard',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryFillColor,
          ),
        ),
      ),
    );
  }
}