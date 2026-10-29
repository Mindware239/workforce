import 'dart:io';

import 'package:biometric_signature/biometric_signature.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:workforce/core/services/secure_storage.dart';

class BiometricAvailabilityResult {
  final bool canProceed;
  final bool canAuthenticate;
  final bool hasEnrolledBiometrics;
  final List<String> availableBiometrics;
  final String? reason;
  final String? errorMessage;

  BiometricAvailabilityResult({
    required this.canProceed,
    required this.canAuthenticate,
    required this.hasEnrolledBiometrics,
    required this.availableBiometrics,
    this.reason,
    this.errorMessage,
  });
}

class FingerprintService {
  final SecureStorage storage;

  FingerprintService({
    required this.storage,
  });

  final BiometricSignature _biometricSignature = BiometricSignature();

  static const String _deviceIdKey = 'fingerprint_device_id';

  // =========================================================
  // Get or create stable device ID
  // =========================================================

  Future<String> getOrCreateDeviceId() async {
    final existing = await storage.read(
      key: _deviceIdKey,
    );

    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    const uuid = Uuid();
    final deviceId = uuid.v4();

    await storage.write(
      key: _deviceIdKey,
      value: deviceId,
    );

    return deviceId;
  }

  // =========================================================
  // Detailed biometric availability check
  // =========================================================

  Future<BiometricAvailabilityResult> checkBiometricAvailability() async {
    try {
      final keyExists = await biometricKeyExists();
      final availability = await _biometricSignature.biometricAuthAvailable();

      final canAuth = availability.canAuthenticate == true;
      final hasEnrolled = availability.hasEnrolledBiometrics == true;
      final types = availability.availableBiometrics
              ?.map((t) => t.toString())
              .toList() ??
          <String>[];
      final reason = availability.reason;

      debugPrint(
        '👆 Biometric details: canAuth=$canAuth, hasEnrolled=$hasEnrolled, keyExists=$keyExists, types=$types, reason=$reason',
      );

      // Determine if we can proceed:
      // 1. canAuthenticate is true
      // 2. OR key already exists in Keystore
      // 3. OR user has enrolled biometrics
      // 4. OR device has biometric hardware detected
      bool canProceed = canAuth || keyExists || hasEnrolled || types.isNotEmpty;

      String? errorMsg;
      if (!canProceed) {
        if (reason == 'BIOMETRIC_ERROR_NONE_ENROLLED') {
          errorMsg =
              'No fingerprint enrolled. Please register your fingerprint in phone Settings > Passwords & Security > Fingerprint Unlock.';
        } else if (reason == 'BIOMETRIC_ERROR_NO_HARDWARE') {
          errorMsg = 'Fingerprint hardware is not available on this device.';
        } else if (reason == 'BIOMETRIC_ERROR_HW_UNAVAILABLE') {
          errorMsg =
              'Fingerprint sensor is currently busy or unavailable. Please try again.';
        } else {
          // In MIUI / custom OEM ROMs where BiometricManager.canAuthenticate(BIOMETRIC_STRONG)
          // returns false due to strict Class 3 requirements, attempt key creation anyway
          // rather than hard-blocking the employee.
          canProceed = true;
        }
      }

      return BiometricAvailabilityResult(
        canProceed: canProceed,
        canAuthenticate: canAuth,
        hasEnrolledBiometrics: hasEnrolled,
        availableBiometrics: types,
        reason: reason,
        errorMessage: errorMsg,
      );
    } catch (e) {
      debugPrint('⚠️ biometricAuthAvailable error: $e');
      final keyExists = await biometricKeyExists();
      return BiometricAvailabilityResult(
        canProceed: keyExists,
        canAuthenticate: false,
        hasEnrolledBiometrics: false,
        availableBiometrics: [],
        reason: e.toString(),
        errorMessage: keyExists ? null : 'Biometric check error: $e',
      );
    }
  }

  Future<bool> isBiometricAvailable() async {
    final result = await checkBiometricAvailability();
    return result.canProceed;
  }

  // =========================================================
  // Check biometric key
  // =========================================================

  Future<bool> biometricKeyExists() async {
    try {
      return await _biometricSignature.biometricKeyExists();
    } catch (_) {
      return false;
    }
  }

  // =========================================================
  // Get existing biometric public key
  // =========================================================

  Future<String?> getPublicKey() async {
    try {
      final keyInfo = await _biometricSignature.getKeyInfo(
        checkValidity: true,
        keyFormat: KeyFormat.pem,
      );

      if (keyInfo.exists != true) {
        return null;
      }

      if (keyInfo.isValid == false) {
        return null;
      }

      final publicKey = keyInfo.publicKey;

      if (publicKey == null || publicKey.isEmpty) {
        return null;
      }

      return publicKey;
    } catch (e) {
      return null;
    }
  }

  // =========================================================
  // Create ES256 biometric key if needed
  // =========================================================

  Future<String?> createKeyIfNeeded({bool force = false}) async {
    if (!force) {
      final exists = await _biometricSignature.biometricKeyExists();

      if (exists) {
        final key = await getPublicKey();
        if (key != null && key.isNotEmpty) {
          return key;
        }
      }
    }

    try {
      await _biometricSignature.deleteKeys();
    } catch (_) {}

    // Create ECDSA P-256 / ES256 key.
    // useDeviceCredentials: true ensures devices where biometric is paired with
    // screen lock or Class 2 sensors (e.g. Xiaomi MIUI) can generate and use the key.
    final result = await _biometricSignature.createKeys(
      keyFormat: KeyFormat.pem,
      promptMessage: 'Register your fingerprint',
      config: CreateKeysConfig(
        useDeviceCredentials: true,
        signatureType: SignatureType.ecdsa,
        setInvalidatedByBiometricEnrollment: false,
        enforceBiometric: true,
      ),
    );

    if (result.code != BiometricError.success) {
      throw Exception(
        result.error ?? 'Unable to create biometric key.',
      );
    }

    final publicKey = result.publicKey;

    if (publicKey == null || publicKey.isEmpty) {
      return await getPublicKey();
    }

    return publicKey;
  }

  // =========================================================
  // Sign server challenge
  // =========================================================

  Future<String?> signChallenge(
    String challenge,
  ) async {
    if (challenge.isEmpty) {
      throw Exception(
        'Fingerprint challenge is empty.',
      );
    }

    final keyExists = await _biometricSignature.biometricKeyExists();

    if (!keyExists) {
      throw Exception(
        'Biometric key does not exist.',
      );
    }

    final result = await _biometricSignature.createSignature(
      payload: challenge,
      signatureFormat: SignatureFormat.base64,
      keyFormat: KeyFormat.pem,
      promptMessage: 'Verify your fingerprint to mark attendance',
      config: CreateSignatureConfig(
        allowDeviceCredentials: true,
      ),
    );

    if (result.code != BiometricError.success) {
      throw Exception(
        result.error ?? 'Fingerprint authentication failed.',
      );
    }

    final signature = result.signature;

    if (signature == null || signature.isEmpty) {
      throw Exception(
        'Biometric signature was not generated.',
      );
    }

    return signature;
  }

  // =========================================================
  // Device name
  // =========================================================

  Future<String> getDeviceName() async {
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iOS Device';
    return 'Mobile Device';
  }
}
