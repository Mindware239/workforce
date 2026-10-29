import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/location/precise_location.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/features/attendence/data/attendance_repository.dart';
import 'package:workforce/features/attendence/presentation/blink_capture_screen.dart';
import 'package:workforce/features/attendence/providers/attendance_provider.dart';
import 'package:workforce/features/attendence/providers/fingerprint_provider.dart';
import 'package:workforce/features/attendence/services/employee_location_service.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';
import 'package:workforce/features/onboarding/presentation/widget/workforce_brand.dart';
import 'package:workforce/features/profile/providers/profile_provider.dart';

class FaceCaptureScreen extends ConsumerStatefulWidget {
  final bool? isStart;
  final double? latitude;
  final double? longitude;
  final double? accuracy;

  const FaceCaptureScreen({
    super.key,
    this.isStart,
    this.latitude,
    this.longitude,
    this.accuracy,
  });

  @override
  ConsumerState<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends ConsumerState<FaceCaptureScreen> {
  bool _isLoading = false;

  // ============================================================
  // RESOLVE GPS POSITION
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

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage(ref.tr('faceCapture.locationServicesRequired'));
      throw Exception('Location service disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showMessage(ref.tr('faceCapture.locationPermissionRequired'));
      throw Exception('Location permission denied');
    }

    return await getPrecisePosition();
  }

  // ============================================================
  // TAKE ATTENDANCE (FACE CAPTURE)
  // ============================================================

