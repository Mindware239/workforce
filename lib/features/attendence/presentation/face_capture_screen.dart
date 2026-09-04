
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:workforce/app/routes/app_routes.dart';

import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/attendence/data/attendance_repository.dart';
import 'package:workforce/features/attendence/providers/fingerprint_provider.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';
import 'package:workforce/features/onboarding/presentation/widget/workforce_brand.dart';

class FaceCaptureScreen extends ConsumerStatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  ConsumerState<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends ConsumerState<FaceCaptureScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;

  Future<void> _takePhoto() async {
    if (_isLoading) return;

    // =========================================================
    // 1. Select attendance method
    // =========================================================

    final String? attendanceType = await _showAttendanceTypeBottomSheet();

    if (!mounted || attendanceType == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // =========================================================
      // 2. Check location service
      // =========================================================

      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      debugPrint('📍 Location service enabled: $serviceEnabled');

      if (!serviceEnabled) {
        _showMessage('Please turn on location services and try again.');
        return;
      }

      // =========================================================
      // 3. Check location permission
      // =========================================================

      LocationPermission permission = await Geolocator.checkPermission();

      debugPrint('📍 Location permission: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        debugPrint('📍 Location permission after request: $permission');
      }

      if (permission == LocationPermission.denied) {
        _showMessage('Location permission is required for attendance.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          'Location permission is permanently denied. '
          'Please enable it from Settings.',
        );
        return;
      }

      // =========================================================
      // 4. Get current location
      // =========================================================

      debugPrint('📍 Getting current location...');

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      debugPrint('📍 Latitude: ${position.latitude}');

      debugPrint('📍 Longitude: ${position.longitude}');

      debugPrint('📍 Accuracy: ${position.accuracy}');

      // =========================================================
      // 5. FACE ATTENDANCE
      // =========================================================

      if (attendanceType == 'face') {
        debugPrint('📷 Attendance type: face');
        debugPrint('📷 Opening front camera...');

        final XFile? photo = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 90,
        );

        if (!mounted) return;

        debugPrint('📷 Photo: ${photo?.path}');

        // User cancelled camera
        if (photo == null) {
          debugPrint('📷 Camera cancelled.');
          return;
        }

        // =======================================================
        // Open photo preview
        // =======================================================

        context.push(
          AppRoutes.photoPreview,
          extra: {
            'imagePath': photo.path,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'attendance_type': 'face',
          },
        );

        return;
      }

      // =========================================================
      // 6. FINGERPRINT ATTENDANCE
      // =========================================================

      if (attendanceType == 'fingerprint') {
        debugPrint('👆 Attendance type: fingerprint');

        await _authenticateFingerprint(position: position);

        return;
      }

      // =========================================================
      // 7. Safety fallback
      // =========================================================

      _showMessage('Invalid attendance method selected.');
    } catch (e, stackTrace) {
      debugPrint('========================================');
      debugPrint('❌ ATTENDANCE CAPTURE ERROR');
      debugPrint('❌ ERROR: $e');
      debugPrint('❌ STACK TRACE: $stackTrace');
      debugPrint('========================================');

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

  Future<void> _authenticateFingerprint({required Position position}) async {
    try {
      debugPrint('👆 Starting fingerprint authentication...');

      // =========================================================
      // Services / Repository
      // =========================================================

      final fingerprintService = ref.read(fingerprintServiceProvider);

      final fingerprintRepository = ref.read(fingerprintRepositoryProvider);

      // =========================================================
      // 1. Check biometric availability
      // =========================================================

      final isAvailable = await fingerprintService.isBiometricAvailable();

      debugPrint('👆 Biometric availability: $isAvailable');

      if (!isAvailable) {
        if (!mounted) return;

        _showMessage(
          'Fingerprint authentication is not available on this device.',
        );

        return;
      }

      // =========================================================
      // 2. Get stable device ID
      // =========================================================

      final deviceId = await fingerprintService.getOrCreateDeviceId();

      debugPrint('📱 Device ID: $deviceId');

      // =========================================================
      // 3. Check existing biometric key
      // =========================================================

      final existingPublicKey = await fingerprintService.getPublicKey();

      bool shouldRegisterDevice = false;

      String? publicKey = existingPublicKey;

      // =========================================================
      // 4. Create biometric key if needed
      // =========================================================

      if (publicKey == null || publicKey.isEmpty) {
        debugPrint('🔐 No valid biometric key found.');

        debugPrint('🔐 Creating ES256 biometric key...');

        publicKey = await fingerprintService.createKeyIfNeeded();

        shouldRegisterDevice = true;

        debugPrint('✅ New ES256 biometric key created.');
      } else {
        debugPrint('✅ Existing biometric public key found.');
      }

      // =========================================================
      // 5. Validate public key
      // =========================================================

      if (publicKey == null || publicKey.isEmpty) {
        if (!mounted) return;

        _showMessage('Unable to obtain biometric public key.');

        return;
      }

      debugPrint('🔑 Public key obtained successfully.');

      // =========================================================
      // 6. Register device only when key is newly created
      // =========================================================

      if (shouldRegisterDevice) {
        debugPrint('📡 Registering biometric device...');

        final registerResponse = await fingerprintRepository.registerDevice(
          deviceId: deviceId,
          deviceName: await fingerprintService.getDeviceName(),
          platform: 'android',
          publicKey: publicKey,
          algorithm: 'ES256',
        );

        debugPrint('📡 Register response: $registerResponse');

        if (registerResponse['success'] != true) {
          if (!mounted) return;

          _showMessage(
            registerResponse['message']?.toString() ??
                'Unable to register fingerprint device.',
          );

          return;
        }

        debugPrint('✅ Fingerprint device registered.');
      } else {
        debugPrint(
          'ℹ️ Device already has a valid biometric key. '
          'Skipping registration.',
        );
      }

      // =========================================================
      // 7. Request challenge
      // =========================================================

      debugPrint('🎯 Requesting fingerprint challenge...');

      final challengeResponse = await fingerprintRepository.createChallenge(
        deviceId: deviceId,
        purpose: 'attendance_entry',
      );

      debugPrint('🎯 Challenge response: $challengeResponse');

      final challengeData = challengeResponse['data'];

      if (challengeData is! Map) {
        if (!mounted) return;

        _showMessage(
          challengeResponse['message']?.toString() ??
              'Unable to create fingerprint challenge.',
        );

        return;
      }

      // =========================================================
      // 8. Read challenge
      // =========================================================

      final challengeId = challengeData['challengeId'];

      final challenge = challengeData['challenge'];

      if (challengeId == null ||
          challenge == null ||
          challenge.toString().isEmpty) {
        if (!mounted) return;

        _showMessage('Invalid fingerprint challenge received.');

        return;
      }

      debugPrint('🎯 Challenge ID: $challengeId');

      debugPrint('🎯 Challenge received.');

      // =========================================================
      // 9. Sign EXACT server challenge
      // =========================================================

      debugPrint('✍️ Requesting biometric signature...');

      final signature = await fingerprintService.signChallenge(
        challenge.toString(),
      );

      if (signature == null || signature.isEmpty) {
        if (!mounted) return;

        _showMessage('Biometric signature was not generated.');

        return;
      }

      debugPrint('✅ Challenge signed successfully.');

      // =========================================================
      // 10. Verify fingerprint
      //
      // IMPORTANT:
      // /fingerprint/verify also marks attendance.
      //
      // DO NOT call attendanceProvider.checkIn()
      // after successful verification.
      // =========================================================

      debugPrint('🔐 Sending fingerprint verification...');

      final verifyResponse = await fingerprintRepository.verify(
        deviceId: deviceId,
        challengeId: int.parse(challengeId.toString()),
        signature: signature,
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
      );

      debugPrint('🔐 Verify response: $verifyResponse');

      // =========================================================
      // 11. Handle success
      // =========================================================

      if (!mounted) return;

      if (verifyResponse['success'] == true) {
        debugPrint('========================================');

        debugPrint('✅ FINGERPRINT ATTENDANCE SUCCESS');

        debugPrint('========================================');

        _showMessage(
          verifyResponse['message']?.toString() ??
              'Fingerprint attendance marked successfully.',
        );

        context.pop();

        return;
      }

      // =========================================================
      // 12. Handle verification failure
      // =========================================================

      _showMessage(
        verifyResponse['message']?.toString() ??
            'Fingerprint verification failed.',
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

  // Future<void> _takePhoto() async {
  //   if (_isLoading) return;

  //   setState(() {
  //     _isLoading = true;
  //   });

  //   try {
  //     // 1. Check location service
  //     final serviceEnabled = await Geolocator.isLocationServiceEnabled();

  //     debugPrint('Location service enabled: $serviceEnabled');

  //     if (!serviceEnabled) {
  //       _showMessage('Please turn on location services and try again.');
  //       return;
  //     }

  //     // 2. Check location permission
  //     LocationPermission permission = await Geolocator.checkPermission();

  //     debugPrint('Location permission: $permission');

  //     if (permission == LocationPermission.denied) {
  //       permission = await Geolocator.requestPermission();

  //       debugPrint('Location permission after request: $permission');
  //     }

  //     if (permission == LocationPermission.denied) {
  //       _showMessage('Location permission is required for attendance.');
  //       return;
  //     }

  //     if (permission == LocationPermission.deniedForever) {
  //       _showMessage(
  //         'Location permission is permanently denied. '
  //         'Please enable it from Settings.',
  //       );
  //       return;
  //     }

  //     // 3. Get location
  //     debugPrint('Getting current location...');

  //     final Position position = await Geolocator.getCurrentPosition(
  //       locationSettings: const LocationSettings(
  //         accuracy: LocationAccuracy.high,
  //       ),
  //     );

  //     debugPrint('Latitude: ${position.latitude}');
  //     debugPrint('Longitude: ${position.longitude}');
  //     debugPrint('Accuracy: ${position.accuracy}');

  //     // 4. Capture photo
  //     debugPrint('Opening camera...');

  //     final XFile? photo = await _picker.pickImage(
  //       source: ImageSource.camera,
  //       preferredCameraDevice: CameraDevice.front,
  //       imageQuality: 90,
  //     );

  //     debugPrint('Photo: ${photo?.path}');

  //     if (!mounted || photo == null) {
  //       return;
  //     }

  //     // 5. Open preview
  //     context.push(
  //       AppRoutes.photoPreview,
  //       extra: {
  //         'imagePath': photo.path,
  //         'latitude': position.latitude,
  //         'longitude': position.longitude,
  //         'accuracy': position.accuracy,
  //       },
  //     );
  //   } catch (e, stackTrace) {
  //     debugPrint('================================');
  //     debugPrint('ATTENDANCE CAPTURE ERROR');
  //     debugPrint('ERROR: $e');
  //     debugPrint('STACK TRACE: $stackTrace');
  //     debugPrint('================================');

  //     if (!mounted) return;

  //     _showMessage(e.toString().replaceFirst('Exception: ', ''));
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //       });
  //     }
  //   }
  // }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _showAttendanceTypeBottomSheet() {
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
                  'Choose Attendance Method',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textColor,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Select how you want to mark your attendance.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedColor,
                  ),
                ),

                const SizedBox(height: 20),

                _buildAttendanceMethodTile(
                  icon: Icons.face_outlined,
                  title: 'Face Verification',
                  subtitle: 'Use camera to verify your face',
                  value: 'face',
                  onTap: () {
                    Navigator.pop(context, 'face');
                  },
                ),

                const SizedBox(height: 12),

                _buildAttendanceMethodTile(
                  icon: Icons.fingerprint,
                  title: 'Fingerprint',
                  subtitle: 'Use your device fingerprint',
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
                title: _isLoading ? 'Please wait...' : 'Take Photo',
                onPressed: () {
                  if (!_isLoading) {
                    _takePhoto();
                  }
                },
              ),

              const SizedBox(height: 12),

              _buildCancelButton(),
            ],
          ),
        ),
      ),
    );
  }

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

  Widget _buildCameraFrame() {
    return SizedBox(
      width: double.infinity,
      height: 310,
      child: Center(child: Image.asset('assets/images/face_capture.png')),
    );
  }

  Widget _buildLocationChip() {
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
              'HQ – Factory Floor',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryFillColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            text: 'Position your face inside the frame',
          ),
          const SizedBox(height: 8),
          _InstructionRow(
            icon: Icons.light_mode_outlined,
            text: 'Make sure your face is clearly visible',
          ),
          const SizedBox(height: 8),
          _InstructionRow(
            icon: Icons.no_photography_outlined,
            text: 'Remove helmet or face covering if required',
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          context.pop();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryFillColor,
          side: const BorderSide(color: AppColors.borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Cancel',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

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
