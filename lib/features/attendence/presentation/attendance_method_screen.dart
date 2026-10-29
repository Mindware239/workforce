import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/location/precise_location.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/styles/tricolour_strip.dart';
import 'package:workforce/features/attendence/data/attendance_repository.dart';
import 'package:workforce/features/attendence/providers/attendance_provider.dart';
import 'package:workforce/features/attendence/providers/fingerprint_provider.dart';
import 'package:workforce/features/attendence/services/employee_location_service.dart';

class AttendanceMethodScreen extends ConsumerStatefulWidget {
  final bool? isStart;
  final double? latitude;
  final double? longitude;
  final double? accuracy;

  const AttendanceMethodScreen({
    super.key,
    this.isStart,
    this.latitude,
    this.longitude,
    this.accuracy,
  });

  @override
  ConsumerState<AttendanceMethodScreen> createState() =>
      _AttendanceMethodScreenState();
}

class _AttendanceMethodScreenState
    extends ConsumerState<AttendanceMethodScreen> {
  bool _isAuthenticating = false;

  // ============================================================
  // POSITION HELPER
  // ============================================================

  Future<Position> _resolvePosition() async {
    if (widget.latitude != null &&
        widget.longitude != null &&
        widget.latitude != 0.0 &&
        widget.longitude != 0.0) {
      return Position(
        latitude: widget.latitude!,
        longitude: widget.longitude!,
        timestamp: DateTime.now(),
        accuracy: widget.accuracy ?? 15.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }
    return await getPrecisePosition();
  }

  // ============================================================
  // FINGERPRINT VERIFICATION FLOW
  // ============================================================

  Future<void> _handleFingerprint() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    try {
      final fingerprintService = ref.read(fingerprintServiceProvider);
      final fingerprintRepository = ref.read(fingerprintRepositoryProvider);
      final attendanceNotifier = ref.read(attendanceProvider.notifier);

      final challengePurpose = widget.isStart == true
          ? 'attendance_entry'
          : 'attendance_exit';

      // 1. Check availability
      final availability =
          await fingerprintService.checkBiometricAvailability();

      debugPrint(
        '👆 Biometric check: canProceed=${availability.canProceed}, canAuth=${availability.canAuthenticate}, hasEnrolled=${availability.hasEnrolledBiometrics}, types=${availability.availableBiometrics}, reason=${availability.reason}',
      );

      if (!availability.canProceed) {
        if (!mounted) return;
        _showMessage(
          availability.errorMessage ??
              ref.tr('faceCapture.fingerprintUnavailable'),
        );
        return;
      }

      // 2. Resolve GPS Location
      final Position position = await _resolvePosition();

      // 3. Stable Device ID
      final deviceId = await fingerprintService.getOrCreateDeviceId();

      // 4. Biometric Public Key
      String? publicKey = await fingerprintService.getPublicKey();
      if (publicKey == null || publicKey.isEmpty) {
        publicKey = await fingerprintService.createKeyIfNeeded();
      }

      if (publicKey == null || publicKey.isEmpty) {
        if (!mounted) return;
        _showMessage(ref.tr('faceCapture.unableBiometricKey'));
        return;
      }

      // 5. Register device on server
      final platform = Platform.isAndroid
          ? 'android'
          : (Platform.isIOS ? 'ios' : 'android');

      try {
        await fingerprintRepository.registerDevice(
          deviceId: deviceId,
          deviceName: await fingerprintService.getDeviceName(),
          platform: platform,
          publicKey: publicKey,
          algorithm: 'ES256',
        );
      } catch (regError) {
        debugPrint('⚠️ Device registration check: $regError');
      }

      // 6. Request challenge
      Map<String, dynamic> challengeResponse;
      try {
        challengeResponse = await fingerprintRepository.createChallenge(
          deviceId: deviceId,
          purpose: challengePurpose,
        );
      } catch (challengeError) {
        debugPrint('⚠️ Re-registering device after challenge error: $challengeError');
        await fingerprintRepository.registerDevice(
          deviceId: deviceId,
          deviceName: await fingerprintService.getDeviceName(),
          platform: platform,
          publicKey: publicKey,
          algorithm: 'ES256',
        );
        challengeResponse = await fingerprintRepository.createChallenge(
          deviceId: deviceId,
          purpose: challengePurpose,
        );
      }

      final challengeData = challengeResponse['data'];
      if (challengeData is! Map) {
        if (!mounted) return;
        _showMessage(
          challengeResponse['message']?.toString() ??
              ref.tr('faceCapture.unableCreateChallenge'),
        );
        return;
      }

      final challengeId = challengeData['challengeId'];
      final challenge = challengeData['challenge'];

      if (challengeId == null || challenge == null) {
        if (!mounted) return;
        _showMessage(ref.tr('faceCapture.invalidChallenge'));
        return;
      }

      int challengeIdToSign = int.parse(challengeId.toString());

      // 7. Prompt Biometric and Sign challenge
      String? signature;
      try {
        signature = await fingerprintService.signChallenge(challenge.toString());
      } catch (signError) {
        debugPrint('⚠️ Signature error: $signError. Attempting key reset and retry...');
        final newKey = await fingerprintService.createKeyIfNeeded(force: true);
        if (newKey != null && newKey.isNotEmpty) {
          await fingerprintRepository.registerDevice(
            deviceId: deviceId,
            deviceName: await fingerprintService.getDeviceName(),
            platform: platform,
            publicKey: newKey,
            algorithm: 'ES256',
          );
          final freshChallengeRes = await fingerprintRepository.createChallenge(
            deviceId: deviceId,
            purpose: challengePurpose,
          );
          final freshChallengeData = freshChallengeRes['data'] as Map;
          challengeIdToSign =
              int.parse(freshChallengeData['challengeId'].toString());
          final freshChallenge = freshChallengeData['challenge'].toString();
          signature = await fingerprintService.signChallenge(freshChallenge);
        } else {
          rethrow;
        }
      }

      if (signature == null || signature.isEmpty) {
        if (!mounted) return;
        _showMessage(ref.tr('faceCapture.signatureNotGenerated'));
        return;
      }

      // 8. Submit attendance
      final bool success;
      if (widget.isStart == true) {
        success = await attendanceNotifier.checkIn(
          attendanceType: 'fingerprint',
          lat: position.latitude,
          lng: position.longitude,
          accuracy: position.accuracy,
          deviceId: deviceId,
          challengeId: challengeIdToSign,
          signature: signature,
        );
      } else {
        success = await attendanceNotifier.checkout(
          attendanceType: 'fingerprint',
          lat: position.latitude,
          lng: position.longitude,
          accuracy: position.accuracy,
          deviceId: deviceId,
          challengeId: challengeIdToSign,
          signature: signature,
        );
      }

      if (!mounted) return;

      if (success) {
        _showMessage(
          widget.isStart == true
              ? ref.tr('faceCapture.checkInSuccessful')
              : ref.tr('faceCapture.sessionEndedSuccessful'),
        );

        if (widget.isStart == true) {
          final localization = ref.read(appLocalizationProvider);
          if (mounted) {
            await LocationTrackingService.requestAlwaysPermission(
              context,
              localization.tr,
            );
          }
        }

        if (mounted) {
          context.go(AppRoutes.dashboard);
        }
        return;
      }

      final attendanceMessage = ref.read(attendanceProvider).message;
      _showMessage(
        attendanceMessage ??
            (widget.isStart == true
                ? ref.tr('faceCapture.unableCheckIn')
                : ref.tr('faceCapture.unableEndSession')),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FINGERPRINT ERROR: $e\n$stackTrace');
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  // ============================================================
  // FACE VERIFICATION FLOW
  // ============================================================

  void _handleFace() {
    if (_isAuthenticating) return;

    context.push(
      AppRoutes.faceCapture,
      extra: {
        'latitude': widget.latitude,
        'longitude': widget.longitude,
        'accuracy': widget.accuracy,
        'isStart': widget.isStart,
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // UI BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isCheckIn = widget.isStart ?? true;
    final titleText = isCheckIn
        ? ref.tr('attendance.checkIn')
        : ref.tr('attendance.checkOut');

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.appBarColor,
        surfaceTintColor: AppColors.appBarColor,
        foregroundColor: AppColors.onAppBarColor,
        bottom: const TricolourStrip(),
        elevation: 0,
        title: Text(
          titleText,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onAppBarColor,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLocationVerifiedBanner(),
              const SizedBox(height: 28),
              Text(
                ref.tr('faceCapture.chooseAttendanceMethod'),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ref.tr('faceCapture.selectAttendanceMethod'),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.mutedColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // 1. FINGERPRINT OPTION CARD
              _buildMethodCard(
                icon: Icons.fingerprint_rounded,
                iconColor: AppColors.primaryFillColor,
                iconBgColor: AppColors.primaryFillColor.withValues(alpha: 0.1),
                title: ref.tr('faceCapture.fingerprint'),
                subtitle: ref.tr('faceCapture.useDeviceFingerprint'),
                badgeText: 'Instant',
                badgeColor: const Color(0xFF1B873F),
                isLoading: _isAuthenticating,
                onTap: _isAuthenticating ? null : _handleFingerprint,
              ),

              const SizedBox(height: 16),

              // 2. FACE OPTION CARD
              _buildMethodCard(
                icon: Icons.face_rounded,
                iconColor: AppColors.saffronText,
                iconBgColor: AppColors.saffronText.withValues(alpha: 0.1),
                title: ref.tr('faceCapture.faceVerification'),
                subtitle: ref.tr('faceCapture.useCameraVerifyFace'),
                badgeText: 'Camera',
                badgeColor: AppColors.saffronText,
                isLoading: false,
                onTap: _isAuthenticating ? null : _handleFace,
              ),

              const SizedBox(height: 36),

              // CANCEL BUTTON
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: _isAuthenticating ? null : () => context.pop(),
                  child: Text(
                    ref.tr('faceCapture.cancel'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOCATION BANNER
  // ============================================================

  Widget _buildLocationVerifiedBanner() {
    final accuracyStr = widget.accuracy != null
        ? '±${widget.accuracy!.toStringAsFixed(1)}m'
        : 'Active';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA5D6A7), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF2E7D32),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location Verified',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Within workplace premises (GPS accuracy $accuracyStr)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // METHOD CARD
  // ============================================================

  Widget _buildMethodCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLoading
                ? iconColor
                : AppColors.borderColor,
            width: isLoading ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 28),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.mutedColor,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                ),
              )
            else
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.mutedColor,
              ),
          ],
        ),
      ),
    );
  }
}