  Future<void> _takePhoto() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final position = await _resolvePosition();
      await _openBlinkCamera(position: position);
    } catch (e, stackTrace) {
      debugPrint('❌ FACE CAPTURE ERROR: $e\n$stackTrace');
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // DIRECT FINGERPRINT VERIFICATION
  // ============================================================

  Future<void> _authenticateWithFingerprintDirectly() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage(ref.tr('faceCapture.locationServicesRequired'));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _showMessage(ref.tr('faceCapture.locationPermissionRequired'));
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showMessage(ref.tr('faceCapture.locationPermissionDenied'));
        return;
      }

      final Position position = await getPrecisePosition();
      await _authenticateFingerprint(position: position);
    } catch (e, stackTrace) {
      debugPrint('❌ FINGERPRINT DIRECT ERROR: $e\n$stackTrace');
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // OPEN BLINK CAMERA
  // ============================================================

  Future<void> _openBlinkCamera({required Position position}) async {
    debugPrint('========================================');

    debugPrint('📷 FACE ATTENDANCE');

    debugPrint('📷 Opening blink camera...');

    debugPrint('📍 Latitude: ${position.latitude}');

    debugPrint('📍 Longitude: ${position.longitude}');

    debugPrint('📍 Accuracy: ${position.accuracy}');

    debugPrint('========================================');

    final String? imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BlinkCameraScreen()),
    );

    if (!mounted) return;

    // ==========================================================
    // USER CANCELLED CAMERA
    // ==========================================================

    if (imagePath == null || imagePath.isEmpty) {
      debugPrint('📷 Blink camera cancelled.');
      return;
    }

    debugPrint('📷 Automatically captured photo:');

    debugPrint('📷 $imagePath');

    // ==========================================================
    // OPEN PHOTO PREVIEW
    // ==========================================================

    context.push(
      AppRoutes.photoPreview,
      extra: {
        'imagePath': imagePath,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'attendance_type': 'face',
        'isStart': widget.isStart,
      },
    );
  }

  // ============================================================
  // FINGERPRINT ATTENDANCE
  // ============================================================

  Future<void> _authenticateFingerprint({required Position position}) async {
    try {
      debugPrint('👆 Starting fingerprint authentication...');

      // ========================================================
      // SERVICES
      // ========================================================

      final fingerprintService = ref.read(fingerprintServiceProvider);

      final fingerprintRepository = ref.read(fingerprintRepositoryProvider);

      final attendanceNotifier = ref.read(attendanceProvider.notifier);

      // ========================================================
      // ATTENDANCE TYPE + PURPOSE
      // ========================================================

      const attendanceType = 'fingerprint';

      final challengePurpose = widget.isStart == true
          ? 'attendance_entry'
          : 'attendance_exit';

      debugPrint('📌 Attendance Type: $attendanceType');

      debugPrint('📌 Challenge Purpose: $challengePurpose');

      // ========================================================
      // 1. CHECK BIOMETRIC AVAILABILITY
      // ========================================================

      final availability = await fingerprintService.checkBiometricAvailability();

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

      // ========================================================
      // 2. GET STABLE DEVICE ID
      // ========================================================

      final deviceId = await fingerprintService.getOrCreateDeviceId();

      debugPrint('📱 Device ID: $deviceId');

      // ========================================================
      // 3. GET OR CREATE PUBLIC KEY
      // ========================================================

      String? publicKey = await fingerprintService.getPublicKey();

      if (publicKey == null || publicKey.isEmpty) {
        debugPrint('🔐 No valid biometric key found.');
        debugPrint('🔐 Creating ES256 biometric key...');
        publicKey = await fingerprintService.createKeyIfNeeded();
        debugPrint('✅ New ES256 biometric key created.');
      } else {
        debugPrint('✅ Existing biometric public key found.');
      }

      // ========================================================
      // 4. VALIDATE PUBLIC KEY
      // ========================================================

      if (publicKey == null || publicKey.isEmpty) {
        if (!mounted) return;

        _showMessage(ref.tr('faceCapture.unableBiometricKey'));

        return;
      }

      // ========================================================
      // 5. REGISTER DEVICE (Idempotent: ensures device is active on backend)
      // ========================================================

      final platform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'android');

      debugPrint('📡 Ensuring biometric device is registered on server...');
      try {
        await fingerprintRepository.registerDevice(
          deviceId: deviceId,
          deviceName: await fingerprintService.getDeviceName(),
          platform: platform,
          publicKey: publicKey,
          algorithm: 'ES256',
        );
        debugPrint('✅ Fingerprint device registration verified.');
      } catch (regError) {
        debugPrint('⚠️ Device registration check: $regError');
      }

      // ========================================================
      // 6. CREATE CHALLENGE
      // ========================================================

      debugPrint('🎯 Requesting fingerprint challenge...');

      Map<String, dynamic> challengeResponse;
      try {
        challengeResponse = await fingerprintRepository.createChallenge(
          deviceId: deviceId,
          purpose: challengePurpose,
        );
      } catch (challengeError) {
        debugPrint('⚠️ Challenge error ($challengeError). Re-registering device and retrying...');
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

      debugPrint(
        '🎯 Challenge response: '
        '$challengeResponse',
      );

      final challengeData = challengeResponse['data'];

      if (challengeData is! Map) {
        if (!mounted) return;

        _showMessage(
          challengeResponse['message']?.toString() ??
              ref.tr('faceCapture.unableCreateChallenge'),
        );

        return;
      }

      // ========================================================
      // 8. READ CHALLENGE
      // ========================================================

      final challengeId = challengeData['challengeId'];

      final challenge = challengeData['challenge'];

      if (challengeId == null ||
          challenge == null ||
          challenge.toString().isEmpty) {
        if (!mounted) return;

        _showMessage(ref.tr('faceCapture.invalidChallenge'));

        return;
      }

      final parsedChallengeId = int.parse(challengeId.toString());

      debugPrint(
        '🎯 Challenge ID: '
        '$parsedChallengeId',
      );

      // ========================================================
      // 9. SIGN EXACT SERVER CHALLENGE
      // ========================================================

      debugPrint('✍️ Requesting biometric signature...');

      int challengeIdToSign = parsedChallengeId;
      String? signature;
      try {
        signature = await fingerprintService.signChallenge(
          challenge.toString(),
        );
      } catch (signError) {
        debugPrint('⚠️ Biometric signature error: $signError. Attempting key reset and retry...');
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
          challengeIdToSign = int.parse(freshChallengeData['challengeId'].toString());
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

      debugPrint('✅ Challenge signed successfully.');

      // ========================================================
      // 10. PERFORM ATTENDANCE
      // ========================================================

      debugPrint(
        widget.isStart == true
            ? '📥 Performing fingerprint CHECK-IN...'
            : '📤 Performing fingerprint CHECK-OUT...',
      );

      final bool success;

      if (widget.isStart == true) {
        success = await attendanceNotifier.checkIn(
          attendanceType: attendanceType,
          lat: position.latitude,
          lng: position.longitude,
          accuracy: position.accuracy,
          deviceId: deviceId,
          challengeId: challengeIdToSign,
          signature: signature,
        );
      } else {
        success = await attendanceNotifier.checkout(
          attendanceType: attendanceType,
          lat: position.latitude,
          lng: position.longitude,
          accuracy: position.accuracy,
          deviceId: deviceId,
          challengeId: challengeIdToSign,
          signature: signature,
        );
      }

      // ========================================================
      // 11. HANDLE RESULT
      // ========================================================

      if (!mounted) return;

      if (success) {
        debugPrint('========================================');

        debugPrint(
          widget.isStart == true
              ? '✅ FINGERPRINT CHECK-IN SUCCESS'
              : '✅ FINGERPRINT CHECK-OUT SUCCESS',
        );

        debugPrint('========================================');

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

      // ========================================================
      // 12. ATTENDANCE API FAILED
      // ========================================================

      final attendanceMessage = ref.read(attendanceProvider).message;

      _showMessage(
        attendanceMessage ??
            (widget.isStart == true
                ? ref.tr('faceCapture.unableCheckIn')
                : ref.tr('faceCapture.unableEndSession')),
      );
    } catch (e, stackTrace) {
      debugPrint('========================================');

      debugPrint('❌ FINGERPRINT ATTENDANCE ERROR');

      debugPrint('❌ ERROR: $e');

      debugPrint('❌ STACK TRACE: $stackTrace');

      debugPrint('========================================');

      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // ATTENDANCE METHOD BOTTOM SHEET
  // ============================================================

  Future<String?> _showAttendanceTypeBottomSheet(bool isStart) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HANDLE
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  ref.tr('faceCapture.chooseAttendanceMethod'),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textColor,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  ref.tr('faceCapture.selectAttendanceMethod'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedColor,
                  ),
                ),

                const SizedBox(height: 20),

                // FACE
                _buildAttendanceMethodTile(
                  icon: Icons.face_outlined,
                  title: ref.tr('faceCapture.faceVerification'),
                  subtitle: ref.tr('faceCapture.useCameraVerifyFace'),
                  value: 'face',
                  onTap: () {
                    Navigator.pop(context, 'face');
                  },
                ),

                const SizedBox(height: 12),

                // FINGERPRINT
                _buildAttendanceMethodTile(
                  icon: Icons.fingerprint,
                  title: ref.tr('faceCapture.fingerprint'),
                  subtitle: ref.tr('faceCapture.useDeviceFingerprint'),
                  value: 'fingerprint',
                  onTap: () {
                    Navigator.pop(context, 'fingerprint');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // ATTENDANCE METHOD TILE
  // ============================================================

  Widget _buildAttendanceMethodTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primaryFillColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primaryFillColor, size: 24),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textColor,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.mutedColor,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: AppColors.mutedColor,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              const WorkforceBrand(),

              const SizedBox(height: 24),

              _buildCameraFrame(),

              const SizedBox(height: 32),

              _buildLocationChip(),

              const SizedBox(height: 32),

              _buildInstructions(),

              const SizedBox(height: 24),

              WorkforcePrimaryButton(
                icon: Icons.camera_alt,
                title: _isLoading
                    ? ref.tr('faceCapture.pleaseWait')
                    : ref.tr('faceCapture.takePhoto'),
                onPressed: () {
                  if (!_isLoading) {
                    _takePhoto();
                  }
                },
              ),

              const SizedBox(height: 12),

              // SizedBox(
              //   width: double.infinity,
              //   height: 48,
              //   child: OutlinedButton.icon(
              //     icon: const Icon(
              //       Icons.fingerprint,
              //       color: AppColors.primaryFillColor,
              //       size: 22,
              //     ),
              //     label: Text(
              //       ref.tr('faceCapture.fingerprint'),
              //       style: GoogleFonts.inter(
              //         fontSize: 14,
              //         fontWeight: FontWeight.w600,
              //         color: AppColors.primaryFillColor,
              //       ),
              //     ),
              //     style: OutlinedButton.styleFrom(
              //       side: const BorderSide(
              //         color: AppColors.primaryFillColor,
              //         width: 1.5,
              //       ),
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(12),
              //       ),
              //     ),
              //     onPressed: _isLoading ? null : _authenticateWithFingerprintDirectly,
              //   ),
              // ),

              // const SizedBox(height: 12),

              _buildCancelButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CAMERA FRAME / PREVIEW IMAGE
  // ============================================================

  Widget _buildCameraFrame() {
    return SizedBox(
      width: double.infinity,
      height: 310,
      child: Center(child: Image.asset('assets/images/face_capture.jpg')),
    );
  }

  // ============================================================
  // LOCATION CHIP
  // ============================================================
  String _getValue(dynamic value) {
    if (value == null) {
      return ref.tr('common.notAvailable');
    }

    if (value is String) {
      return value.isEmpty ? ref.tr('common.notAvailable') : value;
    }

    if (value is num || value is bool) {
      return value.toString();
    }

    if (value is Map) {
      final possibleKeys = [
        'name',
        'fullName',
        'title',
        'label',
        'value',
        'id',
      ];

      for (final key in possibleKeys) {
        final nestedValue = value[key];

        if (nestedValue != null && nestedValue.toString().isNotEmpty) {
          return nestedValue.toString();
        }
      }
    }

    return value.toString();
  }

  Widget _buildLocationChip() {
    final profileState = ref.watch(profileProvider);
    final profile = profileState.profile ?? {};

    final organizationName = _getValue(profile['organizationName']);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(500),
          border: Border.all(color: AppColors.borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 16,
              color: AppColors.primaryFillColor,
            ),

            const SizedBox(width: 4),

            Text(
              organizationName.isNotEmpty
                  ? organizationName
                  : ref.tr('faceCapture.locationLabel'),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.saffronText,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ============================================================
  // INSTRUCTIONS
  // ============================================================

  Widget _buildInstructions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: .1),
      ),
      child: Column(
        children: [
          _InstructionRow(
            icon: Icons.face_outlined,
            text: ref.tr('faceCapture.positionFace'),
          ),

          const SizedBox(height: 8),

          _InstructionRow(
            icon: Icons.light_mode_outlined,
            text: ref.tr('faceCapture.faceClearlyVisible'),
          ),

          const SizedBox(height: 8),

          _InstructionRow(
            icon: Icons.no_photography_outlined,
            text: ref.tr('faceCapture.removeFaceCovering'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CANCEL
  // ============================================================

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          context.pop();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.saffronText,
          side: const BorderSide(color: AppColors.borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          ref.tr('faceCapture.cancel'),
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

// ================================================================
// INSTRUCTION ROW
// ================================================================

class _InstructionRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InstructionRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryFillColor),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 16, color: AppColors.mutedColor),
          ),
        ),
      ],
    );
  }
}
