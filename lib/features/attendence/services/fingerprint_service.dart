import 'package:biometric_signature/biometric_signature.dart';
import 'package:uuid/uuid.dart';
import 'package:workforce/core/services/secure_storage.dart';


class FingerprintService {
  final SecureStorage storage;

  FingerprintService({
    required this.storage,
  });

  final BiometricSignature _biometricSignature =
      BiometricSignature();

  static const String _deviceIdKey =
      'fingerprint_device_id';

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
  // Check biometric availability
  // =========================================================

  Future<bool> isBiometricAvailable() async {
    final result =
        await _biometricSignature.biometricAuthAvailable();

    return result.canAuthenticate == true;
  }

  // =========================================================
  // Check biometric key
  // =========================================================

  Future<bool> biometricKeyExists() async {
    return await _biometricSignature.biometricKeyExists();
  }

  // =========================================================
  // Get existing biometric public key
  // =========================================================

  Future<String?> getPublicKey() async {
    try {
      final keyInfo =
          await _biometricSignature.getKeyInfo(
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
      throw Exception(
        'Unable to read biometric public key: $e',
      );
    }
  }

  // =========================================================
  // Create ES256 biometric key if needed
  //
  // Returns:
  //   public key when a key is created
  //   existing public key when already available
  // =========================================================

  Future<String?> createKeyIfNeeded() async {
    final exists =
        await _biometricSignature.biometricKeyExists();

    // Existing key → don't create another one.
    if (exists) {
      return await getPublicKey();
    }

    // Create ECDSA P-256 / ES256 key.
    final result =
        await _biometricSignature.createKeys(
      keyFormat: KeyFormat.pem,
      promptMessage: 'Register your fingerprint',
      config: CreateKeysConfig(
        useDeviceCredentials: false,
        signatureType: SignatureType.ecdsa,
        setInvalidatedByBiometricEnrollment: true,
        enforceBiometric: true,
      ),
    );

    if (result.code != BiometricError.success) {
      throw Exception(
        result.error ??
            'Unable to create biometric key.',
      );
    }

    final publicKey = result.publicKey;

    if (publicKey == null || publicKey.isEmpty) {
      throw Exception(
        'Biometric key created but public key was not returned.',
      );
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

    final keyExists =
        await _biometricSignature.biometricKeyExists();

    if (!keyExists) {
      throw Exception(
        'Biometric key does not exist.',
      );
    }

    final result =
        await _biometricSignature.createSignature(
      payload: challenge,
      signatureFormat: SignatureFormat.base64,
      keyFormat: KeyFormat.pem,
      promptMessage:
          'Verify your fingerprint to mark attendance',
      config: CreateSignatureConfig(
        allowDeviceCredentials: false,
      ),
    );

    if (result.code != BiometricError.success) {
      throw Exception(
        result.error ??
            'Fingerprint authentication failed.',
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
    return 'Android Device';
  }
}